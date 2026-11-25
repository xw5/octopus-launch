unit uMenuWin;

{$mode objfpc}{$H+}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Forms, Controls, ExtCtrls,
  LMessages, LCLType, Math, uConfig, uIcons, uLauncher, uHooks, uWinEx, uLang;

type
  { TMenuForm - 自绘暗色菜单窗口，支持递归子菜单 }
  TMenuForm = class(TForm)
  private
    FItems: TMenuItemList;
    FOwnsItems: Boolean;       // 子菜单的 Items 是过滤出来的引用列表，不拥有
    FItemRects: array of TRect;
    FHover: Integer;           // 当前悬停项索引（FItems 下标）
    FScrollTop: Integer;       // 内容滚动偏移
    FContentHeight: Integer;
    FParentMenu: TMenuForm;
    FSub: TMenuForm;
    FSubIndex: Integer;      // 已打开子菜单对应条目索引，-1=无
    FSubTimer: TTimer;
    FSubCloseTimer: TTimer;  // 悬停移开后延时关子菜单（立即关会挡住斜穿移向子菜单的路径）
    FCloseTimer: TTimer;     // 鼠标移出后延时关闭检查
    FMonitor: TRect;
    procedure OnSubTimer(Sender: TObject);
    procedure OnSubCloseCheck(Sender: TObject);
    procedure OnCloseCheck(Sender: TObject);
    procedure HandlePaint(Sender: TObject);
    procedure HandleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure HandleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HandleMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleWMActivate(var Msg: TLMActivate); message WM_ACTIVATE;
    procedure HandleCMMouseLeave(var Msg: TLMessage); message CM_MOUSELEAVE;
    function HitTest(X, Y: Integer): Integer;
    function MonitorWork: TRect;
    procedure OpenSubmenu(AIdx: Integer = -1);
    procedure CloseSubmenu;
    function CursorInItemRow(AIdx: Integer): Boolean;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
    destructor Destroy; override;
    // 绘制全部条目到位图（供 HandlePaint 与离屏测试共用）
    procedure DrawItems(ACanvas: TCanvas);
    // 计算尺寸与条目矩形
    procedure Layout;
    // 弹出主菜单
    class procedure PopupAtEdge(AEdge: TEdge; AMonitor: TRect; const APos: TPoint);
    // 全局鼠标按下时调用：点击在所有菜单外则关闭全部
    class procedure CloseIfClickOutside;
    // 关闭全部（根+所有子）
    class procedure CloseAllMenus;
    // 测试/外部挂钩用
    property Items: TMenuItemList read FItems write FItems;
    property HoverIndex: Integer read FHover write FHover;
    property ParentMenu: TMenuForm read FParentMenu write FParentMenu;
  end;

var
  OpenMenus: array of TMenuForm;   // 当前打开的菜单链（0=根）

implementation

const
  ITEM_H = 40;
  SEP_H = 13;
  PAD = 6;
  ICON_SIZE = 20;
  MIN_W = 230;
  CORNER = 10;
  // 关闭判定容差：覆盖贴边菜单与屏幕边缘的 2px 空隙、父子菜单间 2px 间隙、
  // 圆角裁剪区等"视觉在菜单上但窗口外"的区域，防止误关
  CLOSE_SLOP = 8;

  // COLORREF 格式 $00BBGGRR
  COLOR_BG      = $26201C; // RGB(28,28,38)
  COLOR_HOVER   = $4A3634; // RGB(52,54,74)
  COLOR_TEXT    = $F0E4E4; // RGB(228,228,240)
  COLOR_SEP     = $5C4846; // RGB(70,72,92)
  COLOR_ACCENT  = $C8DC40; // RGB(64,220,200)

procedure RegisterMenu(F: TMenuForm);
begin
  SetLength(OpenMenus, Length(OpenMenus) + 1);
  OpenMenus[Length(OpenMenus) - 1] := F;
end;

procedure UnregisterMenu(F: TMenuForm);
var
  I, J: Integer;
begin
  for I := 0 to Length(OpenMenus) - 1 do
    if OpenMenus[I] = F then
    begin
      for J := I to Length(OpenMenus) - 2 do
        OpenMenus[J] := OpenMenus[J + 1];
      SetLength(OpenMenus, Length(OpenMenus) - 1);
      Exit;
    end;
end;

