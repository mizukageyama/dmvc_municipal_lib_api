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

procedure TAuthCriteria.OnAuthentication(const AContext: TWebContext; const AUserName,
  APassword: string; AUserRoles: TList<string>; var AIsValid: Boolean;
  const ASessionData: TDictionary<string, string>);
var
  lConn: TFDConnection;
  lUser: TUserPasswordChecker;
begin
  inherited;

  lConn := TFDConnection.Create(nil);
  lConn.ConnectionDefName := 'Municipal_Library_Connection';
  ActiveRecordConnectionsRegistry.AddDefaultConnection(lConn, True);

  lUser := TMVCActiveRecord
    .GetOneByWhere<TUserPasswordChecker>('email = ? and not deleted',
    [AUserName], False);

  try
    AIsValid := Assigned(lUser) and lUser.IsValid(APassword);
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
    lUser.LastLogin := Now;
    lUser.Update;
    //Let's save in the custom claims the user's user_id
    ASessionData.AddOrSetValue('user_id', lUser.ID.ToString);
  finally
    lUser.Free;
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
    //All the guests can invoke any actions which not belongs to
    //TUserController, and however, can invoke all the "read" methods.
    //Simply put, they cannot do an change on the users.
    AIsAuthorized := (AControllerQualifiedClassName <>
      'UserControllerU.TUserController') or
      (AContext.Request.HTTPMethodAsString = 'GET');
  end;
end;

end.
