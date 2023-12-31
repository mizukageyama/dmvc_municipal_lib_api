﻿unit AuthorControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  EntitiesU, MVCFramework.ActiveRecord, BaseControllerU, System.JSON,
  MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/authors')]
  TAuthorController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Author', 'It returns all the authors with some ' +
      'information about the books written by each of then and reference ' +
      'links to get the full book data. It allows filter.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetAuthors;

    [MVCPath('/all')]
    [MVCSwagSummary('Author', 'Returns all authors without pagination')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetAllAuthors;

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It returns a single author using its ' +
      'author ID.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetAuthorByID(const AuthorID: Integer);

    [MVCPath('/($AuthorID)/books')]
    [MVCSwagSummary('Author', 'It returns all the books written by an author.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetBooksByAuthorID(const AuthorID: Integer);

    [MVCPath]
    [MVCSwagSummary('Author', 'It creates a new author and returns the new ' +
      'author URI in the Location HTTP header')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Author data', TAuthor)]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateAuthor;

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It updates author using its author ID.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Author data', TAuthor)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateAuthorByID(const AuthorID: Integer);

    [MVCPath('/($AuthorID)')]
    [MVCSwagSummary('Author', 'It deletes author using its author ID.')]
    [MVCSwagAuthentication]
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
  LAuthor: TAuthor;
begin
  lAuthor := Context.Request.BodyAs<TAuthor>;
  try
    LAuthor.Insert;
    var AuthorID := lAuthor.ID.ToString;
    Render(StrDict(
      ['id', 'uri'],
      [AuthorID, Format('/api/authors/%s', [AuthorID])]
    ));
  finally
    LAuthor.Free;
  end;
end;

procedure TAuthorController.DeleteAuthorByID(const AuthorID: Integer);
var
  LAuthor: TAuthor;
begin
  LAuthor := TMVCActiveRecord.GetByPK<TAuthor>(AuthorID, True);
  try
    LAuthor.Delete;
  finally
    LAuthor.Free;
  end;
  Render204NoContent('', 'Author deleted');
end;

procedure TAuthorController.GetAllAuthors;
var
  LAuthor: TObjectList<TAuthor>;
begin
  LAuthor := TMVCActiveRecord.SelectRQL<TAuthor>('sort(+FullName, +ID)', -1);
  Render(ObjectDict().Add('data', LAuthor));
end;

procedure TAuthorController.GetAuthorByID(const AuthorID: Integer);
begin
  Render(ObjectDict().Add('data',
    TMVCActiveRecord.GetOneByWhere<TAuthor>('id = ?', [AuthorID])));
end;

procedure TAuthorController.GetAuthors;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LFirstRec: Integer;
  LRQL: string;
  LFilterQuery: string;
  LAuthors: TObjectList<TAuthor>;
begin
  LCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], LCurrentPage);
  LCurrentPage := Max(LCurrentPage, 1);
  LFirstRec := (LCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  LFilterQuery := Context.Request.Params['q'];
  LRQL := AppendIfNotEmpty(LFilterQuery, ';');

  LRQL := Format('%ssort(+FullName, +ID);limit(%d,%d)',
    [LRQL, LFirstRec, TSysConst.PAGE_SIZE]);

  LTotalPages := TPagination.GetTotalPages<TAuthor>(LFilterQuery);
  LAuthors := TMVCActiveRecord.SelectRQL<TAuthor>(LRQL, -1);

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
    .Add('meta', TPagination.GetInfo(LCurrentPage, LTotalPages,
      '/api/authors?%spage=%d', LRQl))
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
  LAuthor: TAuthor;
begin
  LAuthor := TMVCActiveRecord.GetByPK<TAuthor>(AuthorID, false);
  if Assigned(LAuthor) then
  begin
    try
      Context.Request.BodyFor<TAuthor>(LAuthor);
      LAuthor.Update;
      Render(HTTP_STATUS.OK, lAuthor, False);
    finally
      LAuthor.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Author does not exist');
end;

end.
