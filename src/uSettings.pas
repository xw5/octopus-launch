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
    DlgOpen: TOpenDialog;
    DlgDir: TSelectDirectoryDialog;
    procedure BuildUI;
    procedure RebuildTree;
    function GetParentList(Node: TTreeNode): TMenuItemList;
    procedure LoadDetail(Node: TTreeNode);
    procedure CommitDetail;
    procedure UpdateDetailEnable;
    procedure SetDetailControls(AEnabled: Boolean);
    // 事件
    procedure TreeSelectionChanged(Sender: TObject);
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
  Registry, uHooks;

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
  Caption := 'octopus-launch 设置';
  Width := 720;
  Height := 560;
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  Font.Name := 'Microsoft YaHei UI';
  Font.Size := 9;

  DlgOpen := TOpenDialog.Create(Self);
  DlgDir := TSelectDirectoryDialog.Create(Self);
  BuildUI;
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
var
  GB, GBD: TGroupBox;

  function MakeCheck(AParent: TWinControl; const ACaption: string; AX, AY: Integer): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
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

  function MakeLabel(AParent: TWinControl; const ACaption: string;
    AX, AY: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := AParent;
    Result.Caption := ACaption;
    Result.Left := AX;
    Result.Top := AY;
  end;

begin
  // ---- 触发 ----
  GB := TGroupBox.Create(Self);
  GB.Parent := Self;
  GB.Caption := ' 触发 ';
  GB.Left := 10; GB.Top := 10; GB.Width := 690; GB.Height := 90;

  CbTop := MakeCheck(GB, '上边', 15, 22);
  CbBottom := MakeCheck(GB, '下边', 80, 22);
  CbLeft := MakeCheck(GB, '左边', 145, 22);
  CbRight := MakeCheck(GB, '右边', 210, 22);

  MakeLabel(GB, '贴边停留(毫秒):', 15, 55);
  SeDwell := TSpinEdit.Create(Self);
  SeDwell.Parent := GB;
  SeDwell.Left := 130; SeDwell.Top := 51; SeDwell.Width := 80;
  SeDwell.MinValue := 0; SeDwell.MaxValue := 5000;

  MakeLabel(GB, '触发区宽度(px):', 240, 55);
  SeZone := TSpinEdit.Create(Self);
  SeZone.Parent := GB;
  SeZone.Left := 350; SeZone.Top := 51; SeZone.Width := 70;
  SeZone.MinValue := 2; SeZone.MaxValue := 200;

  CbAutoRun := MakeCheck(GB, '开机自启', 450, 55);

  // ---- 菜单项 ----
  GBD := TGroupBox.Create(Self);
  GBD.Parent := Self;
  GBD.Caption := ' 菜单项 ';
  GBD.Left := 10; GBD.Top := 110; GBD.Width := 690; GBD.Height := 390;

  Tree := TTreeView.Create(Self);
  Tree.Parent := GBD;
  Tree.Left := 10; Tree.Top := 18; Tree.Width := 250; Tree.Height := 360;
  Tree.OnSelectionChanged := @TreeSelectionChanged;
  Tree.ReadOnly := True;

  BtnAdd := MakeBtn(GBD, '新增项目', 270, 18, 100, @DoAdd);
  BtnAddChild := MakeBtn(GBD, '新增子项', 270, 48, 100, @DoAddChild);
  BtnAddSep := MakeBtn(GBD, '新增分隔符', 270, 78, 100, @DoAddSep);
  BtnDelete := MakeBtn(GBD, '删除', 270, 108, 100, @DoDelete);
  BtnUp := MakeBtn(GBD, '上移', 270, 138, 100, @DoUp);
  BtnDown := MakeBtn(GBD, '下移', 270, 168, 100, @DoDown);

  // 详情区
  MakeLabel(GBD, '名称:', 380, 22);
  EdName := TEdit.Create(Self);
  EdName.Parent := GBD;
  EdName.Left := 440; EdName.Top := 18; EdName.Width := 235;
  EdName.OnChange := @NameChanged;

  MakeLabel(GBD, '类型:', 380, 52);
  CmbType := TComboBox.Create(Self);
  CmbType.Parent := GBD;
  CmbType.Left := 440; CmbType.Top := 48; CmbType.Width := 120;
  CmbType.Style := csDropDownList;
  CmbType.Items.Add('软件');
  CmbType.Items.Add('网址');
  CmbType.Items.Add('目录');
  CmbType.Items.Add('分隔符');
  CmbType.OnChange := @TypeChanged;

  MakeLabel(GBD, '目标:', 380, 82);
  EdTarget := TEdit.Create(Self);
  EdTarget.Parent := GBD;
  EdTarget.Left := 440; EdTarget.Top := 78; EdTarget.Width := 190;
  EdTarget.OnChange := @TargetChanged;
  BtnBrowseTarget := MakeBtn(GBD, '浏览...', 635, 76, 50, @BrowseTarget);

  MakeLabel(GBD, '参数:', 380, 112);
  EdParams := TEdit.Create(Self);
  EdParams.Parent := GBD;
  EdParams.Left := 440; EdParams.Top := 108; EdParams.Width := 235;
  EdParams.OnChange := @ParamsChanged;

  MakeLabel(GBD, '工作目录:', 380, 142);
  EdWorkDir := TEdit.Create(Self);
  EdWorkDir.Parent := GBD;
  EdWorkDir.Left := 440; EdWorkDir.Top := 138; EdWorkDir.Width := 190;
  EdWorkDir.OnChange := @WorkDirChanged;
  BtnBrowseDir := MakeBtn(GBD, '浏览...', 635, 136, 50, @BrowseDir);

  CbAdmin := TCheckBox.Create(Self);
  CbAdmin.Parent := GBD;
  CbAdmin.Caption := '以管理员身份运行';
  CbAdmin.Left := 440; CbAdmin.Top := 170;
  CbAdmin.OnChange := @AdminChanged;

  // ---- 底部按钮 ----
  BtnSave := MakeBtn(Self, '保存', 520, 510, 85, @DoSave);
  BtnCancel := MakeBtn(Self, '取消', 615, 510, 85, @DoCancel);
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

procedure TSettingsForm.TreeSelectionChanged(Sender: TObject);
begin
  CommitDetail;
  LoadDetail(Tree.Selected);
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
begin
  CommitDetail;
  if Tree.Selected = nil then
    List := Config.Items
  else
    List := GetParentList(Tree.Selected);
  Item := TMenuItem.Create;
  Item.Caption := '新项目';
  Item.Typ := itApp;
  List.Add(Item);
  RebuildTree;
  Tree.Selected := Tree.Items.GetLastNode;
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
  Item.Caption := '新子项';
  Item.Typ := itApp;
  AParent.Children.Add(Item);
  RebuildTree;
  Tree.Selected := Tree.Items.GetLastNode;
end;

procedure TSettingsForm.DoAddSep(Sender: TObject);
var
  Item: TMenuItem;
  List: TMenuItemList;
begin
  if Tree.Selected = nil then
    List := Config.Items
  else
    List := GetParentList(Tree.Selected);
  Item := TMenuItem.Create;
  Item.Typ := itSep;
  List.Add(Item);
  RebuildTree;
  Tree.Selected := Tree.Items.GetLastNode;
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

  function FindNodeByData(AData: TObject): TTreeNode;
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
    DlgOpen.Filter := '程序|*.exe;*.lnk;*.bat;*.cmd|所有文件|*.*';
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
  // LoadFromFile 会释放全部旧对象，先断开详情引用防 UAF
  FCurrent := nil;
  Config.LoadFromFile(ConfigFilePath);
  RebuildTree;
  Close;
end;

end.
