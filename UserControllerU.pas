unit UserControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, BaseControllerU, System.SysUtils,
  MVCFramework.Logger, System.StrUtils, EntitiesU,
  System.Math, CommonsU, FireDAC.Stan.Error, System.Generics.Collections,
  MVCFramework.Swagger.Commons;

type
  [MVCPath('/api/users')]
  TUserController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('User', 'It returns all the users not logically deleted ' +
      '(password hash is not shown) and allows to apply a filter.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetUsers;

    [MVCPath]
    [MVCSwagSummary('User', 'It creates a new user and returns the new user ' +
      'URI.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'User data', TUserWithPassword)]
    [MVCHTTPMethod([httpPOST])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure CreateUser;

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It returns a single user using its user ID.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpGET])]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure GetUserByID(const UserID: Integer);

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It updates a user using its user ID.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'User data', TUser)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    [MVCProduces(TMVCMediaType.APPLICATION_JSON)]
    procedure UpdateUserByID(const UserID: Integer);

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It logically deletes a user using its user ID. ' +
      'The record is not physically deleted but its deleted field is ' +
      'set to True.')]
    [MVCSwagAuthentication]
    [MVCHTTPMethod([httpDELETE])]
    procedure DeleteUserByID(const UserID: Integer);

    [MVCPath('/me/password')]
    [MVCSwagSummary('User', 'Any user can change its password after login.')]
    [MVCSwagAuthentication]
    [MVCSwagParam(plBody, 'body', 'User data', TUserWithPassword)]
    [MVCHTTPMethod([httpPUT])]
    [MVCConsumes(TMVCMediaType.APPLICATION_JSON)]
    procedure ChangeCurrentUserPassword;
  end;

implementation

uses
   MVCFramework.Serializer.JsonDataObjects, JsonDataObjects;

{ TUserController }

procedure TUserController.ChangeCurrentUserPassword;
var
  LUser: TUserWithPassword;
  LJSONObject: TJSONObject;
begin
  lJSONObject := StrToJSONObject(Context.Request.Body);
  try
    LUser := TMVCActiveRecord.GetOneByWhere<TUserWithPassword>(
      'email = ? and not deleted', [Context.LoggedUser.UserName], True);
   LUser.Password := LJSONObject.S['pwd'];
   LUser.Update;
   Render204NoContent('/api/users/' + LUser.ID.ToString,
     'Password Changed Successfully');
 finally
   LUser.Free;
 end;
end;

procedure TUserController.CreateUser;
var
  LUser: TUserWithPassword;
begin
  LUser := Context.Request.BodyAs<TUserWithPassword>;
  try
    try
      LUser.Deleted := False;
      LUser.Insert;
    except
      on E: EFDException do
      begin
        if E.Message.ToLower.Contains('user_email_idx') then
        begin
          raise Exception.CreateFmt('User "%s" already exists', [LUser.Email]);
        end;
        raise;
      end;
    end;
    Render201Created('/api/users/' + LUser.ID.ToString);
  finally
    LUser.Free;
  end;
end;

procedure TUserController.DeleteUserByID(const UserID: Integer);
var
  LUser: TUser;
begin
  if Context.LoggedUser.CustomData['user_id'].ToInteger = UserID then
  begin
    raise EMVCException.Create(HTTP_STATUS.Unauthorized,
      'Current user cannot be deleted');
  end;

  LUser := TMVCActiveRecord.GetByPK<TUser>(UserID, True);
  try
    LUser.Deleted := True;
    LUser.Update;
    Render204NoContent('', 'User deleted');
  finally
    LUser.Free;
  end;
end;

procedure TUserController.GetUserByID(const UserID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.GetOneByWhere<TUser>('id = ?', [UserID])));
end;

procedure TUserController.GetUsers;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LFirstRec: Integer;
  LRQL: string;
  LFilterQuery: string;
  LUsers: TObjectList<TUser>;
begin
  LCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], LCurrentPage);
  LCurrentPage := Max(LCurrentPage, 1);
  LFirstRec := (LCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  LFilterQuery := Context.Request.Params['q'];
  if LFilterQuery.IsEmpty then
    LFilterQuery := 'ne(deleted, 1)'
  else
    LFilterQuery := 'and(' + AppendIfNotEmpty(LFilterQuery, ',ne(deleted, 1))');

  LRQL := AppendIfNotEmpty(LFilterQuery, ';');

  LRQL := Format('%ssort(+Email, +ID);limit(%d,%d)',
    [LRQL, LFirstRec, TSysConst.PAGE_SIZE]);

  LTotalPages := TPagination.GetTotalPages<TUser>(LFilterQuery);
  LUsers := TMVCActiveRecord.SelectRQL<TUser>(LRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      LUsers,
      procedure(const User: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/users/' + TUser(User).ID.ToString).
          Add(HATEOAS.REL, 'self');
      end
    )
    .Add('meta', TPagination.GetInfo(LCurrentPage, LTotalPages,
      '/api/users?%spage=%d', LRQL))
  );
end;

procedure TUserController.UpdateUserByID(const UserID: Integer);
var
  lUser: TUser;
begin
  lUser := TMVCActiveRecord.GetByPK<TUser>(UserID, false);
  if Assigned(lUser) then
  begin
    try
      Context.Request.BodyFor<TUser>(lUser);
      lUser.Update;
      Render(HTTP_STATUS.OK, lUser, False);
    finally
      lUser.Free;
    end;
  end
  else
    Render(HTTP_STATUS.NotFound, 'User does not exist');
end;

end.
