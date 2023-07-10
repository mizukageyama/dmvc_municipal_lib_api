unit MunicipalLibraryWM;

interface

uses 
  System.SysUtils,
  System.Classes,
  Web.HTTPApp,
  MVCFramework, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.VCLUI.Wait, Data.DB,
  FireDAC.Comp.Client, FireDAC.Phys.MySQLDef, FireDAC.Phys.MySQL;

type
  TMunicipalLibraryWebModule = class(TWebModule)
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleDestroy(Sender: TObject);
  private
    FMVC: TMVCEngine;
  public
    { Public declarations }
  end;

var
  WebModuleClass: TComponentClass = TMunicipalLibraryWebModule;

implementation

{$R *.dfm}

uses
  CustomerControllerU,
  System.IOUtils,
  MVCFramework.Commons,
  MVCFramework.JWT,
  MVCFramework.Middleware.JWT,
  MVCFramework.Middleware.ActiveRecord,
  MVCFramework.Middleware.StaticFiles, 
  MVCFramework.Middleware.Analytics,
  MVCFramework.Middleware.Trace, 
  MVCFramework.Middleware.CORS, 
  MVCFramework.Middleware.ETag, MVCFramework.Swagger.Commons,
  MVCFramework.Middleware.Compression, AuthorControllerU, LendingControllerU,
  UserControllerU, BookControllerU, AuthCriteriaU, PrivateControllerU,
  PublicControllerU, MVCFramework.Crypt.Utils, MVCFramework.Middleware.Swagger;

procedure TMunicipalLibraryWebModule.WebModuleCreate(Sender: TObject);
var
  lSwagInfo: TMVCSwaggerInfo;
begin
  FMVC := TMVCEngine.Create(Self,
    procedure(Config: TMVCConfig)
    begin
      Config[TMVCConfigKey.SessionTimeout] := '0';
      Config[TMVCConfigKey.DefaultContentType] := TMVCConstants
        .DEFAULT_CONTENT_TYPE;
      Config[TMVCConfigKey.DefaultContentCharset] := TMVCConstants
        .DEFAULT_CONTENT_CHARSET;
      Config[TMVCConfigKey.AllowUnhandledAction] := 'false';
      Config[TMVCConfigKey.LoadSystemControllers] := 'false';
      Config[TMVCConfigKey.DefaultViewFileExtension] := 'html';
      Config[TMVCConfigKey.ViewPath] := 'templates';
      Config[TMVCConfigKey.MaxEntitiesRecordCount] := '20';
      Config[TMVCConfigKey.ExposeServerSignature] := 'true';
      Config[TMVCConfigKey.ExposeXPoweredBy] := 'true';
      Config[TMVCConfigKey.MaxRequestSize] :=
        IntToStr(TMVCConstants.DEFAULT_MAX_REQUEST_SIZE);
    end);

  FMVC.AddController(TBookController);
  FMVC.AddController(TCustomerController);
  FMVC.AddController(TAuthorController);
  FMVC.AddController(TLendingController);
  FMVC.AddController(TUserController);

  lSwagInfo.Title := 'Municipal Library API';
  lSwagInfo.Version := 'v1';
  lSwagInfo.TermsOfService := 'http://www.apache.org/licenses/LICENSE-2.0.txt';
  lSwagInfo.Description := 'Swagger Documentation Example';
  lSwagInfo.ContactName := 'DelphiMVCFramework Team';
  lSwagInfo.ContactEmail := 'contactmail@dmvc.com';
  lSwagInfo.ContactUrl := 'https://github.com/danieleteti/delphimvcframework';
  lSwagInfo.LicenseName := 'Apache License - Version 2.0, January 2004';
  lSwagInfo.LicenseUrl := 'http://www.apache.org/licenses/LICENSE-2.0';

  FMVC.AddMiddleWare(TMVCSwaggerMiddleware.Create(FMVC, lSwagInfo,
    '/api/swagger.json'));

  FMVC.AddMiddleware(TMVCStaticFilesMiddleware.Create('/swagger',
    TPath.Combine(ExtractFilePath(GetModuleName(HInstance)),
    '..\..\swagger-ui')));

  var lConfigClaims: TJWTClaimsSetup := procedure (const JWT: TJWT)
    begin
      JWT.Claims.Issuer := 'Municipal Library';
      //JWT will expire in 1 hour
      JWT.Claims.ExpirationTime := Now + EncodeTime(1, 0, 0, 0);
      JWT.Claims.NotBefore := Now - EncodeTime(0, 5, 0, 0);
    end;

  FMVC.AddMiddleware(
    TMVCJWTAuthenticationMiddleware.Create(
      TAuthCriteria.Create,
      lConfigClaims,
      'this_is_my_secret',
      '/api/login',
      [TJWTCheckableClaim.ExpirationTime, TJWTCheckableClaim.NotBefore]
    )
  );

  MVCCryptInit; //Initialize OpenSSL
  FMVC.AddMiddleware(TMVCCORSMiddleware.Create); //CORS Middleware
  FMVC.AddMiddleware(TMVCCompressionMiddleware.Create);
end;

procedure TMunicipalLibraryWebModule.WebModuleDestroy(Sender: TObject);
begin
  FMVC.Free;
end;

end.