{ TMenuForm }
constructor TMenuForm.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  FOwnsItems := False;
  FHover := -1;
  FSubIndex := -1;
  FScrollTop := 0;
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Position := poDesigned;
  Color := COLOR_BG;
  DoubleBuffered := True;
  Font.Name := 'Segoe UI';
  Font.Size := 11;

  OnPaint := @HandlePaint;
  OnMouseMove := @HandleMouseMove;
  OnMouseUp := @HandleMouseUp;
  OnMouseWheel := @HandleMouseWheel;
  OnKeyDown := @HandleKeyDown;
  KeyPreview := True;

  FSubTimer := TTimer.Create(Self);
  FSubTimer.Interval := 220;
  FSubTimer.Enabled := False;
  FSubTimer.OnTimer := @OnSubTimer;

  FSubCloseTimer := TTimer.Create(Self);
  FSubCloseTimer.Interval := 300;
  FSubCloseTimer.Enabled := False;
  FSubCloseTimer.OnTimer := @OnSubCloseCheck;

  FCloseTimer := TTimer.Create(Self);
  FCloseTimer.Interval := 350;
  FCloseTimer.Enabled := False;
  FCloseTimer.OnTimer := @OnCloseCheck;
end;

destructor TMenuForm.Destroy;
begin
  UnregisterMenu(Self);
  SetLength(FItemRects, 0);
  if FOwnsItems then
    FItems.Free;
  inherited Destroy;
end;

procedure TMenuForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style and not (WS_CAPTION or WS_SIZEBOX);
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
  // 阴影
  Params.WindowClass.Style := Params.WindowClass.Style or CS_DROPSHADOW;
end;

procedure TMenuForm.HandleCMMouseLeave(var Msg: TLMessage);
begin
  // 子菜单开着时光标多半是横移进了子菜单（子菜单盖住父窗口右缘），
  // 父条目高亮保持不清除；子菜单关了或没有子菜单才恢复正常清除
  if (FHover >= 0) and (FSub = nil) then
  begin
    FHover := -1;
    Invalidate;
  end;
  // 鼠标离开本菜单窗口：延时检查，若未进入任一菜单窗口则全部关闭
  // （延时是为了给"父菜单移入子菜单"留时间；进入子菜单后由检查取消关闭）
  if Length(OpenMenus) > 0 then
  begin
    DebugLog('CM_MOUSELEAVE: arm close check');
    FCloseTimer.Enabled := False;
    FCloseTimer.Enabled := True;
  end;
end;

procedure TMenuForm.OnCloseCheck(Sender: TObject);
var
  I: Integer;
  P: TPoint;
  R: TRect;
begin
  if Length(OpenMenus) = 0 then
  begin
    FCloseTimer.Enabled := False;
    Exit;
  end;
  GetCursorPos(P);
  for I := 0 to Length(OpenMenus) - 1 do
    if OpenMenus[I].HandleAllocated and
       GetWindowRect(OpenMenus[I].Handle, R) then
    begin
      // 外扩 CLOSE_SLOP 后再判定：贴边空隙/菜单间隙/圆角不算移出
      R := Rect(R.Left - CLOSE_SLOP, R.Top - CLOSE_SLOP,
        R.Right + CLOSE_SLOP, R.Bottom + CLOSE_SLOP);
      if PtInRect(R, P) then
        Exit; // 光标仍在菜单附近：保持定时器继续轮询，等真正移出再关。
              // 不能一次性退出——否则之后光标移远时定时器已被消费、
              // 又没有新的 CM_MOUSELEAVE 再武装，菜单会永远滞留
    end;
  DebugLog(Format('CloseCheck: cursor=(%d,%d) menus=%d -> close all', [P.X, P.Y, Length(OpenMenus)]));
  FCloseTimer.Enabled := False;
  CloseAllMenus;
end;

// 菜单失去激活（用户点去了别的应用/Alt-Tab）时立即关闭。
// 否则菜单会滞留在其它窗口后面变成不可见的"僵尸窗口"，
// 占着 hsMenuOpen 状态导致后续触发永远无响应
procedure TMenuForm.HandleWMActivate(var Msg: TLMActivate);
var
  I: Integer;
  Related: HWND;
