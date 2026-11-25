unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Windows, Messages, SysUtils, Classes, Forms, Controls, Menus, ExtCtrls,
  LMessages, uConfig, uHooks, uMenuWin, uSettings;

type
  { TMainForm - 隐藏主窗体：托盘 + 钩子调度 }
  TMainForm = class(TForm)
  private
    FTray: TTrayIcon;
    FTrayMenu: TPopupMenu;
    FDwellTimer: TTimer;
    procedure HandleEdgeTrigger(AEdge: TEdge; AMonitor: TRect; const APos: TPoint);
    procedure HandleDwellTimer(Sender: TObject);
    procedure HandleTraySettings(Sender: TObject);
    procedure HandleTrayExit(Sender: TObject);
    procedure HandleDblClick(Sender: TObject);
    procedure WMDisplayChange(var Msg: TLMessage); message WM_DISPLAYCHANGE;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    procedure OpenSettings;
  end;

var
  MainForm: TMainForm;

implementation

uses
  uLauncher, uIcons;

constructor TMainForm.CreateNew(AOwner: TComponent; Num: Integer);
var
  MiSettings, MiSep, MiExit: Menus.TMenuItem;
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'octopus-launch';
  Visible := False;

  // 配置
  Config.LoadFromFile(ConfigFilePath);

  // 托盘（用 LoadImage 直接取 HICON，绕开 LCL TIcon 的 ICO 解析器）
  // 注意：资源名必须是 APPICON 而不是 MAINICON——LCL TApplication.Initialize
  // 会自动用自身有 bug 的解析器加载 MAINICON 导致启动弹错
  FTray := TTrayIcon.Create(Self);
  FTray.Icon.Handle := HICON(LoadImageW(HInstance, 'APPICON', IMAGE_ICON,
    GetSystemMetrics(SM_CXICON), GetSystemMetrics(SM_CYICON), LR_DEFAULTCOLOR));
  FTray.Hint := 'octopus-launch';
  FTray.Visible := True;

  FTrayMenu := TPopupMenu.Create(Self);
  MiSettings := Menus.TMenuItem.Create(FTrayMenu);
  MiSettings.Caption := '设置...';
  MiSettings.OnClick := @HandleTraySettings;
  FTrayMenu.Items.Add(MiSettings);

  MiSep := Menus.TMenuItem.Create(FTrayMenu);
  MiSep.Caption := '-';
  FTrayMenu.Items.Add(MiSep);

  MiExit := Menus.TMenuItem.Create(FTrayMenu);
  MiExit.Caption := '退出';
  MiExit.OnClick := @HandleTrayExit;
  FTrayMenu.Items.Add(MiExit);

  FTray.PopUpMenu := FTrayMenu;
  FTray.OnDblClick := @HandleDblClick;

  // 钩子与驻留检测
  OnEdgeTrigger := @HandleEdgeTrigger;
  StartHooks;
  FDwellTimer := TTimer.Create(Self);
  FDwellTimer.Interval := 30;
  FDwellTimer.OnTimer := @HandleDwellTimer;
  FDwellTimer.Enabled := True;
end;

procedure TMainForm.WMDisplayChange(var Msg: TLMessage);
begin
  RefreshMonitors;
end;

procedure TMainForm.HandleDwellTimer(Sender: TObject);
begin
  CheckDwell;
end;

procedure TMainForm.HandleEdgeTrigger(AEdge: TEdge; AMonitor: TRect; const APos: TPoint);
begin
  TMenuForm.PopupAtEdge(AEdge, AMonitor, APos);
end;

procedure TMainForm.HandleDblClick(Sender: TObject);
begin
  OpenSettings;
end;

procedure TMainForm.HandleTraySettings(Sender: TObject);
begin
  OpenSettings;
end;

procedure TMainForm.HandleTrayExit(Sender: TObject);
begin
  TMenuForm.CloseAllMenus;
  StopHooks;
  FTray.Visible := False;
  FreeIconCache;
  Application.Terminate;
end;

procedure TMainForm.OpenSettings;
begin
  ShowSettingsForm;
end;

end.
