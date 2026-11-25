unit uSettings;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Spin, Dialogs, Graphics, uConfig;

type
  { TSettingsForm - 纯代码构建的设置窗口 }
  TSettingsForm = class(TForm)
  private
    FLoading: Boolean;
    FCurrent: TMenuItem;
    // 分组框与标签需保留引用，语言切换时统一更新文案并重排
    GBTrigger, GBMenu: TGroupBox;
    LblDwell, LblZone, LblName, LblType, LblTarget, LblParams, LblWorkDir,
    LblLang: TLabel;
    // 触发区
    CbTop, CbBottom, CbLeft, CbRight, CbAutoRun: TCheckBox;
    SeDwell, SeZone: TSpinEdit;
    // 菜单编辑区
    Tree: TTreeView;
    BtnAdd, BtnAddChild, BtnAddSep, BtnDelete, BtnUp, BtnDown: TButton;
    EdName: TEdit;
    CmbType: TComboBox;
    EdTarget, EdParams, EdWorkDir: TEdit;
    BtnBrowseTarget, BtnBrowseDir: TButton;
    CbAdmin: TCheckBox;
    BtnSave, BtnCancel: TButton;
    // 语言
    CmbLang: TComboBox;
    DlgOpen: TOpenDialog;
    DlgDir: TSelectDirectoryDialog;
    procedure BuildUI;
    // 按当前语言设置全部文案，并按实测文本宽度重排触发区（防中英文切换后撑破/重叠）
    procedure ApplyCaptions;
    procedure RebuildTree;
    function GetParentList(Node: TTreeNode): TMenuItemList;
    function FindNodeByData(AData: TObject): TTreeNode;
    // 在 List 的 AIdx 位置插入新项并选中对应树节点（无选中时调用方传 List.Count）
    procedure InsertAndSelect(List: TMenuItemList; AIdx: Integer; Item: TMenuItem);
    procedure LoadDetail(Node: TTreeNode);
    procedure CommitDetail;
    procedure UpdateDetailEnable;
    procedure SetDetailControls(AEnabled: Boolean);
    // 事件
    procedure TreeSelectionChanged(Sender: TObject);
    procedure LangChanged(Sender: TObject);
    procedure DoAdd(Sender: TObject);
    procedure DoAddChild(Sender: TObject);
    procedure DoAddSep(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoUp(Sender: TObject);
    procedure DoDown(Sender: TObject);
    procedure DoMove(Delta: Integer);
    procedure NameChanged(Sender: TObject);
    procedure TypeChanged(Sender: TObject);
    procedure TargetChanged(Sender: TObject);
    procedure ParamsChanged(Sender: TObject);
    procedure WorkDirChanged(Sender: TObject);
    procedure AdminChanged(Sender: TObject);
    procedure BrowseTarget(Sender: TObject);
    procedure BrowseDir(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoCancel(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

procedure ShowSettingsForm;

implementation

uses
  Registry, uHooks, uLang;

procedure ShowSettingsForm;
var
  I: Integer;
  F: TSettingsForm;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TSettingsForm then
    begin
      F := TSettingsForm(Screen.Forms[I]);
      // Close 默认是 caHide（隐藏不释放），隐藏状态必须重新 Show
      if not F.Visible then
        F.Show;
      if F.WindowState = wsMinimized then
        F.WindowState := wsNormal;
      F.BringToFront;
      SetForegroundWindow(F.Handle);
      Exit;
    end;
  F := TSettingsForm.CreateNew(Application);
  F.Show;
end;

{ TSettingsForm }

constructor TSettingsForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Width := 740;
  Height := 570;
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  Font.Name := 'Microsoft YaHei UI';
  Font.Size := 9;

  DlgOpen := TOpenDialog.Create(Self);
  DlgDir := TSelectDirectoryDialog.Create(Self);
  BuildUI;
  ApplyCaptions;
  RebuildTree;

  CbTop.Checked := edTop in Config.Edges;
  CbBottom.Checked := edBottom in Config.Edges;
  CbLeft.Checked := edLeft in Config.Edges;
  CbRight.Checked := edRight in Config.Edges;
  SeDwell.Value := Config.DwellMs;
  SeZone.Value := Config.EdgeZonePx;

  with TRegistry.Create do
  try
    RootKey := HKEY_CURRENT_USER;
    CbAutoRun.Checked := OpenKeyReadOnly(
      'Software\Microsoft\Windows\CurrentVersion\Run')
      and ValueExists('octopus-launch');
  finally
    Free;
  end;
end;

procedure TSettingsForm.BuildUI;

  function MakeCheck(AParent: TWinControl; AX, AY: Integer): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := AParent;
    Result.Left := AX;
    Result.Top := AY;
  end;

  function MakeBtn(AParent: TWinControl; const ACaption: string;
    AX, AY, AW: Integer; AHandler: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Left := AX;
    Result.Top := AY;
    Result.Width := AW;
    if Assigned(AHandler) then
      Result.OnClick := AHandler;
  end;

  function MakeLabel(AParent: TWinControl; AX, AY: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Left := AX;
    Result.Top := AY;
  end;

begin
  // ---- 触发 ----
  GBTrigger := TGroupBox.Create(Self);
  GBTrigger.Parent := Self;
  GBTrigger.Left := 10; GBTrigger.Top := 10;
  GBTrigger.Width := 720; GBTrigger.Height := 96;

  CbTop := MakeCheck(GBTrigger, 15, 22);
  CbBottom := MakeCheck(GBTrigger, 80, 22);
  CbLeft := MakeCheck(GBTrigger, 145, 22);
  CbRight := MakeCheck(GBTrigger, 210, 22);

  LblDwell := MakeLabel(GBTrigger, 15, 57);
  SeDwell := TSpinEdit.Create(Self);
  SeDwell.Parent := GBTrigger;
  SeDwell.Left := 130; SeDwell.Top := 53; SeDwell.Width := 80;
  SeDwell.MinValue := 0; SeDwell.MaxValue := 5000;

  LblZone := MakeLabel(GBTrigger, 240, 57);
  SeZone := TSpinEdit.Create(Self);
  SeZone.Parent := GBTrigger;
  SeZone.Left := 350; SeZone.Top := 53; SeZone.Width := 70;
  SeZone.MinValue := 2; SeZone.MaxValue := 200;

  CbAutoRun := MakeCheck(GBTrigger, 450, 55);

  // ---- 菜单项 ----
  GBMenu := TGroupBox.Create(Self);
  GBMenu.Parent := Self;
  GBMenu.Left := 10; GBMenu.Top := 116;
  GBMenu.Width := 720; GBMenu.Height := 390;

  Tree := TTreeView.Create(Self);
  Tree.Parent := GBMenu;
  Tree.Left := 10; Tree.Top := 18; Tree.Width := 250; Tree.Height := 360;
  Tree.OnSelectionChanged := @TreeSelectionChanged;
  Tree.ReadOnly := True;

  BtnAdd := MakeBtn(GBMenu, '', 270, 18, 105, @DoAdd);
  BtnAddChild := MakeBtn(GBMenu, '', 270, 48, 105, @DoAddChild);
  BtnAddSep := MakeBtn(GBMenu, '', 270, 78, 105, @DoAddSep);
  BtnDelete := MakeBtn(GBMenu, '', 270, 108, 105, @DoDelete);
  BtnUp := MakeBtn(GBMenu, '', 270, 138, 105, @DoUp);
  BtnDown := MakeBtn(GBMenu, '', 270, 168, 105, @DoDown);

  // 详情区
  LblName := MakeLabel(GBMenu, 385, 22);
  EdName := TEdit.Create(Self);
  EdName.Parent := GBMenu;
  EdName.Left := 445; EdName.Top := 18; EdName.Width := 240;
  EdName.OnChange := @NameChanged;

  LblType := MakeLabel(GBMenu, 385, 52);
  CmbType := TComboBox.Create(Self);
  CmbType.Parent := GBMenu;
  CmbType.Left := 445; CmbType.Top := 48; CmbType.Width := 120;
  CmbType.Style := csDropDownList;
  CmbType.OnChange := @TypeChanged;

  LblTarget := MakeLabel(GBMenu, 385, 82);
  EdTarget := TEdit.Create(Self);
  EdTarget.Parent := GBMenu;
  EdTarget.Left := 445; EdTarget.Top := 78; EdTarget.Width := 175;
  EdTarget.OnChange := @TargetChanged;
  BtnBrowseTarget := MakeBtn(GBMenu, '', 628, 76, 64, @BrowseTarget);

  LblParams := MakeLabel(GBMenu, 385, 112);
  EdParams := TEdit.Create(Self);
  EdParams.Parent := GBMenu;
  EdParams.Left := 445; EdParams.Top := 108; EdParams.Width := 240;
  EdParams.OnChange := @ParamsChanged;

  LblWorkDir := MakeLabel(GBMenu, 385, 142);
  EdWorkDir := TEdit.Create(Self);
  EdWorkDir.Parent := GBMenu;
  EdWorkDir.Left := 445; EdWorkDir.Top := 138; EdWorkDir.Width := 175;
  EdWorkDir.OnChange := @WorkDirChanged;
  BtnBrowseDir := MakeBtn(GBMenu, '', 628, 136, 64, @BrowseDir);

  CbAdmin := TCheckBox.Create(Self);
  CbAdmin.Parent := GBMenu;
  CbAdmin.Left := 445; CbAdmin.Top := 170;
  CbAdmin.OnChange := @AdminChanged;

  // ---- 语言 ----
  LblLang := MakeLabel(Self, 15, 524);
  CmbLang := TComboBox.Create(Self);
  CmbLang.Parent := Self;
  CmbLang.Left := 75; CmbLang.Top := 520; CmbLang.Width := 120;
  CmbLang.Style := csDropDownList;
  // 语言名固定显示原生名称，不随语言切换；"跟随系统"文案在 ApplyCaptions 中按当前语言刷新
  CmbLang.Items.Add('跟随系统');
  CmbLang.Items.Add('中文');
  CmbLang.Items.Add('English');
  CmbLang.OnChange := @LangChanged;

  // ---- 底部按钮 ----
  BtnSave := MakeBtn(Self, '', 545, 520, 85, @DoSave);
  BtnCancel := MakeBtn(Self, '', 640, 520, 85, @DoCancel);
end;

procedure TSettingsForm.ApplyCaptions;
var
  Idx, X: Integer;

  function W(const S: string): Integer;
  begin
    Self.Canvas.Font := Self.Font;
    Result := Self.Canvas.TextWidth(S);
  end;

begin
  FLoading := True;
  try
    Caption := L(lkSettingsCaption);
    GBTrigger.Caption := ' ' + L(lkTrigger) + ' ';
    GBMenu.Caption := ' ' + L(lkMenuItems) + ' ';

    // 第一行：边缘开关。按实测文本宽度横向排列，英文长标签也不会互相重叠
    CbTop.Caption := L(lkTop);
    CbBottom.Caption := L(lkBottom);
    CbLeft.Caption := L(lkLeft);
    CbRight.Caption := L(lkRight);
    X := 15;
    CbTop.Left := X;    Inc(X, W(CbTop.Caption) + 42);
    CbBottom.Left := X; Inc(X, W(CbBottom.Caption) + 42);
    CbLeft.Left := X;   Inc(X, W(CbLeft.Caption) + 42);
    CbRight.Left := X;

    // 第二行：停留 / 热区 / 开机自启
    LblDwell.Caption := L(lkDwellMs);
    LblZone.Caption := L(lkZonePx);
    CbAutoRun.Caption := L(lkAutoRun);
    X := 15;
    LblDwell.Left := X; Inc(X, W(LblDwell.Caption) + 8);
    SeDwell.Left := X;  Inc(X, SeDwell.Width + 28);
    LblZone.Left := X;  Inc(X, W(LblZone.Caption) + 8);
    SeZone.Left := X;   Inc(X, SeZone.Width + 28);
    CbAutoRun.Left := X;

    // 详情区
    LblName.Caption := L(lkName);
    LblType.Caption := L(lkType);
    LblTarget.Caption := L(lkTarget);
    LblParams.Caption := L(lkParams);
    LblWorkDir.Caption := L(lkWorkDir);
    CbAdmin.Caption := L(lkAdmin);

    // 类型下拉（保持当前选中项）
    Idx := CmbType.ItemIndex;
    CmbType.Clear;
    CmbType.Items.Add(L(lkTypeApp));
    CmbType.Items.Add(L(lkTypeUrl));
    CmbType.Items.Add(L(lkTypeDir));
    CmbType.Items.Add(L(lkTypeSep));
    CmbType.ItemIndex := Idx;

    // 按钮
    BtnAdd.Caption := L(lkAdd);
    BtnAddChild.Caption := L(lkAddChild);
    BtnAddSep.Caption := L(lkAddSep);
    BtnDelete.Caption := L(lkDelete);
    BtnUp.Caption := L(lkMoveUp);
    BtnDown.Caption := L(lkMoveDown);
    BtnBrowseTarget.Caption := L(lkBrowse);
    BtnBrowseDir.Caption := L(lkBrowse);
    BtnSave.Caption := L(lkSave);
    BtnCancel.Caption := L(lkCancel);

    // 语言下拉跟随配置（FLoading 保证 OnChange 不会误触发）
    LblLang.Caption := L(lkLanguage);
    CmbLang.Items[0] := L(lkLangSystem);
    if Config.Language = 'en' then
      CmbLang.ItemIndex := 2
    else if Config.Language = 'zh' then
      CmbLang.ItemIndex := 1
    else
      CmbLang.ItemIndex := 0;  // system = 跟随系统
  finally
    FLoading := False;
  end;
end;

procedure TSettingsForm.RebuildTree;

  procedure AddChildren(ParentNode: TTreeNode; List: TMenuItemList);
  var
    I: Integer;
    Node: TTreeNode;
  begin
    for I := 0 to List.Count - 1 do
    begin
      Node := Tree.Items.AddChildObject(ParentNode, List[I].Caption, List[I]);
      AddChildren(Node, List[I].Children);
    end;
  end;

begin
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    AddChildren(nil, Config.Items);
    Tree.FullExpand;
  finally
    Tree.Items.EndUpdate;
  end;
  FCurrent := nil;
  UpdateDetailEnable;
end;

function TSettingsForm.GetParentList(Node: TTreeNode): TMenuItemList;
begin
  if (Node = nil) or (Node.Parent = nil) then
    Result := Config.Items
  else
    Result := TMenuItem(Node.Parent.Data).Children;
end;

function TSettingsForm.FindNodeByData(AData: TObject): TTreeNode;
var
  N: TTreeNode;
begin
  Result := nil;
  N := Tree.Items.GetFirstNode;
  while N <> nil do
  begin
    if TObject(N.Data) = AData then
      Exit(N);
    N := N.GetNext;
  end;
end;

procedure TSettingsForm.InsertAndSelect(List: TMenuItemList; AIdx: Integer;
  Item: TMenuItem);
begin
  List.Insert(AIdx, Item);
  RebuildTree;
  Tree.Selected := FindNodeByData(Item);
end;

procedure TSettingsForm.TreeSelectionChanged(Sender: TObject);
begin
  CommitDetail;
  LoadDetail(Tree.Selected);
end;

procedure TSettingsForm.LangChanged(Sender: TObject);
var
  Code: string;
begin
  if FLoading then Exit;
  case CmbLang.ItemIndex of
    1: Code := 'zh';
    2: Code := 'en';
  else
    Code := 'system';
  end;
  if Code = Config.Language then Exit;
  Config.Language := Code;
  SetLanguage(Code);   // 通知托盘菜单等已显示界面
  ApplyCaptions;       // 本窗体文案重排
end;

procedure TSettingsForm.LoadDetail(Node: TTreeNode);
begin
  FLoading := True;
  try
    if Node = nil then
    begin
      FCurrent := nil;
      UpdateDetailEnable;
      Exit;
    end;
    FCurrent := TMenuItem(Node.Data);
    EdName.Text := FCurrent.Caption;
    case FCurrent.Typ of
      itApp: CmbType.ItemIndex := 0;
      itUrl: CmbType.ItemIndex := 1;
      itDir: CmbType.ItemIndex := 2;
      itSep: CmbType.ItemIndex := 3;
    end;
    EdTarget.Text := FCurrent.Target;
    EdParams.Text := FCurrent.Params;
    EdWorkDir.Text := FCurrent.WorkDir;
    CbAdmin.Checked := FCurrent.Admin;
    UpdateDetailEnable;
  finally
    FLoading := False;
  end;
end;

procedure TSettingsForm.SetDetailControls(AEnabled: Boolean);
begin
  EdName.Enabled := AEnabled;
  CmbType.Enabled := AEnabled;
  EdTarget.Enabled := AEnabled;
  EdParams.Enabled := AEnabled;
  EdWorkDir.Enabled := AEnabled;
  CbAdmin.Enabled := AEnabled;
  BtnBrowseTarget.Enabled := AEnabled;
  BtnBrowseDir.Enabled := AEnabled;
end;

procedure TSettingsForm.UpdateDetailEnable;
var
  IsSep, IsApp: Boolean;
begin
  IsSep := (FCurrent <> nil) and (FCurrent.Typ = itSep);
  IsApp := (FCurrent <> nil) and (FCurrent.Typ = itApp);
  SetDetailControls(FCurrent <> nil);
  EdTarget.Enabled := not IsSep;
  BtnBrowseTarget.Enabled := IsApp or ((FCurrent <> nil) and (FCurrent.Typ = itDir));
  BtnBrowseDir.Enabled := IsApp;
  EdParams.Enabled := IsApp;
  EdWorkDir.Enabled := IsApp;
  CbAdmin.Enabled := IsApp;
end;

procedure TSettingsForm.CommitDetail;
begin
  if FCurrent = nil then Exit;
  FCurrent.Caption := EdName.Text;
  FCurrent.Target := EdTarget.Text;
  FCurrent.Params := EdParams.Text;
  FCurrent.WorkDir := EdWorkDir.Text;
  FCurrent.Admin := CbAdmin.Checked;
  // 树节点文字同步
  if (Tree.Selected <> nil) and (TObject(Tree.Selected.Data) = TObject(FCurrent)) then
    Tree.Selected.Text := FCurrent.Caption;
end;

procedure TSettingsForm.DoAdd(Sender: TObject);
var
  Item: TMenuItem;
  List: TMenuItemList;
  Idx: Integer;
begin
  CommitDetail;
  if Tree.Selected = nil then
  begin
    List := Config.Items;
    Idx := List.Count;
  end
  else
  begin
    // 插入到当前选中项的后面（同级）
    List := GetParentList(Tree.Selected);
    Idx := List.IndexOf(TObject(Tree.Selected.Data)) + 1;
  end;
  Item := TMenuItem.Create;
  Item.Caption := L(lkNewItem);
  Item.Typ := itApp;
  InsertAndSelect(List, Idx, Item);
end;

procedure TSettingsForm.DoAddChild(Sender: TObject);
var
  Item: TMenuItem;
  AParent: TMenuItem;
begin
  if Tree.Selected = nil then
  begin
    DoAdd(nil);
    Exit;
  end;
  CommitDetail;
  AParent := TMenuItem(Tree.Selected.Data);
  Item := TMenuItem.Create;
  Item.Caption := L(lkNewChild);
  Item.Typ := itApp;
  // 子项加在当前项的 Children 末尾
  InsertAndSelect(AParent.Children, AParent.Children.Count, Item);
end;

procedure TSettingsForm.DoAddSep(Sender: TObject);
var
  Item: TMenuItem;
  List: TMenuItemList;
  Idx: Integer;
begin
  if Tree.Selected = nil then
  begin
    List := Config.Items;
    Idx := List.Count;
  end
  else
  begin
    // 插入到当前选中项的后面（同级）
    List := GetParentList(Tree.Selected);
    Idx := List.IndexOf(TObject(Tree.Selected.Data)) + 1;
  end;
  Item := TMenuItem.Create;
  Item.Typ := itSep;
  InsertAndSelect(List, Idx, Item);
end;

procedure TSettingsForm.DoDelete(Sender: TObject);
var
  List: TMenuItemList;
begin
  if Tree.Selected = nil then Exit;
  List := GetParentList(Tree.Selected);
  // 先断开详情引用：List.Delete 会释放对象，随后 RebuildTree 清空树会触发
  // SelectionChanged → CommitDetail，若 FCurrent 还指向已释放内存就会崩溃
  FCurrent := nil;
  List.Delete(List.IndexOf(TObject(Tree.Selected.Data)));
  RebuildTree;
end;

procedure TSettingsForm.DoUp(Sender: TObject);
begin
  DoMove(-1);
end;

procedure TSettingsForm.DoDown(Sender: TObject);
begin
  DoMove(1);
end;

procedure TSettingsForm.DoMove(Delta: Integer);
var
  Node: TTreeNode;
  List: TMenuItemList;
  Idx, Target: Integer;
  MovedObj: TObject;
begin
  Node := Tree.Selected;
  if Node = nil then Exit;
  List := GetParentList(Node);
  Idx := List.IndexOf(TObject(Node.Data));
  Target := Idx + Delta;
  if (Target < 0) or (Target >= List.Count) then Exit;
  MovedObj := TObject(Node.Data);
  List.Move(Idx, Target);
  RebuildTree;
  Tree.Selected := FindNodeByData(MovedObj);
  if Tree.Selected <> nil then
    LoadDetail(Tree.Selected);
end;

procedure TSettingsForm.NameChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  FCurrent.Caption := EdName.Text;
  if Tree.Selected <> nil then
    Tree.Selected.Text := FCurrent.Caption;
end;

procedure TSettingsForm.TypeChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  case CmbType.ItemIndex of
    0: FCurrent.Typ := itApp;
    1: FCurrent.Typ := itUrl;
    2: FCurrent.Typ := itDir;
    3: FCurrent.Typ := itSep;
  end;
  UpdateDetailEnable;
end;

procedure TSettingsForm.TargetChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  FCurrent.Target := EdTarget.Text;
end;

procedure TSettingsForm.ParamsChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  FCurrent.Params := EdParams.Text;
end;

procedure TSettingsForm.WorkDirChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  FCurrent.WorkDir := EdWorkDir.Text;
end;

procedure TSettingsForm.AdminChanged(Sender: TObject);
begin
  if FLoading or (FCurrent = nil) then Exit;
  FCurrent.Admin := CbAdmin.Checked;
end;

procedure TSettingsForm.BrowseTarget(Sender: TObject);
begin
  // 目录类型：目标选文件夹；软件类型：选可执行文件
  if (FCurrent <> nil) and (FCurrent.Typ = itDir) then
  begin
    if DlgDir.Execute then
      EdTarget.Text := DlgDir.FileName;
  end
  else
  begin
    DlgOpen.Filter := L(lkProgFilter);
    if DlgOpen.Execute then
      EdTarget.Text := DlgOpen.FileName;
  end;
end;

procedure TSettingsForm.BrowseDir(Sender: TObject);
begin
  if DlgDir.Execute then
    EdWorkDir.Text := DlgDir.FileName;
end;

procedure TSettingsForm.DoSave(Sender: TObject);
begin
  CommitDetail;
  Config.Edges := [];
  if CbTop.Checked then Include(Config.Edges, edTop);
  if CbBottom.Checked then Include(Config.Edges, edBottom);
  if CbLeft.Checked then Include(Config.Edges, edLeft);
  if CbRight.Checked then Include(Config.Edges, edRight);
  Config.DwellMs := SeDwell.Value;
  Config.EdgeZonePx := SeZone.Value;

  with TRegistry.Create do
  try
    RootKey := HKEY_CURRENT_USER;
    if OpenKey('Software\Microsoft\Windows\CurrentVersion\Run', True) then
    begin
      if CbAutoRun.Checked then
        WriteString('octopus-launch', '"' + ParamStr(0) + '"')
      else if ValueExists('octopus-launch') then
        DeleteValue('octopus-launch');
    end;
  finally
    Free;
  end;

  Config.SaveToFile(ConfigFilePath);
  RefreshMonitors;
  Close;
end;

procedure TSettingsForm.DoCancel(Sender: TObject);
begin
  // 丢弃内存中的修改，重新从磁盘加载
  // LoadFromFile 会释放全部旧对象，先断开详情引用防 UAF；
  // LoadFromFile 内部会按磁盘上的 language 调 SetLanguage（含托盘通知），
  // 本窗体文案需手动重排，语言下拉也会在 ApplyCaptions 中同步回配置值
  FCurrent := nil;
  Config.LoadFromFile(ConfigFilePath);
  RebuildTree;
  ApplyCaptions;
  Close;
end;

end.