begin
  inherited;
  if (Msg.Active <> WA_INACTIVE) or (Length(OpenMenus) = 0) then Exit;
  Related := Msg.ActiveWindow;
  for I := 0 to Length(OpenMenus) - 1 do
    if OpenMenus[I].HandleAllocated and (OpenMenus[I].Handle = Related) then
      Exit; // 激活转移到了菜单链内的窗口（如子菜单），不关闭
  DebugLog(Format('Deactivate: related=%x -> close all', [PtrUInt(Related)]));
  CloseAllMenus;
end;

procedure TMenuForm.Layout;
var
  I, W, H, TW, MaxW: Integer;
  Y: Integer;
  Item: TMenuItem;
begin
  MaxW := MIN_W;
  Canvas.Font := Font;
  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    if Item.Typ <> itSep then
    begin
      TW := Canvas.TextWidth(Item.Caption);
      if TW + 56 + 24 > MaxW then
        MaxW := TW + 56 + 24; // 图标区+文字+箭头+边距
    end;
  end;
  Width := Max(MaxW, MIN_W);

  SetLength(FItemRects, FItems.Count);
  Y := PAD;
  for I := 0 to FItems.Count - 1 do
  begin
    if FItems[I].Typ = itSep then
      H := SEP_H
    else
      H := ITEM_H;
    FItemRects[I] := Rect(PAD, Y, Width - PAD, Y + H);
    Inc(Y, H);
  end;
  FContentHeight := Y + PAD;

  H := FContentHeight;
  if H > MonitorWork.Bottom - MonitorWork.Top - 40 then
    H := MonitorWork.Bottom - MonitorWork.Top - 40;
  Height := H;

  // 圆角区域
  SetWindowRgn(Handle, CreateRoundRectRgn(0, 0, Width + 1, Height + 1, CORNER, CORNER), True);
end;

function TMenuForm.MonitorWork: TRect;
var
  MI: TMonitorInfoW;
begin
  FillChar(MI, SizeOf(MI), 0);
  MI.cbSize := SizeOf(MI);
  if (FMonitor.Left <> 0) or (FMonitor.Right <> 0) or
     (FMonitor.Top <> 0) or (FMonitor.Bottom <> 0) then
    if GetMonitorInfoW(MonitorFromRect(@FMonitor, MONITOR_DEFAULTTONEAREST), @MI) then
      Exit(MI.rcWork);
  // 兜底：主屏工作区
  SystemParametersInfoW(SPI_GETWORKAREA, 0, @Result, 0);
end;

function TMenuForm.HitTest(X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  Inc(Y, FScrollTop);
  // 横向取整行判定：条目矩形只画到 Width-PAD，若严格按矩形判定，
  // 父菜单右缘的空白带会被当成"移出条目"而立即关掉子菜单，
  // 导致从父菜单移向子菜单时必须"快速冲过去"。行高内横向都属于该条目。
  for I := 0 to FItems.Count - 1 do
    if (X >= 0) and (X < Width) and
       (Y >= FItemRects[I].Top) and (Y < FItemRects[I].Bottom) then
      Exit(I);
end;

procedure TMenuForm.DrawItems(ACanvas: TCanvas);
var
  I: Integer;
  R, IR: TRect;
  Item: TMenuItem;
  IconH: HICON;
begin
  if (FItems = nil) or (Length(FItemRects) <> FItems.Count) then Exit;
  ACanvas.Brush.Color := COLOR_BG;
  ACanvas.FillRect(Rect(0, 0, Width, Height));
  ACanvas.Font := Font;

  for I := 0 to FItems.Count - 1 do
  begin
    Item := FItems[I];
    R := FItemRects[I];
    OffsetRect(R, 0, -FScrollTop);
    if R.Bottom < 0 then Continue;
    if R.Top > Height then Break;

    if Item.Typ = itSep then
    begin
      ACanvas.Pen.Color := COLOR_SEP;
      ACanvas.MoveTo(R.Left + 6, (R.Top + R.Bottom) div 2);
      ACanvas.LineTo(R.Right - 6, (R.Top + R.Bottom) div 2);
      Continue;
    end;

    if I = FHover then
    begin
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Color := COLOR_HOVER;
      ACanvas.Pen.Style := psClear;
      ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, 6, 6);
      ACanvas.Pen.Style := psSolid;
    end;

    ACanvas.Font.Color := COLOR_TEXT;

    // 图标
    IR := Rect(R.Left + 8, R.Top + (ITEM_H - ICON_SIZE) div 2,
      R.Left + 8 + ICON_SIZE, R.Top + (ITEM_H + ICON_SIZE) div 2);
    case Item.Typ of
      itApp:
        begin
          IconH := GetAppIcon(Item.Target);
          if IconH <> 0 then
            DrawIconEx(ACanvas.Handle, IR.Left, IR.Top, IconH,
              ICON_SIZE, ICON_SIZE, 0, HBRUSH(0), DI_NORMAL);
        end;
      itUrl: DrawBuiltInIcon(ACanvas.Handle, bkUrl, IR);
      itDir: DrawBuiltInIcon(ACanvas.Handle, bkDir, IR);
    end;

    // 图标绘制/字体切换会污染 DC（背景模式变 OPAQUE、残留外部画刷），
    // 且 LCL 对相同 Style 不重设 DC——必须强制切换样式逼 LCL 重新同步
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Style := bsClear;

    // 文字
    ACanvas.TextOut(R.Left + 14 + ICON_SIZE, R.Top + (ITEM_H - ACanvas.TextHeight('Hg')) div 2,
      Item.Caption);

    // 子菜单箭头
    if Item.Children.Count > 0 then
    begin
      ACanvas.Font.Size := Font.Size + 3;
      ACanvas.Brush.Style := bsSolid;
      ACanvas.Brush.Style := bsClear;
      ACanvas.TextOut(R.Right - 18, R.Top + (ITEM_H - ACanvas.TextHeight('>')) div 2, '›');
      ACanvas.Font.Size := Font.Size;
    end;
  end;
