unit CommonsU;

interface

uses
  MVCFramework.ActiveRecord, MVCFramework.Commons, EntitiesU, System.Math,
  MVCFramework.Serializer.Commons,  System.SysUtils, MVCFramework.Logger,
  System.StrUtils, FireDAC.Stan.Error, System.Generics.Collections;

type
  TSysConst = class(TObject)
  public
    const PAGE_SIZE = 10;
    const PASSWORD_HASHING_ITERATION_COUNT = 5;
    const PASSWORD_KEY_SIZE = 7;
  end;

type
  TPagination = class(TObject)
  public
    class function GetTotalPages<T: TMVCActiveRecord, constructor>
      (lRQL: string): Integer;
    class function GetInfo(const CurrPageNumber: UInt32;
      const TotalPage: UInt32; const URITemplate, FilterQuery: string;
      const ForRQLQuery: boolean = true):TMVCStringDictionary;
  end;

function AppendIfNotEmpty(const lQueryParams, toAppend: string): string;


implementation

function AppendIfNotEmpty(const lQueryParams, toAppend: string): string;
var
  query: string;
begin
  { temporarily assign query param here }
  query := '';
  if not lQueryParams.IsEmpty then
    { if params exist, add semicolon}
    query := lQueryParams + toAppend;
  { return the additional query to be added to lRQL }
  Result := query;
end;

{ TPagination }
class function TPagination.GetTotalPages<T>(lRQL: string): Integer;
var
  lRecordCount: Integer;
begin
  lRecordCount := TMVCActiveRecord.Count<T>(lRQL);
  Result := Ceil(lRecordCount / TSysConst.PAGE_SIZE);
end;

class function TPagination.GetInfo(const CurrPageNumber: UInt32;
  const TotalPage: UInt32; const URITemplate, FilterQuery: string;
  const ForRQLQuery: boolean = true): TMVCStringDictionary;
var
  lQuery: string;
  lInfoKeys: array of string;
  lInfoValues: array of string;
begin
  Insert('curr_page', lInfoKeys, 0);
  Insert(CurrPageNumber.ToString(), lInfoValues, 0);

  { get additional filter query if params 'q' exists }
  if (not FilterQuery.IsEmpty) and ForRQLQuery then
    lQuery := 'q=' + AppendIfNotEmpty(FilterQuery, '&')
  else
    lQuery := FilterQuery;

  if CurrPageNumber > 1 then
  begin
    Insert('prev_page_uri', lInfoKeys, 0);
    Insert(Format(URITemplate, [lQuery, (CurrPageNumber - 1)]), lInfoValues, 0);
  end;

  if TotalPage > CurrPageNumber then
  begin
    Insert('next_page_uri', lInfoKeys, 0);
    Insert(Format(URITemplate, [lQuery, (CurrPageNumber + 1)]), lInfoValues, 0);
  end;
  Result := StrDict(lInfoKeys, lInfoValues);
end;

end.
