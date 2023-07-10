unit CommonsU;

interface

uses
  MVCFramework.ActiveRecord, MVCFramework.Commons, EntitiesU, System.Math,
  MVCFramework.Serializer.Commons,  System.SysUtils, MVCFramework.Logger,
  System.StrUtils, FireDAC.Stan.Error, System.Generics.Collections, System.JSON;

type
  TSysConst = class(TObject)
  public
    const PAGE_SIZE = 10;
    const PASSWORD_HASHING_ITERATION_COUNT = 5;
    const PASSWORD_KEY_SIZE = 12;
  end;

type
  TPagination = class(TObject)
  public
    class function GetTotalPages<T: TMVCActiveRecord, constructor>
      (ARQL: string): Integer;
    class function GetInfo(const ACurrPageNumber: UInt32;
      const ATotalPage: UInt32; const AURITemplate, AFilterQuery: string;
      const AForRQLQuery: boolean = true):TMVCStringDictionary;
  end;

function AppendIfNotEmpty(const AQueryParams, AtoAppend: string): string;

implementation

function AppendIfNotEmpty(const AQueryParams, AtoAppend: string): string;
var
  Query: string;
begin
  { temporarily assign query param here }
  query := '';
  if not AQueryParams.IsEmpty then
    { if params exist, add semicolon}
    Query := AQueryParams + AtoAppend;
  { return the additional query to be added to lRQL }
  Result := Query;
end;

{ TPagination }
class function TPagination.GetTotalPages<T>(ARQL: String): Integer;
var
  LRecordCount: Integer;
begin
  LRecordCount := TMVCActiveRecord.Count<T>(ARQL);
  Result := Ceil(LRecordCount / TSysConst.PAGE_SIZE);
end;

class function TPagination.GetInfo(const ACurrPageNumber: UInt32;
  const ATotalPage: UInt32; const AURITemplate, AFilterQuery: String;
  const AForRQLQuery: Boolean = true): TMVCStringDictionary;
var
  LQuery: string;
  LInfoKeys: array of string;
  LInfoValues: array of string;
begin
  Insert('curr_page', LInfoKeys, 0);
  Insert(ACurrPageNumber.ToString(), LInfoValues, 0);

  Insert('total_page', LInfoKeys, 0);
  Insert(ATotalPage.ToString(), LInfoValues, 0);

  { get additional filter query if params 'q' exists }
  if (not AFilterQuery.IsEmpty) and AForRQLQuery then
    LQuery := 'q=' + AppendIfNotEmpty(AFilterQuery, '&')
  else
    LQuery := AFilterQuery;

  if ACurrPageNumber > 1 then
  begin
    Insert('prev_page_uri', LInfoKeys, 0);
    Insert(Format(AURITemplate, [LQuery, (ACurrPageNumber - 1)]), LInfoValues, 0);
  end;

  if ATotalPage > ACurrPageNumber then
  begin
    Insert('next_page_uri', LInfoKeys, 0);
    Insert(Format(AURITemplate, [LQuery, (ACurrPageNumber + 1)]), LInfoValues, 0);
  end;
  Result := StrDict(LInfoKeys, LInfoValues);
end;

end.
