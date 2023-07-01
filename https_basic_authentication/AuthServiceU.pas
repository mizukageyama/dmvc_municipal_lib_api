unit AuthServiceU;

interface

type
  TAuthService = class(TObject)
  end;

function GetPasswordHash(const Salt: string; const Iteration,
  OutputKeyLength: Integer; const Password: string): string;

implementation

uses
  System.SysUtils, MVCFramework.Commons, MVCFramework.Crypt.Utils;

function GetPasswordHash(const Salt: string; const Iteration,
  OutputKeyLength: Integer; const Password: string): string;
var
  lPwdUTF8Bytes: TBytes;
  lSaltUTF8Bytes: TBytes;
  lSaltedPassword: TBytes;
begin
  lPwdUTF8Bytes := TEncoding.UTF8.GetBytes(Password);
  lSaltUTF8Bytes := TEncoding.UTF8.GetBytes(Salt);
  lSaltedPassword := PBKDF2(lPwdUTF8Bytes, lSaltUTF8Bytes, Iteration,
    OutputKeyLength);
  Result := BytesToHex(lSaltedPassword);
end;


end.
