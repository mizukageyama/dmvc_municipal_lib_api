unit BookControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, BaseControllerU;

type
  [MVCPath('/api/books')]
  TBookController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Book', 'It returns list of all books. It allows to apply a filter.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetBooks;

    [MVCPath('/all')]
    [MVCSwagSummary('Book', 'It returns list of all books without pagination.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetAllBooks;

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It returns a single book with a ref link to its author and the '+
      'story of its lending.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetBookById(BookID: Integer);

    [MVCPath]
    [MVCSwagSummary('Book', 'It creates a new book and returns the URI to find it in the ' +
      'Location HTTP header.')]
    [MVCHTTPMethod([httpPOST])]
    procedure CreateBook;

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It updates book information using its book ID.')]
    [MVCHTTPMethod([httpPUT])]
    procedure UpdateBookById(BookID: Integer);

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It deletes book information using its book ID.')]
    [MVCHTTPMethod([httpDELETE])]
    procedure DeleteBookById(BookID: Integer);
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils, EntitiesU,
  System.Math, CommonsU, System.Generics.Collections;

{ TBookController }

procedure TBookController.CreateBook;
var
  lBook: TBook;
begin
  EnsureRole('employee');
  lBook := Context.Request.BodyAs<TBook>;
  try
    lBook.Insert;
    Render201Created('/api/books/' + lBook.ID.ToString);
  finally
    lBook.Free;
  end;
end;

procedure TBookController.DeleteBookById(BookID: Integer);
var
  lBook: TBook;
begin
  EnsureRole('employee');
  lBook := TMVCActiveRecord.GetByPK<TBook>(BookID, True);
  try
    lBook.Delete;
  finally
    lBook.Free;
  end;
  Render204NoContent('', 'Book deleted');
end;

procedure TBookController.GetAllBooks;
var
  lBooks: TObjectList<TBookAndAuthor>;
begin
  lBooks := TMVCActiveRecord
    .SelectRQL<TBookAndAuthor>('sort(+Title, +PubYear)', -1);
  Render(ObjectDict().Add('data', lBooks));
end;

procedure TBookController.GetBookById(BookID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TBookAndAuthor>('id = ?', [BookID]),
      procedure(const Book: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/books/' + TBookAndAuthor(Book).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/books/').
          Add(HATEOAS.REL, 'list');
      end
    )
  );
end;

procedure TBookController.GetBooks;
var
  lTotalPages: Integer;
  lCurrentPage: Integer;
  lFirstRec: Integer;
  lRQL: string;
  lFilterQuery: string;
  lBooks: TObjectList<TBookAndAuthor>;
begin
  lCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], lCurrentPage);
  lCurrentPage := Max(lCurrentPage, 1);
  lFirstRec := (lCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  lFilterQuery := Context.Request.Params['q'];
  lRQL := AppendIfNotEmpty(lFilterQuery, ';');

  lRQL := Format('%ssort(+Title, +PubYear);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lTotalPages := TPagination.GetTotalPages<TBookAndAuthor>(lFilterQuery);
  lBooks := TMVCActiveRecord.SelectRQL<TBookAndAuthor>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lBooks,
      procedure(const Book: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/books/' + TBookAndAuthor(Book).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' + TBook(Book).AuthorID.ToString).
          Add(HATEOAS.REL, 'author');
      end
    )
    .Add('meta', TPagination.GetInfo(lCurrentPage, lTotalPages,
      '/api/books?%spage=%d', lRQl))
  );
end;

procedure TBookController.UpdateBookById(BookID: Integer);
var
  lBook: TBook;
begin
  EnsureRole('employee');
  lBook := TMVCActiveRecord.GetByPK<TBook>(BookID, false);
  if Assigned(lBook) then
  begin
    try
      Context.Request.BodyFor<TBook>(lBook);
      lBook.Update;
      Render(HTTP_STATUS.OK, lBook, False);
    finally
      lBook.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Author does not exist');
end;


end.
