unit AuthCriteriaU;

interface

uses
  System.Generics.Collections,
  MVCFramework, PrivateControllerU;

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
  AAuthenticationRequired :=  AControllerQualifiedClassName =
    TPrivateController.QualifiedClassName;
end;

procedure TAuthCriteria.OnAuthentication(const AContext: TWebContext; const AUserName,
  APassword: string; AUserRoles: TList<string>; var AIsValid: Boolean;
  const ASessionData: TDictionary<string, string>);
begin
  AIsValid := APassword = ('pwd' + AUserName);
  if not AIsValid then
    Exit;
  if AUserName = 'user1' then
    AUserRoles.Add('role1')
  else if AUserName = 'user2' then
    AUserRoles.Add('role2')
  else if AUserName = 'user3' then
  begin
    AUserRoles.Add('role1');
    AUserRoles.Add('role2');
  end;
  AIsValid := AUserRoles.Count > 0;
end;

procedure TAuthCriteria.OnAuthorization(const AContext: TWebContext;
  AUserRoles: TList<string>; const AControllerQualifiedClassName: string;
  const AActionName: string; var AIsAuthorized: Boolean);
begin
  AIsAuthorized := False;

  if AUserRoles.Contains('role1') then
  begin
    AIsAuthorized := AIsAuthorized or (AActionName = 'ActionForRole1');
  end;

  if AUserRoles.Contains('role2') then
  begin
    AIsAuthorized := AIsAuthorized or (AActionName = 'ActionForRole2');
  end;
end;

end.
