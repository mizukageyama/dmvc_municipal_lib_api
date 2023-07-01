unit CustomerControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, FireDAC.ConsoleUI.Wait, BaseControllerU,
  System.SysUtils, MVCFramework.Logger, System.StrUtils, EntitiesU,
  System.Generics.Collections, System.Math, CommonsU;

type
  [MVCPath('/api/customers')]
  TCustomerController = class(TBaseController)
  public
    [MVCPath] { DONE }
    [MVCDoc('It returns the list of all the customers with a ref link to ' +
      'get all lendings for each customer.')]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetCustomers;

    [MVCPath('/($CustomerID)')] { DONE }
    [MVCDoc('It returns a single customer with a ref link to its borrowings.')]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetCustomerByID(const CustomerID: Integer);

    [MVCPath]
    [MVCDoc('It creates a new customer and return its customer URI in the ' +
      'Location HTTP header.')]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateCustomers;

    [MVCPath('/($CustomerID)')]
    [MVCDoc('It updates a customer using its customer ID.')]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateCustomerByID(const CustomerID: Integer);

    [MVCPath('/($CustomerID)')]
    [MVCDoc('It deletes a customer using its customer ID.')]
    [MVCHTTPMethod([httpDELETE])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure DeleteCustomerByID(const CustomerID: Integer);
  end;

implementation

procedure TCustomerController.CreateCustomers;
var
  lCustomer: TCustomer;
begin
  lCustomer := Context.Request.BodyAs<TCustomer>;
  try
    lCustomer.Insert;
    Render201Created('/api/customers/' + lCustomer.ID.ToString);
  finally
    lCustomer.Free;
  end;
end;

procedure TCustomerController.DeleteCustomerByID(const CustomerID: Integer);
var
  lCustomer: TCustomer;
begin
  lCustomer := TMVCActiveRecord.GetByPK<TCustomer>(CustomerID, True);
  try
    lCustomer.Delete;
  finally
    lCustomer.Free;
  end;
  Render204NoContent('', 'Customer deleted');
end;

procedure TCustomerController.GetCustomerByID(const CustomerID: Integer);
begin
  Render(
    ObjectDict()
      .Add('data',
        TMVCActiveRecord.Where<TCustomer>('id = ?', [CustomerID]),
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
  );
end;

procedure TCustomerController.GetCustomers;
var
  lTotalPages: Integer;
  lCurrentPage: Integer;
  lFirstRec: Integer;
  lRQL: string;
  lFilterQuery: string;
  lCustomers: TObjectList<TCustomer>;
begin
  lCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], lCurrentPage);
  lCurrentPage := Max(lCurrentPage, 1);
  lFirstRec := (lCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  lFilterQuery := Context.Request.Params['q'];
  lRQL := AppendIfNotEmpty(lFilterQuery, ';');

  lRQL := Format('%ssort(+DateOfBirth, +ID);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lTotalPages := TPagination.GetTotalPages<TCustomer>(lFilterQuery);
  lCustomers := TMVCActiveRecord.SelectRQL<TCustomer>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lCustomers,
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
    .Add('meta', TPagination.GetInfo(lCurrentPage, lTotalPages,
      '/api/customers?%spage=%d', lRQl))
  );
end;

procedure TCustomerController.UpdateCustomerByID(const CustomerID: Integer);
var
  lCustomer: TCustomer;
begin
  lCustomer := TMVCActiveRecord.GetByPK<TCustomer>(CustomerID, false);
  if Assigned(lCustomer) then
  begin
    try
      Context.Request.BodyFor<TCustomer>(lCustomer);
      lCustomer.Update;
      Render(HTTP_STATUS.OK, lCustomer, False);
    finally
      lCustomer.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'Customer does not exist');
end;

end.
