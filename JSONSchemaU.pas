unit JSONSchemaU;

interface

uses
  System.SysUtils, Generics.Collections;

type
  TJSONSchemaClass = class
  private
    FProperties: TDictionary<string, Variant>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddProperty(const AName: string; const AValue: Variant);
    class function Author: TJSONSchemaClass;
  end;

  TJSONSchemaProperty = record
    Name: string;
    Value: Variant;
    constructor Create(const AName: string; const AValue: Variant);
  end;

function CreateJSONSchemaClass(const Properties: array of TJSONSchemaProperty): TJSONSchemaClass;

implementation

{ TJSONSchemaClass }

class function TJSONSchemaClass.Author: TJSONSchemaClass;
begin
  Result := CreateJSONSchemaClass([
      TJSONSchemaProperty.Create('name', 'John'),
      TJSONSchemaProperty.Create('age', 30)
    ])
end;

constructor TJSONSchemaClass.Create;
begin
  FProperties := TDictionary<string, Variant>.Create;
end;

destructor TJSONSchemaClass.Destroy;
begin
  FProperties.Free;
  inherited;
end;

procedure TJSONSchemaClass.AddProperty(const AName: string; const AValue: Variant);
begin
  FProperties.Add(AName, AValue);
end;

function CreateJSONSchemaClass(const Properties: array of TJSONSchemaProperty): TJSONSchemaClass;
var
  I: Integer;
begin
  Result := TJSONSchemaClass.Create;
  for I := Low(Properties) to High(Properties) do
    Result.AddProperty(Properties[I].Name, Properties[I].Value);
end;

{ TJSONSchemaProperty }

constructor TJSONSchemaProperty.Create(const AName: string;
  const AValue: Variant);
begin
  Name := AName;
  Value := AValue;
end;

end.
