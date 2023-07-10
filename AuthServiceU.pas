unit AuthServiceU;

interface

uses CommonsU;

function GetPasswordHash(const ASalt, APassword: string): string;

implementation

uses
  System.SysUtils, MVCFramework.Commons, MVCFramework.Crypt.Utils;

function GetPasswordHash(const ASalt, APassword: string): string;
var
  LPwdUTF8Bytes: TBytes;
  LSaltUTF8Bytes: TBytes;
  LSaltedPassword: TBytes;
begin
  LPwdUTF8Bytes := TEncoding.UTF8.GetBytes(APassword);
  LSaltUTF8Bytes := TEncoding.UTF8.GetBytes(ASalt);
  LSaltedPassword := PBKDF2(LPwdUTF8Bytes, LSaltUTF8Bytes,
    TSysConst.PASSWORD_HASHING_ITERATION_COUNT, TSysConst.PASSWORD_KEY_SIZE);
  Result := BytesToHex(LSaltedPassword);
end;


end.
