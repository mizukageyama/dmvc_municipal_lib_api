unit PublicControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons;

type
  [MVCPath('/api/public')]
  TPublicController = class(TMVCController)
  public
    [MVCPath]
    [MVCHTTPMethod([httpGET])]
    procedure Index;
  end;

implementation

uses
  System.SysUtils, MVCFramework.Logger, System.StrUtils;


{ TPublicController }

procedure TPublicController.Index;
begin
  { we are going to produce simple text.
    let's inform the client about the format
    of the body response format }
  ContentType := TMVCMediaType.TEXT_PLAIN;
  { Render a simple string }
  Render('Hello World! It''s ' + TimeToStr(Time) + ' in DMVCFrameworkLand');
end;

end.

