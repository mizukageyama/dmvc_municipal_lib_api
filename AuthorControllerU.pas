unit AuthorControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  EntitiesU, MVCFramework.ActiveRecord, BaseControllerU,  System.JSON,
  MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/authors')]
  TAuthorController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Author', 'It returns all the authors with some information about the ' +
      'books written by each of then and reference links to get the full ' +
      'book data. It allows filter.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetAuthors;

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It returns a single author using its author ID.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetAuthorByID(const AuthorID: Integer);

    [MVCPath('/($AuthorID)/books')]
    [MVCSwagSummary('Author', 'It returns all the books written by an author.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetBooksByAuthorID(const AuthorID: Integer);

    [MVCPath]
    [MVCSwagSummary('Author', 'It creates a new author and returns the new author URI ' +
      'in the Location HTTP header')]
    [MVCHTTPMethod([httpPOST])]
    [MVCSwagParam(plBody, 'body', 'Author data', TAuthor)]
    procedure CreateAuthor;

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It updates author using its author ID.')]
    [MVCHTTPMethod([httpPUT])]
    procedure UpdateAuthorByID(const AuthorID: Integer);

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It deletes author using its author ID.')]
    [MVCHTTPMethod([httpDELETE])]
    procedure DeleteAuthorByID(const AuthorID: Integer);
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils,
  System.Math, CommonsU, System.Generics.Collections;

{ TAuthorController }

procedure TAuthorController.CreateAuthor;
var
  lAuthor: TAuthor;
begin
  EnsureRole('employee');
  lAuthor := Context.Request.BodyAs<TAuthor>;
  try
    lAuthor.Insert;
    var AuthorID := lAuthor.ID.ToString;
    Render(StrDict(
      ['id', 'uri'],
      [AuthorID, Format('/api/authors/%s', [AuthorID])]
    ));
  finally
    lAuthor.Free;
  end;
end;

procedure TAuthorController.DeleteAuthorByID(const AuthorID: Integer);
var
  lAuthor: TAuthor;
begin
  EnsureRole('employee');
  lAuthor := TMVCActiveRecord.GetByPK<TAuthor>(AuthorID, True);
  try
    lAuthor.Delete;
  finally
    lAuthor.Free;
  end;
  Render204NoContent('', 'Author deleted');
end;

procedure TAuthorController.GetAuthorByID(const AuthorID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TAuthor>('id = ?', [AuthorID]),
      procedure(const Author: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' + TAuthor(Author).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' +
            TAuthor(Author).ID.ToString + '/books').
          Add(HATEOAS.REL, 'books');
      end
    )
  );
end;

procedure TAuthorController.GetAuthors;
var
  lTotalPages: Integer;
  lCurrentPage: Integer;
  lFirstRec: Integer;
  lRQL: string;
  lFilterQuery: string;
  lAuthors: TObjectList<TAuthor>;
begin
  lCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], lCurrentPage);
  lCurrentPage := Max(lCurrentPage, 1);
  lFirstRec := (lCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  lFilterQuery := Context.Request.Params['q'];
  lRQL := AppendIfNotEmpty(lFilterQuery, ';');

  lRQL := Format('%ssort(+FullName, +ID);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lTotalPages := TPagination.GetTotalPages<TAuthor>(lFilterQuery);
  lAuthors := TMVCActiveRecord.SelectRQL<TAuthor>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lAuthors,
      procedure(const Author: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' + TAuthor(Author).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' +
            TAuthor(Author).ID.ToString + '/books').
          Add(HATEOAS.REL, 'books');
      end
    )
    .Add('meta', TPagination.GetInfo(lCurrentPage, lTotalPages,
      '/api/authors?%spage=%d', lRQl))
  );
end;

procedure TAuthorController.GetBooksByAuthorID(const AuthorID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TBook>('author_id = ?', [AuthorID]),
      procedure(const Book: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/books/' + TBook(Book).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' + AuthorID.ToString).
          Add(HATEOAS.REL, 'author');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/authors/' + AuthorID.ToString + '/books').
          Add(HATEOAS.REL, 'author_books');
      end
    )
  );
end;

procedure TAuthorController.UpdateAuthorByID(const AuthorID: Integer);
var
  lAuthor: TAuthor;
begin
  EnsureRole('employee');

  lAuthor := TMVCActiveRecord.GetByPK<TAuthor>(AuthorID, false);
  if Assigned(lAuthor) then
  begin
    try
      Context.Request.BodyFor<TAuthor>(lAuthor);
      lAuthor.Update;
      Render(HTTP_STATUS.OK, lAuthor, False);
    finally
      lAuthor.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Author does not exist');
end;

end.
