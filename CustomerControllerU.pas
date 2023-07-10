unit CustomerControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, FireDAC.ConsoleUI.Wait, BaseControllerU,
  System.SysUtils, MVCFramework.Logger, System.StrUtils, EntitiesU,
  System.Generics.Collections, System.Math, CommonsU,
  MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/customers')]
  TCustomerController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('Customer', 'It returns the list of all the customers ' +
      'with a ref link to get all lendings for each customer.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetCustomers;

    [MVCPath('/all')]
    [MVCSwagSummary('Customer',
      'It returns the list of all the customers without pagination')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetAllCustomers;

    [MVCPath('/($CustomerID)')]
    [MVCSwagSummary('Customer', 'It returns a single customer with a ref link' +
      'to its borrowings.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetCustomerByID(const CustomerID: Integer);

    [MVCPath]
    [MVCSwagSummary('Customer', 'It creates a new customer and return its ' +
      'customer URI in the Location HTTP header.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Customer data', TCustomer)]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateCustomers;

    [MVCPath('/($CustomerID)')]
    [MVCSwagSummary('Customer', 'It updates a customer using its customer ID.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'Customer data', TCustomer)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateCustomerByID(const CustomerID: Integer);

    [MVCPath('/($CustomerID)')]
    [MVCSwagSummary('Customer', 'It deletes a customer using its customer ID.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpDELETE])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure DeleteCustomerByID(const CustomerID: Integer);
  end;

implementation

procedure TCustomerController.CreateCustomers;
var
  LCustomer: TCustomer;
begin
  LCustomer := Context.Request.BodyAs<TCustomer>;
  try
    LCustomer.Insert;
    Render201Created('/api/customers/' + LCustomer.ID.ToString);
  finally
    LCustomer.Free;
  end;
end;

procedure TCustomerController.DeleteCustomerByID(const CustomerID: Integer);
var
  LCustomer: TCustomer;
begin
  LCustomer := TMVCActiveRecord.GetByPK<TCustomer>(CustomerID, True);
  try
    LCustomer.Delete;
  finally
    LCustomer.Free;
  end;
  Render204NoContent('', 'Customer deleted');
end;

procedure TCustomerController.GetAllCustomers;
var
  LCustomers: TObjectList<TCustomer>;
begin
  LCustomers := TMVCActiveRecord
    .SelectRQL<TCustomer>('sort(+FirstName, +LastName)', -1);
  Render(ObjectDict().Add('data', LCustomers));
end;

procedure TCustomerController.GetCustomerByID(const CustomerID: Integer);
begin
  Render(ObjectDict().Add('data',
    TMVCActiveRecord.GetOneByWhere<TCustomer>('id = ?', [CustomerID])));
end;

procedure TCustomerController.GetCustomers;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LFirstRec: Integer;
  LRQL: string;
  LFilterQuery: string;
  LCustomers: TObjectList<TCustomer>;
begin
  LCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], LCurrentPage);
  LCurrentPage := Max(LCurrentPage, 1);
  LFirstRec := (LCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  LFilterQuery := Context.Request.Params['q'];
  LRQL := AppendIfNotEmpty(LFilterQuery, ';');

  LRQL := Format('%ssort(+FirstName, +LastName);limit(%d,%d)',
    [LRQL, LFirstRec, TSysConst.PAGE_SIZE]);

  LTotalPages := TPagination.GetTotalPages<TCustomer>(LFilterQuery);
  LCustomers := TMVCActiveRecord.SelectRQL<TCustomer>(LRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      LCustomers,
      procedure(const Obj: TObject; const Links: IMVCLinks)
        begin
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/customers/%d', [TCustomer(Obj).ID])).
            Add(HATEOAS.REL, 'self');
          Links.AddRefLink.
            Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
            Add(HATEOAS.HREF, Format('/api/lendings/customers/%d',
              [Tcustomer(Obj).ID])).
            Add(HATEOAS.REL, 'customer_lendings');
        end
    )
    .Add('meta', TPagination.GetInfo(LCurrentPage, LTotalPages,
      '/api/customers?%spage=%d', LRQL))
  );
end;

procedure TCustomerController.UpdateCustomerByID(const CustomerID: Integer);
var
  LCustomer: TCustomer;
begin
  LCustomer := TMVCActiveRecord.GetByPK<TCustomer>(CustomerID, false);
  if Assigned(LCustomer) then
  begin
    try
      Context.Request.BodyFor<TCustomer>(LCustomer);
      LCustomer.Update;
      Render(HTTP_STATUS.OK, LCustomer, False);
    finally
      LCustomer.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Customer does not exist');
end;

end.
