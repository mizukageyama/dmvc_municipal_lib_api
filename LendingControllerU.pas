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
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateLending(const CustomerID: Integer);

    [MVCPath('/($LendingID)')]
    [MVCSwagSummary('Lending', 'It updates lending information.')]
    [MVCSwagAuthentication]
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
  lUserID: string;
  lLending: TLending;
  lLendingByBookId: TLending;
begin
  EnsureRole('employee');
  lLending := Context.Request.BodyAs<TLending>;

  {check if the book is already lent to another customer}
  lLendingByBookId := TMVCActiveRecord
    .GetOneByWhere<TLending>('book_id = ? and lending_end IS NULL',
    [lLending.BookID], false);
  if Assigned(lLendingByBookId) then
     raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Sorry, this book is lent to someone else.');

  try
    if not Context.LoggedUser.CustomData.TryGetValue('user_id', lUserID) then
    begin
      raise EMVCException.Create('UserID not found in customer data');
    end;

    lLending.LendingStartUserID := lUserID.ToInt64;
    lLending.LendingStart := Now;
    lLending.LendingEnd.Clear;
    lLending.CustomerID := CustomerID;

    lLending.Insert;
    Render201Created('/api/lendings/' + lLending.ID.ToString);
  finally
    lLending.Free;
  end;
end;

procedure TLendingController.GetLendingHistoryByBookID(const BookID: Integer);
begin
  EnsureRole('employee');
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
  lTotalPages: Integer;
  lCurrentPage: Integer;
  lFirstRec: Integer;
  lRQL: string;
  lFilterQuery: string; //status
  lLendings: TObjectList<TLendingRef>;
begin
  EnsureRole('employee');
  lCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], lCurrentPage);
  lCurrentPage := Max(lCurrentPage, 1);
  lFirstRec := (lCurrentPage - 1) * TSysConst.PAGE_SIZE;

  { get additional filter query if params 'q' exists }
  lFilterQuery := Context.Request.Params['status'];
  if not lFilterQuery.IsEmpty then
  begin
     var status := lFilterQuery;
     if status = 'open' then
       lRQL := 'eq(lending_end, null)'
     else if status = 'closed' then
       lRQL := 'ne(lending_end, null)';
    lFilterQuery := 'status=' + lFilterQuery;
  end;
  lTotalPages := TPagination.GetTotalPages<TLendingRef>(lRQL);

  lRQL := AppendIfNotEmpty(lRQL, ';');
  lRQL := Format('%ssort(-LendingStart, +ID);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lLendings := TMVCActiveRecord.SelectRQL<TLendingRef>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lLendings,
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
    .Add('meta', TPagination.GetInfo(lCurrentPage, lTotalPages,
      '/api/lendings?%spage=%d', lFilterQuery, false))
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
  lLending: TLending;
  lUserID: string;
begin
  EnsureRole('employee');
  lLending := TMVCActiveRecord.GetByPK<TLending>(LendingID);
  try
    if not Context.LoggedUser.CustomData.TryGetValue('user_id', lUserID) then
    begin
      raise EMVCException.Create('UserID not found in custom data');
    end;

    if lLending.LendingEnd.HasValue then
    begin
      raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Lending already terminated');
    end;

    lLending.LendingEnd := Now;
    lLending.LendingEndUserID := lUserID.ToInt64;
    lLending.Update;
    Render204NoContent('/api/lendings/' + LendingID.ToString,
      'Lending Terminated Correctly');
  finally
    lLending.Free;
  end;
end;


procedure TLendingController.UpdateLendingByID(const LendingID: Integer);
var
  lLending: TLending;
  lLendingByBookId: TLending;
begin
  EnsureRole('employee');
  lLending := TMVCActiveRecord.GetByPK<TLending>(LendingID, false);

  {check if the book is already lent to another customer}
  lLendingByBookId := TMVCActiveRecord
    .GetOneByWhere<TLending>('book_id = ? and lending_end IS NULL',
    [lLending.BookID], false);
  if Assigned(lLendingByBookId) then
     raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Sorry, this book is lent to someone else.');

  if Assigned(lLending) then
  begin
    try
      Context.Request.BodyFor<TLending>(lLending);
      lLending.Update;
      Render(HTTP_STATUS.OK, lLending, False);
    finally
      lLending.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Lending does not exist');
end;

end.