end;

procedure TMenuForm.HandlePaint(Sender: TObject);
var
  Bmp: TBitmap;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(ClientWidth, ClientHeight);
    DrawItems(Bmp.Canvas);
    Canvas.Draw(0, 0, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TMenuForm.HandleMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewHover: Integer;
begin
  FCloseTimer.Enabled := False; // 鼠标回来了，取消移出关闭
  NewHover := HitTest(X, Y);
  if NewHover = FHover then
  begin
    // 仍在原条目上（含移入子菜单期间）：取消子菜单延时关闭
    if FSub <> nil then
      FSubCloseTimer.Enabled := False;
    Exit;
  end;

  FHover := NewHover;
  if (FHover < 0) or (FItems[FHover].Typ = itSep) or (FItems[FHover].Children.Count = 0) then
  begin
    // 移出条目/移到无子项条目上：不立即关子菜单。斜着移向子菜单、
    // 或在条目间快速滑动时中途落点可能没有子项，立即关会挡住移动路径；
    // 延时 300ms 再关，期间进入子菜单窗口会取消关闭
    if FSub <> nil then
    begin
      FSubTimer.Enabled := False;
      FSubCloseTimer.Enabled := False;
      FSubCloseTimer.Enabled := True;
    end
    else
      FSubTimer.Enabled := False;
  end
  else if (FSub <> nil) and (FSubIndex = FHover) then
  begin
    // 回到子菜单所属条目（折返或路过）：子菜单保持，取消延时关闭
    FSubCloseTimer.Enabled := False;
  end
  else if FSub <> nil then
  begin
    // 已有子菜单但属于别的条目：先关，再对当前条目延时打开它自己的子菜单
    FSubCloseTimer.Enabled := False;
    FSubTimer.Enabled := False;
    CloseSubmenu;
    FSubTimer.Tag := FHover;
    FSubTimer.Enabled := True;
  end
  else
  begin
    // 悬停到有子项的条目：延时打开子菜单
    FSubTimer.Tag := FHover;
    FSubTimer.Enabled := True;
  end;
  Invalidate;
end;

procedure TMenuForm.OnSubTimer(Sender: TObject);
begin
  FSubTimer.Enabled := False;
  // 常规路径：悬停仍在该条目上，打开子菜单。
  // 补救路径：快速掠过该条目已移出本窗口（CM_MOUSELEAVE 已把 FHover 置 -1），
  // 若光标仍在该条目所在的行高度带内（正冲向子菜单），照常打开
  if (FHover >= 0) and (FHover = FSubTimer.Tag)
    and (FItems[FHover].Children.Count > 0) then
    OpenSubmenu(FHover)
  else if (FSub = nil) and (Length(OpenMenus) > 0) then
  begin
    if CursorInItemRow(FSubTimer.Tag) then
      OpenSubmenu(FSubTimer.Tag)
  end;
end;

// 光标当前是否悬停在本菜单第 AIdx 条目对应的屏幕行带内（含横向整行）
function TMenuForm.CursorInItemRow(AIdx: Integer): Boolean;
var
  P: TPoint;
begin
  Result := False;
  if (AIdx < 0) or (AIdx >= FItems.Count) then Exit;
  GetCursorPos(P);
  // 内容坐标 → 屏幕坐标（考虑窗口位置与滚动偏移）
  Result := (P.X >= Self.Left) and (P.X < Self.Left + Width) and
            (P.Y >= Self.Top + FItemRects[AIdx].Top - FScrollTop) and
            (P.Y < Self.Top + FItemRects[AIdx].Bottom - FScrollTop);
end;

procedure TMenuForm.OnSubCloseCheck(Sender: TObject);
var
  P: TPoint;
begin
  FSubCloseTimer.Enabled := False;
  if FSub = nil then Exit;
  GetCursorPos(P);
  // 光标已在子菜单窗口内（子菜单会自己接管悬停）→ 取消关闭
  if FSub.HandleAllocated and
     PtInRect(Rect(FSub.Left, FSub.Top, FSub.Left + FSub.Width, FSub.Top + FSub.Height), P) then
    Exit;
  // 光标又回到了子菜单所属条目的行带内（比如轻微移出后折回）→ 取消关闭
  if CursorInItemRow(FSubIndex) then
    Exit;
  DebugLog('SubCloseCheck: closing submenu');
  CloseSubmenu;
  Invalidate;
end;

procedure TMenuForm.HandleMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Idx: Integer;
  Item: TMenuItem;
begin
  if Button <> mbLeft then Exit;
  Idx := HitTest(X, Y);
  if Idx < 0 then Exit;
  Item := FItems[Idx];
  if Item.Typ = itSep then Exit;

  DebugLog(Format('MouseUp idx=%d caption=%s typ=%s target=%s',
    [Idx, Item.Caption, ItemTypeToStr(Item.Typ), Item.Target]));

  if Item.Children.Count > 0 then
  begin
    FHover := Idx;
    FSubCloseTimer.Enabled := False;
    OpenSubmenu(Idx);
    Invalidate;
    Exit;
  end;

  CloseAllMenus;
  LaunchItem(Item);
end;

procedure TMenuForm.HandleMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var
  MaxScroll: Integer;
begin
  Handled := True;
  MaxScroll := Max(0, FContentHeight - ClientHeight);
  FScrollTop := EnsureRange(FScrollTop - WheelDelta div 2, 0, MaxScroll);
  Invalidate;
end;

procedure TMenuForm.HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    CloseAllMenus;
  end;
end;

procedure TMenuForm.CloseSubmenu;
begin
  FSubIndex := -1;
  if FSub <> nil then
  begin
    DebugLog('CloseSubmenu');
    FSub.CloseSubmenu;
    FSub.Release;
    FSub := nil;
  end;
end;

procedure TMenuForm.OpenSubmenu(AIdx: Integer);
var
  Sub: TMenuForm;
  SR: TRect;
  Work: TRect;
begin
  CloseSubmenu;
  if AIdx < 0 then
    AIdx := FHover;
  if (AIdx < 0) or (AIdx >= FItems.Count) or (FItems[AIdx].Children.Count = 0) then Exit;

  Sub := TMenuForm.CreateNew(nil);
  Sub.FItems := FItems[AIdx].Children;  // 引用，不拥有
  Sub.FParentMenu := Self;
  Sub.FMonitor := FMonitor;
  Self.FSub := Sub;
  Self.FSubIndex := AIdx;
  FHover := AIdx; // 补救路径下 FHover 已被 CM_MOUSELEAVE 置 -1，恢复高亮与后续判定
  // 先注册再显示，保证激活切换时父级 Deactivate 不误关
  RegisterMenu(Sub);
  Sub.Layout;

  Work := Sub.MonitorWork;
  SR := FItemRects[AIdx];
  // 转屏幕坐标（父项矩形是内容坐标，需考虑父级滚动和窗口位置）
  SR.Top := SR.Top - FScrollTop + Self.Top;
  SR.Bottom := SR.Bottom - FScrollTop + Self.Top;
  SR.Left := SR.Left + Self.Left;
  SR.Right := SR.Right + Self.Left;

  Sub.Left := SR.Right + 2;
  Sub.Top := SR.Top;
  if Sub.Left + Sub.Width > Work.Right then
    Sub.Left := SR.Left - Sub.Width - 2;
  Sub.Left := Max(Work.Left, Min(Sub.Left, Work.Right - Sub.Width));
  Sub.Top := Max(Work.Top, Min(Sub.Top, Work.Bottom - Sub.Height));
  Sub.Show;
  DebugLog(Format('submenu open: idx=%d at=(%d,%d) size=%dx%d', [AIdx, Sub.Left, Sub.Top, Sub.Width, Sub.Height]));
  // LCL 实测不会在句柄上保持 WS_EX_TOPMOST，菜单会落到其它窗口后面；
  // 显示后强制置顶
  SetWindowPos(Sub.Handle, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  Sub.Invalidate;
  Sub.SetFocus;
end;

class procedure TMenuForm.CloseIfClickOutside;
var
  I: Integer;
  P: TPoint;
  R: TRect;
begin
  if Length(OpenMenus) = 0 then Exit;
  GetCursorPos(P);
  for I := 0 to Length(OpenMenus) - 1 do
    if OpenMenus[I].HandleAllocated and
       GetWindowRect(OpenMenus[I].Handle, R) then
    begin
      // 与关闭判定同样的容差：贴边空隙/菜单间隙/圆角不算菜单外
      R := Rect(R.Left - CLOSE_SLOP, R.Top - CLOSE_SLOP,
        R.Right + CLOSE_SLOP, R.Bottom + CLOSE_SLOP);
      if PtInRect(R, P) then
        Exit; // 菜单内的点击交给正常 MouseUp 处理
    end;
  DebugLog('Outside mousedown -> close all');
  CloseAllMenus;
end;

class procedure TMenuForm.PopupAtEdge(AEdge: TEdge; AMonitor: TRect; const APos: TPoint);
var
  F: TMenuForm;
  Work: TRect;
  T0, T1: QWORD;
begin
  T0 := GetTickCount64;
  CloseAllMenus;

  if Config.Items.Count = 0 then
  begin
    // UTF-8 字面量必须经 UnicodeString 转码，否则 MessageBoxW 乱码
    MessageBoxW(0, PWideChar(UnicodeString(L(lkEmptyMenu))),
      PWideChar(UnicodeString('octopus-launch')), MB_ICONINFORMATION);
    NotifyMenuClosed;
    Exit;
  end;

  F := TMenuForm.CreateNew(nil);
  F.FItems := Config.Items;
  F.FMonitor := AMonitor;
  RegisterMenu(F);
  F.Layout;

  Work := F.MonitorWork;
  case AEdge of
    edTop:
      begin
        F.Left := APos.X - F.Width div 2;
        F.Top := AMonitor.Top + 2;
      end;
    edBottom:
      begin
        F.Left := APos.X - F.Width div 2;
        F.Top := AMonitor.Bottom - F.Height - 2;
      end;
    edLeft:
      begin
        F.Left := AMonitor.Left + 2;
        F.Top := APos.Y - F.Height div 2;
      end;
    edRight:
      begin
        F.Left := AMonitor.Right - F.Width - 2;
        F.Top := APos.Y - F.Height div 2;
      end;
  end;
  F.Left := Max(Work.Left, Min(F.Left, Work.Right - F.Width));
  F.Top := Max(Work.Top, Min(F.Top, Work.Bottom - F.Height));

  F.Show;
  DebugLog(Format('popup timing: create+layout+show=%dms', [GetTickCount64 - T0]));
  SetWindowPos(F.Handle, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  F.Invalidate;
  T1 := GetTickCount64;
  F.SetFocus;
  DebugLog(Format('popup timing: total=%dms setfocus=%dms',
    [GetTickCount64 - T0, GetTickCount64 - T1]));
end;

class procedure TMenuForm.CloseAllMenus;
var
  Saved: array of TMenuForm;
  I: Integer;
begin
  if Length(OpenMenus) = 0 then Exit;
  DebugLog(Format('CloseAllMenus: count=%d', [Length(OpenMenus)]));
  // 先摘下注册表再释放，防止 Visible=False 触发 Deactivate 造成递归
  Saved := Copy(OpenMenus, 0, Length(OpenMenus));
  SetLength(OpenMenus, 0);
  for I := Length(Saved) - 1 downto 0 do
  begin
    Saved[I].Visible := False;
    Saved[I].Release;
  end;
  NotifyMenuClosed;
end;

end.
