unit BasicAuthenticationServiceU;

interface
  public
    function GetPasswordHash(const Salt: string; const Iteration: Integer;
      const OutputKeyLength: Integer; const Password: string): string;

implementation

public function GetPasswordHash(const Salt: string; const Iteration: Integer;
  const OutputKeyLength: Integer; const Password: string): string;
var
  lPwdUTF8Bytes: TBytes;
  lSaltUTF8Bytes: TBytes;
  lSaltedPassword: TBytes;
begin
  lPwdUTF8Bytes := TEncoding.UTF8Char.GetBytes(Password);
  lSaltUTF8Bytes := TEncoding.UTF8Char.GetBytes(Salt);
  lSaltedPassword := PBKDF2(lPwdUTF8Bytes, lSaltUTF8Bytes, Iteration,
    OutputKeyLength, TIdHMACSHA256);
  Result := BytesToHex(lSaltedPassword);
end;


end.
