unit uConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, fpjson, jsonparser;

type
  TItemType = (itApp, itUrl, itDir, itSep);

  TMenuItem = class;

  { TMenuItemList }
  TMenuItemList = class(TObjectList)
  private
    function GetItem(Index: Integer): TMenuItem;
  public
    function Add(AItem: TMenuItem): Integer;
    property Items[Index: Integer]: TMenuItem read GetItem; default;
  end;

  { TMenuItem }
  TMenuItem = class
  public
    Caption: string;
    Typ: TItemType;
    Target: string;
    Params: string;
    WorkDir: string;
    Admin: Boolean;
    Children: TMenuItemList;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

  TEdge = (edTop, edBottom, edLeft, edRight);
  TEdges = set of TEdge;

  { TConfig }
  TConfig = class
  public
    Edges: TEdges;
    DwellMs: Integer;
    EdgeZonePx: Integer;   // 边缘触发热区宽度 px
    Items: TMenuItemList;
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const AFile: string);
    procedure SaveToFile(const AFile: string);
  end;

function ConfigFilePath: string;
function ItemTypeToStr(T: TItemType): string;
function StrToItemType(const S: string): TItemType;
procedure DebugLog(const S: string);  // 追加调试日志到 config 同目录 debug.log

var
  Config: TConfig;

implementation

const
  APP_DIR_NAME = 'octopus-launch';

function ConfigFilePath: string;
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + APP_DIR_NAME;
  ForceDirectories(Dir);
  Result := IncludeTrailingPathDelimiter(Dir) + 'config.json';
end;

function ItemTypeToStr(T: TItemType): string;
begin
  case T of
    itApp: Result := 'app';
    itUrl: Result := 'url';
    itDir: Result := 'dir';
    itSep: Result := 'sep';
  else
    Result := 'app';
  end;
end;

function StrToItemType(const S: string): TItemType;
begin
  if S = 'url' then Result := itUrl
  else if S = 'dir' then Result := itDir
  else if S = 'sep' then Result := itSep
  else Result := itApp;
end;

procedure DebugLog(const S: string);
var
  F: TextFile;
begin
  AssignFile(F, ExtractFilePath(ConfigFilePath) + 'debug.log');
  if FileExists(ExtractFilePath(ConfigFilePath) + 'debug.log') then
    Append(F)
  else
    Rewrite(F);
  try
    Writeln(F, FormatDateTime('hh:nn:ss.zzz', Now) + ' ' + S);
  finally
    CloseFile(F);
  end;
end;

{ TMenuItemList }

function TMenuItemList.GetItem(Index: Integer): TMenuItem;
begin
  Result := TMenuItem(inherited Items[Index]);
end;

function TMenuItemList.Add(AItem: TMenuItem): Integer;
begin
  Result := inherited Add(AItem);
end;

{ TMenuItem }

constructor TMenuItem.Create;
begin
  inherited Create;
  Children := TMenuItemList.Create(True);
end;

destructor TMenuItem.Destroy;
begin
  Children.Free;
  inherited Destroy;
end;

{ TConfig }

constructor TConfig.Create;
begin
  inherited Create;
  Items := TMenuItemList.Create(True);
  Edges := [edTop, edBottom];
  DwellMs := 300;
  EdgeZonePx := 10;
end;

destructor TConfig.Destroy;
begin
  Items.Free;
  inherited Destroy;
end;

procedure ParseMenuItem(AObj: TJSONObject; AItem: TMenuItem);
var
  J: TJSONData;
  Arr: TJSONArray;
  I: Integer;
  Child: TMenuItem;
begin
  AItem.Caption := AObj.Get('name', '');
  AItem.Typ := StrToItemType(AObj.Get('type', 'app'));
  AItem.Target := AObj.Get('target', '');
  AItem.Params := AObj.Get('params', '');
  AItem.WorkDir := AObj.Get('workdir', '');
  AItem.Admin := AObj.Get('admin', False);
  J := AObj.Find('children');
  if (J <> nil) and (J.JSONType = jtArray) then
  begin
    Arr := TJSONArray(J);
    for I := 0 to Arr.Count - 1 do
      if Arr.Objects[I] <> nil then
      begin
        Child := TMenuItem.Create;
        ParseMenuItem(Arr.Objects[I], Child);
        if (Child.Typ <> itSep) and (Child.Caption = '') then
          Child.Caption := '(未命名)';
        AItem.Children.Add(Child);
      end;
  end;
