unit BaseControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons;

type
  [MVCPath('/api')]
  TBaseController = class(TMVCController)
  protected
    procedure OnBeforeAction(Context: TWebContext; const AActionName: string;
      var Handled: Boolean); override;
    procedure OnAfterAction(Context: TWebContext; const AActionName: string);
      override;
    procedure EnsureRole(const Role: string);
    procedure EnsureOneOf(const Roles: TArray<string>);
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Param, MVCFramework.ActiveRecord;

procedure TBaseController.EnsureOneOf(const Roles: TArray<string>);
var
  lRole: string;
begin
  for lRole in Roles do
  begin
    if Context.LoggedUser.Roles.Contains(lRole) then
    begin
      Exit;
    end;
  end;
  raise EMVCException.Create(HTTP_STATUS.Forbidden, 'Forbidden');
end;

procedure TBaseController.EnsureRole(const Role: string);
begin
  if not Context.LoggedUser.Roles.Contains(Role) then
  begin
    raise EMVCException.Create(HTTP_STATUS.Forbidden, 'Forbidden');
  end;
end;

procedure TBaseController.OnAfterAction(Context: TWebContext;
  const AActionName: string);
begin
  ActiveRecordConnectionsRegistry.RemoveDefaultConnection;
  inherited;
end;

procedure TBaseController.OnBeforeAction(Context: TWebContext;
  const AActionName: string; var Handled: Boolean);
var
  lConn: TFDConnection;
begin
  inherited;
  lConn := TFDConnection.Create(nil);
  lConn.ConnectionDefName := 'Municipal_Library_Connection';
  ActiveRecordConnectionsRegistry.AddDefaultConnection(lConn, True);
end;

end.
