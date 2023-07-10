unit LendingControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, BaseControllerU, System.SysUtils,
  MVCFramework.Logger, System.StrUtils, EntitiesU, System.Math, CommonsU,
  System.Generics.Collections, MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/lendings')]
  TLendingController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Lending', 'It returns all lendings for all customers.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetLendings;

    [MVCPath('/customers/($CustomerID)')]
    [MVCSwagSummary('Lending', 'It returns the list of all lendings for a ' +
      'customer.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetLendingsByCustomerID(const CustomerID: Integer);

    [MVCPath('/books/($BookID)')]
    [MVCSwagSummary('Lending', 'It returns all the lendings for a ' +
      'specified book.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetLendingHistoryByBookID(const BookID: Integer);

    [MVCPath('/customers/($CustomerID)')]
    [MVCSwagSummary('Lending', 'It creates a new lending for a customer ' +
      'about a book.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Lending data', TLending)]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateLending(const CustomerID: Integer);

    [MVCPath('/($LendingID)')]
    [MVCSwagSummary('Lending', 'It updates lending information.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Lending data', TLending)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateLendingByID(const LendingID: Integer);

    [MVCPath('/terminated/($LendingID)')]
    [MVCSwagSummary('Lending', 'It terminates a lending.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpPUT])]
    procedure TerminateLending(const LendingID: Integer);
  end;

implementation

{ TLendingController }
procedure TLendingController.CreateLending(const CustomerID: Integer);
var
  LUserID: string;
  LLending: TLending;
  LLendingByBookId: TLending;
begin
  LLending := Context.Request.BodyAs<TLending>;

  {check if the book is already lent to another customer}
  LLendingByBookId := TMVCActiveRecord
    .GetOneByWhere<TLending>('book_id = ? and lending_end IS NULL',
    [LLending.BookID], false);
  if Assigned(LLendingByBookId) then
     raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Sorry, this book is lent to someone else.');

  try
    if not Context.LoggedUser.CustomData.TryGetValue('user_id', LUserID) then
    begin
      raise EMVCException.Create('UserID not found in customer data');
    end;

    LLending.LendingStartUserID := LUserID.ToInt64;
    LLending.LendingStart := Now;
    LLending.LendingEnd.Clear;
    LLending.CustomerID := CustomerID;

    LLending.Insert;
    Render201Created('/api/lendings/' + LLending.ID.ToString);
  finally
    LLending.Free;
  end;
end;

procedure TLendingController.GetLendingHistoryByBookID(const BookID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TLendingRef>('book_id = ?', [BookID]),
      procedure(const Obj: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/lendings/' + TLendingRef(Obj).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/books/' + BookID.ToString).
          Add(HATEOAS.REL, 'book');
      end
    )
  );
end;

procedure TLendingController.GetLendings;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LFirstRec: Integer;
  LRQL: string;
  LFilterQuery: string; //status
  LLendings: TObjectList<TLendingRef>;
begin
  LCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], LCurrentPage);
  LCurrentPage := Max(LCurrentPage, 1);
  LFirstRec := (LCurrentPage - 1) * TSysConst.PAGE_SIZE;

  { get additional filter query if params 'q' exists }
  LFilterQuery := Context.Request.Params['status'];
  if not LFilterQuery.IsEmpty then
  begin
     var status := LFilterQuery;
     if status = 'open' then
       LRQL := 'eq(lending_end, null)'
     else if status = 'closed' then
       lRQL := 'ne(lending_end, null)';
    LFilterQuery := 'status=' + LFilterQuery;
  end;
  LTotalPages := TPagination.GetTotalPages<TLendingRef>(LRQL);

  LRQL := AppendIfNotEmpty(LRQL, ';');
  LRQL := Format('%ssort(-LendingStart, +ID);limit(%d,%d)',
    [LRQL, LFirstRec, TSysConst.PAGE_SIZE]);

  LLendings := TMVCActiveRecord.SelectRQL<TLendingRef>(LRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      LLendings,
      procedure(const Obj: TObject; const Links: IMVCLinks)
        begin
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/lendings/%d', [TLendingRef(Obj).ID])).
            Add(HATEOAS.REL, 'self');
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/lendings/customers/%d',
              [TLendingRef(Obj).ID])).
            Add(HATEOAS.REL, 'customer_lendings');
        end
    )
    .Add('meta', TPagination.GetInfo(LCurrentPage, LTotalPages,
      '/api/lendings?%spage=%d', LFilterQuery, false))
  );
end;

procedure TLendingController.GetLendingsByCustomerID(const CustomerID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TLendingRef>('customer_id = ?', [CustomerID]),
      procedure(const Obj: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/lendings/' + TLendingRef(Obj).ID.ToString).
          Add(HATEOAS.REL, 'self');
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/lendings/').
          Add(HATEOAS.REL, 'list');
      end
    )
  );
end;

procedure TLendingController.TerminateLending(const LendingID: Integer);
var
  LLending: TLending;
  LUserID: string;
begin
  LLending := TMVCActiveRecord.GetByPK<TLending>(LendingID);
  try
    if not Context.LoggedUser.CustomData.TryGetValue('user_id', LUserID) then
    begin
      raise EMVCException.Create('UserID not found in custom data');
    end;

    if LLending.LendingEnd.HasValue then
    begin
      raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Lending already terminated');
    end;

    LLending.LendingEnd := Now;
    LLending.LendingEndUserID := lUserID.ToInt64;
    LLending.Update;
    Render204NoContent('/api/lendings/' + LendingID.ToString,
      'Lending Terminated Correctly');
  finally
    LLending.Free;
  end;
end;


procedure TLendingController.UpdateLendingByID(const LendingID: Integer);
var
  LLending: TLending;
  LLendingByBookId: TLending;
begin
  LLending := TMVCActiveRecord.GetByPK<TLending>(LendingID, false);

  {check if the book is already lent to another customer}
  LLendingByBookId := TMVCActiveRecord
    .GetOneByWhere<TLending>('book_id = ? and lending_end IS NULL',
    [LLending.BookID], false);
  if Assigned(LLendingByBookId) then
     raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Sorry, this book is lent to someone else.');

  if Assigned(LLending) then
  begin
    try
      Context.Request.BodyFor<TLending>(LLending);
      LLending.Update;
      Render(HTTP_STATUS.OK, LLending, False);
    finally
      LLending.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Lending does not exist');
end;

end.
