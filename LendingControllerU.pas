unit LendingControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, BaseControllerU, System.SysUtils,
  MVCFramework.Logger, System.StrUtils, EntitiesU, System.Math, CommonsU,
  System.Generics.Collections;

type
  [MVCPath('/api/lendings')]
  TLendingController = class(TBaseController)
  public
    [MVCPath]
    [MVCDoc('It returns all lendings for all customers.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetLendings;

    [MVCPath('customers/($CustomerID)')]
    [MVCDoc('It returns the list of all lendings for a customer.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetLendingsByCustomerID(const CustomerID: Integer);

    [MVCPath('books/($BookID)')]
    [MVCDoc('It returns all the lendings for a specified book.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetLendingHistoryByBookID(const BookID: Integer);

    [MVCPath('customers/($CustomerID)')]
    [MVCDoc('It creates a new lending for a customer about a book.')]
    [MVCHTTPMethod([httpPOST])]
    procedure CreateLending;

    [MVCPath('/($LendingID)')]
    [MVCDoc('It updates lending information.')]
    [MVCHTTPMethod([httpPUT])]
    procedure UpdateLendingByID(const LendingID: Integer);

    [MVCPath('/terminated/($LendingID)')]
    [MVCDoc('It terminates a lending.')]
    [MVCHTTPMethod([httpPOST])]
    procedure TerminateLending(const LendingID: Integer);
  end;

implementation

{ TLendingController }
procedure TLendingController.CreateLending;
var
  lLending: TLending;
begin
  lLending := Context.Request.BodyAs<TLending>;
  try
    lLending.Insert;
    Render201Created('/api/lendings/' + lLending.ID.ToString);
  finally
    lLending.Free;
  end;
end;

procedure TLendingController.GetLendingHistoryByBookID(const BookID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TLending>('book_id = ?', [BookID]),
      procedure(const Obj: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/lendings/' + TLending(Obj).ID.ToString).
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
  lLendings: TObjectList<TLending>;
begin
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
     else
       lRQL := 'ne(lending_end, null)';
    lFilterQuery := 'status=' + lFilterQuery;
  end;
  lTotalPages := TPagination.GetTotalPages<TLending>(lRQL);

  lRQL := AppendIfNotEmpty(lRQL, ';');
  lRQL := Format('%ssort(-LendingStart, +ID);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lLendings := TMVCActiveRecord.SelectRQL<TLending>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lLendings,
      procedure(const Obj: TObject; const Links: IMVCLinks)
        begin
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/lendings/%d', [TLending(Obj).ID])).
            Add(HATEOAS.REL, 'self');
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/lendings/customers/%d',
              [TLending(Obj).ID])).
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
      TMVCActiveRecord.Where<TLending>('customer_id = ?', [CustomerID]),
      procedure(const Obj: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/lendings/' + TLending(Obj).ID.ToString).
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
begin
  lLending := TMVCActiveRecord.GetByPK<TLending>(LendingID);
  try
    if lLending.LendingEnd.HasValue then
    begin
      raise EMVCException.Create(HTTP_STATUS.BadRequest,
        'Lending already terminated');
    end;
    lLending.LendingEnd := Now;
    {"LendingEndUserID" should be logged user which terminated
    the lending (the operator of the municipal library). However
    we still don't have the authentication in place, so at this time,
    we will write just 1 as LendingEndUserID}
    lLending.LendingEndUserID := 1;
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
begin
  lLending := TMVCActiveRecord.GetByPK<TLending>(LendingID, false);
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
    Render(HTTP_STATUS.NotFound, 'Author does not exist');
end;

end.
