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
    procedure EnsureRole(const ARole: string);
    procedure EnsureOneOf(const ARoles: TArray<string>);
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Param, MVCFramework.ActiveRecord;

procedure TBaseController.EnsureOneOf(const ARoles: TArray<string>);
var
  LRole: string;
begin
  for LRole in ARoles do
  begin
    if Context.LoggedUser.Roles.Contains(LRole) then
    begin
      Exit;
    end;
  end;
  raise EMVCException.Create(HTTP_STATUS.Forbidden, 'Forbidden');
end;

procedure TBaseController.EnsureRole(const ARole: string);
begin
  if not Context.LoggedUser.Roles.Contains(ARole) then
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
  LConn: TFDConnection;
begin
  inherited;
  LConn := TFDConnection.Create(nil);
  LConn.ConnectionDefName := 'Municipal_Library_Connection';
  ActiveRecordConnectionsRegistry.AddDefaultConnection(LConn, True);
end;

end.
