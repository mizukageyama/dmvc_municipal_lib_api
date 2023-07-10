unit AuthServiceU;

interface

uses CommonsU;

function GetPasswordHash(const Salt, Password: string): string;

implementation

uses
  System.SysUtils, MVCFramework.Commons, MVCFramework.Crypt.Utils;

function GetPasswordHash(const Salt, Password: string): string;
var
  lPwdUTF8Bytes: TBytes;
  lSaltUTF8Bytes: TBytes;
  lSaltedPassword: TBytes;
begin
  lPwdUTF8Bytes := TEncoding.UTF8.GetBytes(Password);
  lSaltUTF8Bytes := TEncoding.UTF8.GetBytes(Salt);
  lSaltedPassword := PBKDF2(lPwdUTF8Bytes, lSaltUTF8Bytes,
    TSysConst.PASSWORD_HASHING_ITERATION_COUNT, TSysConst.PASSWORD_KEY_SIZE);
  Result := BytesToHex(lSaltedPassword);
end;


end.
