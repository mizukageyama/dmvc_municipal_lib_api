unit BookControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,EntitiesU,
  MVCFramework.ActiveRecord, BaseControllerU, MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/books')]
  TBookController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Book', 'It returns list of all books. It allows to ' +
      'apply a filter.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetBooks;

    [MVCPath('/all')]
    [MVCSwagSummary('Book', 'It returns list of all books without pagination.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetAllBooks;

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It returns a single book with a ref link to its ' +
    'author and the story of its lending.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetBookById(BookID: Integer);

    [MVCPath]
    [MVCSwagSummary('Book', 'It creates a new book and returns the URI to ' +
    'find it in the Location HTTP header.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Book data', TBook)]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateBook;

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It updates book information using its book ID.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Book data', TBook)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateBookById(BookID: Integer);

    [MVCPath('/($BookID)')]
    [MVCSwagSummary('Book', 'It deletes book information using its book ID.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpDELETE])]
    procedure DeleteBookById(BookID: Integer);
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils, System.Math, CommonsU,
  System.Generics.Collections;

{ TBookController }

procedure TBookController.CreateBook;
var
  LBook: TBook;
begin
  LBook := Context.Request.BodyAs<TBook>;
  try
    LBook.Insert;
    Render201Created('/api/books/' + LBook.ID.ToString);
  finally
    LBook.Free;
  end;
end;

procedure TBookController.DeleteBookById(BookID: Integer);
var
  LBook: TBook;
begin
  EnsureRole('employee');
  LBook := TMVCActiveRecord.GetByPK<TBook>(BookID, True);
  try
    LBook.Delete;
  finally
    LBook.Free;
  end;
  Render204NoContent('', 'Book deleted');
end;

procedure TBookController.GetAllBooks;
var
  LBooks: TObjectList<TBookAndAuthor>;
begin
  LBooks := TMVCActiveRecord
    .SelectRQL<TBookAndAuthor>('sort(+Title, +PubYear)', -1);
  Render(ObjectDict().Add('data', LBooks));
end;

procedure TBookController.GetBookById(BookID: Integer);
begin
  Render(ObjectDict().Add('data',
    TMVCActiveRecord.GetOneByWhere<TBookAndAuthor>('id = ?', [BookID])));
end;

procedure TBookController.GetBooks;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LFirstRec: Integer;
  LRQL: string;
  LFilterQuery: string;
  LBooks: TObjectList<TBookAndAuthor>;
begin
  LCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], LCurrentPage);
  LCurrentPage := Max(LCurrentPage, 1);
  LFirstRec := (LCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  LFilterQuery := Context.Request.Params['q'];
  LRQL := AppendIfNotEmpty(LFilterQuery, ';');

  LRQL := Format('%ssort(+Title, +PubYear);limit(%d,%d)',
    [LRQL, LFirstRec, TSysConst.PAGE_SIZE]);

  LTotalPages := TPagination.GetTotalPages<TBookAndAuthor>(LFilterQuery);
  LBooks := TMVCActiveRecord.SelectRQL<TBookAndAuthor>(LRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      LBooks,
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
    .Add('meta', TPagination.GetInfo(LCurrentPage, LTotalPages,
      '/api/books?%spage=%d', LRQL))
  );
end;

procedure TBookController.UpdateBookById(BookID: Integer);
var
  LBook: TBook;
begin
  EnsureRole('employee');
  LBook := TMVCActiveRecord.GetByPK<TBook>(BookID, false);
  if Assigned(LBook) then
  begin
    try
      Context.Request.BodyFor<TBook>(LBook);
      LBook.Update;
      Render(HTTP_STATUS.OK, LBook, False);
    finally
      LBook.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Author does not exist');
end;


end.
