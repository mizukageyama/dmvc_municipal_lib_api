unit AuthCriteriaU;

interface

uses
  System.Generics.Collections, FireDAC.Comp.Client, MVCFramework.ActiveRecord,
  MVCFramework, PrivateControllerU, EntitiesU, System.StrUtils, System.SysUtils;

type
  TAuthCriteria = class(TInterfacedObject, IMVCAuthenticationHandler)
  public
    procedure OnRequest(const AContext: TWebContext;
      const AControllerQualifiedClassName, AActionName: string;
      var AAuthenticationRequired: Boolean);
    procedure OnAuthentication(const AContext: TWebContext; const AUserName,
      APassword: string; AUserRoles: TList<string>; var AIsValid: Boolean;
      const ASessionData: TDictionary<string, string>);
    procedure OnAuthorization(const AContext: TWebContext;
      AUserRoles: TList<string>; const AControllerQualifiedClassName: string;
      const AActionName: string; var AIsAuthorized: Boolean);
 end;

implementation

procedure TAuthCriteria.OnRequest(const AContext: TWebContext;
  const AControllerQualifiedClassName, AActionName: string;
  var AAuthenticationRequired: Boolean);
begin
  AAuthenticationRequired := True;
end;

procedure TAuthCriteria.OnAuthentication(const AContext: TWebContext;
  const AUserName, APassword: string; AUserRoles: TList<string>;
  var AIsValid: Boolean; const ASessionData: TDictionary<string, string>);
var
  LConn: TFDConnection;
  LUser: TUserPasswordChecker;
begin
  inherited;

  LConn := TFDConnection.Create(nil);
  LConn.ConnectionDefName := 'Municipal_Library_Connection';
  ActiveRecordConnectionsRegistry.AddDefaultConnection(LConn, True);

  LUser := TMVCActiveRecord
    .GetOneByWhere<TUserPasswordChecker>('email = ? and not deleted',
    [AUserName], False);

  try
    AIsValid := Assigned(LUser) and LUser.IsValid(APassword);
    if not AIsValid then
    begin
      Exit;
    end;
    //all valid users have "guest"
    AUserRoles.Add('guest');
    if EndsText('@library.com', AUserName) then
    begin
      //the employee are recognized using their email
      AUserRoles.Add('employee');
    end;
    LUser.LastLogin := Now;
    LUser.Update;
    //Let's save in the custom claims the user's user_id
    ASessionData.AddOrSetValue('user_id', LUser.ID.ToString);
  finally
    LUser.Free;
    ActiveRecordConnectionsRegistry.RemoveDefaultConnection;
  end;
end;

procedure TAuthCriteria.OnAuthorization(const AContext: TWebContext;
  AUserRoles: TList<string>; const AControllerQualifiedClassName: string;
  const AActionName: string; var AIsAuthorized: Boolean);
begin
  AIsAuthorized := False;

  if AUserRoles.Contains('employee') then
  begin
    AIsAuthorized := True;
    Exit;
  end
  else
  begin
    {
      Permissions for GUESTS are:
      1. UserController - Change Password Only
      2. Author - GET request only
      3. Books - GET request only
    }

    AIsAuthorized := ((AControllerQualifiedClassName =
      'UserControllerU.TUserController') and
      (AActionName = 'ChangeCurrentUserPassword')) or
      ((AControllerQualifiedClassName = 'AuthorControllerU.TAuthorController')
      and (AContext.Request.HTTPMethodAsString = 'GET')) or
      ((AControllerQualifiedClassName = 'BookControllerU.TBookController')
      and (AContext.Request.HTTPMethodAsString = 'GET'));
  end;
end;

end.
