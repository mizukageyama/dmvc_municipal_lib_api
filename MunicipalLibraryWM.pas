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
      // session timeout (0 means session cookie)
      Config[TMVCConfigKey.SessionTimeout] := '0';
      //default content-type
      Config[TMVCConfigKey.DefaultContentType] := TMVCConstants.DEFAULT_CONTENT_TYPE;
      //default content charset
      Config[TMVCConfigKey.DefaultContentCharset] := TMVCConstants.DEFAULT_CONTENT_CHARSET;
      //unhandled actions are permitted?
      Config[TMVCConfigKey.AllowUnhandledAction] := 'false';
      //enables or not system controllers loading (available only from localhost requests)
      Config[TMVCConfigKey.LoadSystemControllers] := 'false';
      //default view file extension
      Config[TMVCConfigKey.DefaultViewFileExtension] := 'html';
      //view path
      Config[TMVCConfigKey.ViewPath] := 'templates';
      //Max Record Count for automatic Entities CRUD
      Config[TMVCConfigKey.MaxEntitiesRecordCount] := '20';
      //Enable Server Signature in response
      Config[TMVCConfigKey.ExposeServerSignature] := 'true';
      //Enable X-Powered-By Header in response
      Config[TMVCConfigKey.ExposeXPoweredBy] := 'true';
      // Max request size in bytes
      Config[TMVCConfigKey.MaxRequestSize] := IntToStr(TMVCConstants.DEFAULT_MAX_REQUEST_SIZE);
    end);

  FMVC.AddController(TBookController);
  FMVC.AddController(TCustomerController);
  FMVC.AddController(TAuthorController);
  FMVC.AddController(TLendingController);
  FMVC.AddController(TUserController);

  lSwagInfo.Title := 'Sample Swagger API';
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
  // Analytics middleware generates a csv log, useful to do trafic analysis
  //FMVC.AddMiddleware(TMVCAnalyticsMiddleware.Create(GetAnalyticsDefaultLogger));
  
  // The folder mapped as documentroot for TMVCStaticFilesMiddleware must exists!
  //FMVC.AddMiddleware(TMVCStaticFilesMiddleware.Create('/static', TPath.Combine(ExtractFilePath(GetModuleName(HInstance)), 'www')));
  
  // Trace middlewares produces a much detailed log for debug purposes
  //FMVC.AddMiddleware(TMVCTraceMiddleware.Create);

  // CORS middleware handles... well, CORS
  FMVC.AddMiddleware(TMVCCORSMiddleware.Create);
  
  // Simplifies TMVCActiveRecord connection definition
  //FMVC.AddMiddleware(TMVCActiveRecordMiddleware.Create('Municipal_Library_Connection'));
  
  // Compression middleware must be the last in the chain, just before the ETag, if present.
  FMVC.AddMiddleware(TMVCCompressionMiddleware.Create);
  
  // ETag middleware must be the latest in the chain
  //FMVC.AddMiddleware(TMVCETagMiddleware.Create);
 
   

  {
  FMVC.OnWebContextCreate(
    procedure(const Context: TWebContext) 
    begin 
      // Initialize services to make them accessibile from Context 
      // Context.CustomIntfObject := TMyService.Create; 
    end); 
  
  FMVC.OnWebContextDestroy(
    procedure(const Context: TWebContext)
    begin
      //Cleanup services, if needed
    end);
  }
end;

procedure TMunicipalLibraryWebModule.WebModuleDestroy(Sender: TObject);
begin
  FMVC.Free;
end;

end.
