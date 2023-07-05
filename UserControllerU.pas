unit UserControllerU;

interface

uses
  MVCFramework, MVCFramework.Commons, MVCFramework.Serializer.Commons,
  MVCFramework.ActiveRecord, BaseControllerU, System.SysUtils,
  MVCFramework.Logger, System.StrUtils, EntitiesU,
  System.Math, CommonsU, FireDAC.Stan.Error, System.Generics.Collections;

type
  [MVCPath('/api/users')]
  TUserController = class(TBaseController)
  public
    [MVCPath]
    [MVCSwagSummary('User', 'It returns all the users not logically deleted ' +
      '(password hash is not shown) and allows to apply a filter.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetUsers;

    [MVCPath]
    [MVCSwagSummary('User', 'It creates a new user and returns the new user URI.')]
    [MVCHTTPMethod([httpPOST])]
    procedure CreateUser;

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It returns a single user using its user ID.')]
    [MVCHTTPMethod([httpGET])]
    procedure GetUserByID(const UserID: Integer);

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It updates a user using its user ID.')]
    [MVCHTTPMethod([httpPUT])]
    procedure UpdateUserByID(const UserID: Integer);

    [MVCPath('/($UserID)')]
    [MVCSwagSummary('User', 'It logically deletes a user using its user ID. The record ' +
      'is not physically deleted but its deleted field is set to True.')]
    [MVCHTTPMethod([httpDELETE])]
    procedure DeleteUserByID(const UserID: Integer);

    [MVCPath('/me/password')]
    [MVCSwagSummary('User', 'Any user can change its password after login.')]
    [MVCHTTPMethod([httpPUT])]
    procedure ChangeCurrentUserPassword;
  end;

implementation

uses
   MVCFramework.Serializer.JsonDataObjects, JsonDataObjects;

{ TUserController }

procedure TUserController.ChangeCurrentUserPassword;
var
  lUser: TUserWithPassword;
begin
  EnsureOneOf(['employee', 'guest']);
  lUser := Context.Request.BodyAs<TUserWithPassword>;
  try
    lUser := TMVCActiveRecord.GetOneByWhere<TUserWithPassword>(
      'email = ? and not deleted', [Context.LoggedUser.UserName], True);

   lUser.Update;
   Render204NoContent('/api/users/' + lUser.ID.ToString);
 finally
   lUser.Free;
 end;

end;

procedure TUserController.CreateUser;
var
  lUser: TUserWithPassword;
begin
  EnsureRole('employee');
  lUser := Context.Request.BodyAs<TUserWithPassword>;
  try
    try
      lUser.Deleted := False;
      lUser.Insert;
    except
      on E: EFDException do
      begin
        if E.Message.ToLower.Contains('user_email_idx') then
        begin
          raise Exception.CreateFmt('User "%s" already exists', [lUser.Email]);
        end;
        raise;
      end;
    end;
    Render201Created('/api/users/' + lUser.ID.ToString);
  finally
    lUser.Free;
  end;
end;

procedure TUserController.DeleteUserByID(const UserID: Integer);
var
  lUser: TUser;
begin
  EnsureRole('employee');
  if Context.LoggedUser.CustomData['user_id'].ToInteger = UserID then
  begin
    raise EMVCException.Create(HTTP_STATUS.Unauthorized,
      'Current user cannot be deleted');
  end;

  lUser := TMVCActiveRecord.GetByPK<TUser>(UserID, True);
  try
    lUser.Deleted := True;
    lUser.Update;
    Render204NoContent('', 'User deleted');
  finally
    lUser.Free;
  end;
end;

procedure TUserController.GetUserByID(const UserID: Integer);
begin
  Render(
    ObjectDict().Add('data',
      TMVCActiveRecord.Where<TUser>('id = ?', [UserID]),
      procedure(const User: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/users/').
          Add(HATEOAS.REL, 'list');
      end
    )
  );
end;

procedure TUserController.GetUsers;
var
  lTotalPages: Integer;
  lCurrentPage: Integer;
  lFirstRec: Integer;
  lRQL: string;
  lFilterQuery: string;
  lUsers: TObjectList<TUser>;
begin
  { if current user doesn't have "employee" role, raise an exception }
  EnsureRole('employee');

  lCurrentPage := 0;
  TryStrToInt(Context.Request.Params['page'], lCurrentPage);
  lCurrentPage := Max(lCurrentPage, 1);
  lFirstRec := (lCurrentPage - 1) * TSysConst.PAGE_SIZE;
  { get additional filter query if params 'q' exists }
  lFilterQuery := Context.Request.Params['q'];
  lRQL := AppendIfNotEmpty(lFilterQuery, ';');

  lRQL := Format('%ssort(+Email, +ID);limit(%d,%d)',
    [lRQL, lFirstRec, TSysConst.PAGE_SIZE]);

  lTotalPages := TPagination.GetTotalPages<TUser>(lFilterQuery);
  lUsers := TMVCActiveRecord.SelectRQL<TUser>(lRQL, -1);

  Render(
    ObjectDict().Add(
      'data',
      lUsers,
      procedure(const User: TObject; const Links: IMVCLinks)
      begin
        Links.AddRefLink.
          Add(HATEOAS._TYPE, TMVCMediaType.APPLICATION_JSON).
          Add(HATEOAS.HREF, '/api/users/' + TUser(User).ID.ToString).
          Add(HATEOAS.REL, 'self');
      end
    )
    .Add('meta', TPagination.GetInfo(lCurrentPage, lTotalPages,
      '/api/users?%spage=%d', lRQl))
  );
end;

procedure TUserController.UpdateUserByID(const UserID: Integer);
var
  lUser: TUser;
begin
  EnsureRole('employee');
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
