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
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Param, MVCFramework.ActiveRecord;

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