end;

procedure TConfig.LoadFromFile(const AFile: string);
var
  Root: TJSONData;
  Obj, ChildObj: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Item: TMenuItem;
  EdgeStr: string;
  EdgeArr: TJSONArray;
begin
  if not FileExists(AFile) then Exit;
  with TStringList.Create do
  try
    LoadFromFile(AFile, TEncoding.UTF8);
    Root := GetJSON(Text);
  finally
    Free;
  end;
  try
    if not (Root.JSONType = jtObject) then Exit;
    Obj := TJSONObject(Root);

    Edges := [];
    EdgeArr := TJSONArray(Obj.Find('edges'));
    if EdgeArr <> nil then
      for I := 0 to EdgeArr.Count - 1 do
      begin
        EdgeStr := EdgeArr.Strings[I];
        if EdgeStr = 'top' then Include(Edges, edTop)
        else if EdgeStr = 'bottom' then Include(Edges, edBottom)
        else if EdgeStr = 'left' then Include(Edges, edLeft)
        else if EdgeStr = 'right' then Include(Edges, edRight);
      end;

    DwellMs := Obj.Get('dwellMs', 300);
    if DwellMs < 0 then DwellMs := 0;
    if DwellMs > 5000 then DwellMs := 5000;

    EdgeZonePx := Obj.Get('edgeZone', 10);
    if EdgeZonePx < 2 then EdgeZonePx := 2;
    if EdgeZonePx > 200 then EdgeZonePx := 200;

    Items.Clear;
    Arr := TJSONArray(Obj.Find('menu'));
    if Arr <> nil then
      for I := 0 to Arr.Count - 1 do
      begin
        ChildObj := Arr.Objects[I];
        if ChildObj = nil then Continue;
        Item := TMenuItem.Create;
        ParseMenuItem(ChildObj, Item);
        if (Item.Typ <> itSep) and (Item.Caption = '') then
          Item.Caption := '(未命名)';
        Items.Add(Item);
      end;
  finally
    Root.Free;
  end;
end;

procedure WriteItemToJSON(AItem: TMenuItem; AObj: TJSONObject);
var
  Arr: TJSONArray;
  I: Integer;
  ChildObj: TJSONObject;
begin
  AObj.Add('name', AItem.Caption);
  AObj.Add('type', ItemTypeToStr(AItem.Typ));
  AObj.Add('target', AItem.Target);
  AObj.Add('params', AItem.Params);
  AObj.Add('workdir', AItem.WorkDir);
  AObj.Add('admin', AItem.Admin);
  if AItem.Children.Count > 0 then
  begin
    Arr := TJSONArray.Create;
    for I := 0 to AItem.Children.Count - 1 do
    begin
      ChildObj := TJSONObject.Create;
      WriteItemToJSON(AItem.Children[I], ChildObj);
      Arr.Add(ChildObj);
    end;
    AObj.Add('children', Arr);
  end;
end;

procedure TConfig.SaveToFile(const AFile: string);
var
  Root: TJSONObject;
  EdgeArr: TJSONArray;
  MenuArr: TJSONArray;
  I: Integer;
  Obj: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    EdgeArr := TJSONArray.Create;
    if edTop in Edges then EdgeArr.Add('top');
    if edBottom in Edges then EdgeArr.Add('bottom');
    if edLeft in Edges then EdgeArr.Add('left');
    if edRight in Edges then EdgeArr.Add('right');
    Root.Add('edges', EdgeArr);
    Root.Add('dwellMs', DwellMs);
    Root.Add('edgeZone', EdgeZonePx);

    MenuArr := TJSONArray.Create;
    for I := 0 to Items.Count - 1 do
    begin
      Obj := TJSONObject.Create;
      WriteItemToJSON(Items[I], Obj);
      MenuArr.Add(Obj);
    end;
    Root.Add('menu', MenuArr);

    ForceDirectories(ExtractFilePath(AFile));
    with TStringList.Create do
    try
      Text := Root.FormatJSON([], 2);
      SaveToFile(AFile, TEncoding.UTF8);
    finally
      Free;
    end;
  finally
    Root.Free;
  end;
end;

initialization
  Config := TConfig.Create;

finalization
  Config.Free;

end.
