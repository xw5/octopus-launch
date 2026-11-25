unit uHooks;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Math, uConfig, uWinEx;

type
  TEdgeTriggerEvent = procedure(AEdge: TEdge; AMonitor: TRect; const APos: TPoint) of object;

var
  // 主窗体设置；触发时调用（已在主线程内）
  OnEdgeTrigger: TEdgeTriggerEvent;

procedure StartHooks;
procedure StopHooks;
procedure RefreshMonitors;
procedure CheckDwell;         // 由主窗体定时器周期调用
procedure NotifyMenuClosed;   // 菜单窗口关闭时回调

implementation

uses
  uMenuWin;

type
  TMonitorInfoRec = record
    Bounds: TRect;
    Work: TRect;
  end;

const
  HOT_EXIT_MIN = 20;  // 迟滞区最小宽度 px：只有超出此范围才重置计时/冷却，防微抖动归零

// 迟滞区宽度：保证始终大于热区本身
function ExitZoneWidth: Integer;
begin
  Result := Max(HOT_EXIT_MIN, Config.EdgeZonePx + 10);
end;

var
  FHook: HHOOK = 0;
  FMonitors: array of TMonitorInfoRec;
  FState: (hsIdle, hsInZone, hsMenuOpen, hsCooldown) = hsIdle;
  FZoneEdge: TEdge = edTop;
  FZoneMonitor: Integer = -1;
  FEnterTick: QWORD = 0;
  FLastPos: TPoint;
  FLastHookEventTick: QWORD = 0;  // 钩子最近一次收到事件的时间

// ---- 显示器枚举 ----

function MonitorEnumProc(HMon: THandle; HDC: HDC; ARect: PRect; LParam: LPARAM): BOOL; stdcall;
var
  MI: TMonitorInfoW;
  Idx: Integer;
begin
  Result := True;
  FillChar(MI, SizeOf(MI), 0);
  MI.cbSize := SizeOf(MI);
  if GetMonitorInfoW(HMon, @MI) then
  begin
    Idx := Length(FMonitors);
    SetLength(FMonitors, Idx + 1);
    FMonitors[Idx].Bounds := MI.rcMonitor;
    FMonitors[Idx].Work := MI.rcWork;
  end;
end;

procedure RefreshMonitors;
begin
  SetLength(FMonitors, 0);
  EnumDisplayMonitors(0, nil, @MonitorEnumProc, 0);
end;

// ---- 边缘是否为"外边缘"（相邻有其它显示器则不算） ----

function RectsHorizontallyOverlap(const A, B: TRect): Boolean;
begin
  Result := (A.Right > B.Left + 1) and (A.Left < B.Right - 1);
end;

function RectsVerticallyOverlap(const A, B: TRect): Boolean;
begin
  Result := (A.Bottom > B.Top + 1) and (A.Top < B.Bottom - 1);
end;

function EdgeIsOuter(MIdx: Integer; AEdge: TEdge): Boolean;
var
  I: Integer;
  M, O: TMonitorInfoRec;
begin
  Result := True;
  M := FMonitors[MIdx];
  for I := 0 to Length(FMonitors) - 1 do
  begin
    if I = MIdx then Continue;
    O := FMonitors[I];
    case AEdge of
      edTop:
        if (Abs(O.Bounds.Bottom - M.Bounds.Top) <= 2)
          and RectsHorizontallyOverlap(M.Bounds, O.Bounds) then
          Exit(False);
      edBottom:
        if (Abs(O.Bounds.Top - M.Bounds.Bottom) <= 2)
          and RectsHorizontallyOverlap(M.Bounds, O.Bounds) then
          Exit(False);
      edLeft:
        if (Abs(O.Bounds.Right - M.Bounds.Left) <= 2)
          and RectsVerticallyOverlap(M.Bounds, O.Bounds) then
          Exit(False);
      edRight:
        if (Abs(O.Bounds.Left - M.Bounds.Right) <= 2)
          and RectsVerticallyOverlap(M.Bounds, O.Bounds) then
          Exit(False);
    end;
  end;
end;

// ---- 热区判定：返回命中的显示器索引；上下边优先于左右边 ----

function PosInZoneWidth(const P: TPoint; Zone: Integer;
  out Edge: TEdge; out MIdx: Integer): Boolean;
var
  I: Integer;
  B: TRect;
begin
  Result := False;
  MIdx := -1;
  // 先查上下边（角落优先级：上下 > 左右）
  for I := 0 to Length(FMonitors) - 1 do
  begin
    B := FMonitors[I].Bounds;
    if (P.X >= B.Left) and (P.X <= B.Right) then
    begin
      if (edTop in Config.Edges) and EdgeIsOuter(I, edTop)
        and (P.Y - B.Top <= Zone) and (P.Y >= B.Top) then
      begin
        Edge := edTop; MIdx := I; Exit(True);
      end;
      if (edBottom in Config.Edges) and EdgeIsOuter(I, edBottom)
        and (B.Bottom - P.Y <= Zone) and (P.Y <= B.Bottom) then
      begin
        Edge := edBottom; MIdx := I; Exit(True);
      end;
    end;
  end;
  // 再查左右边
  for I := 0 to Length(FMonitors) - 1 do
  begin
    B := FMonitors[I].Bounds;
    if (P.Y >= B.Top) and (P.Y <= B.Bottom) then
    begin
      if (edLeft in Config.Edges) and EdgeIsOuter(I, edLeft)
        and (P.X - B.Left <= Zone) and (P.X >= B.Left) then
      begin
        Edge := edLeft; MIdx := I; Exit(True);
      end;
      if (edRight in Config.Edges) and EdgeIsOuter(I, edRight)
        and (B.Right - P.X <= Zone) and (P.X <= B.Right) then
      begin
        Edge := edRight; MIdx := I; Exit(True);
      end;
    end;
  end;
end;

function PosInHotZone(const P: TPoint; out Edge: TEdge; out MIdx: Integer): Boolean;
begin
  Result := PosInZoneWidth(P, Config.EdgeZonePx, Edge, MIdx);
end;

// 迟滞判定：是否仍在热区外沿（迟滞区）内
function PosNearEdge(const P: TPoint; out Edge: TEdge; out MIdx: Integer): Boolean;
begin
  Result := PosInZoneWidth(P, ExitZoneWidth, Edge, MIdx);
end;

// ---- 低级鼠标钩子 ----

function LowLevelMouseProc(ACode: Integer; AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
var
  Info: PMouseLLHookStruct;
  Edge: TEdge;
  MIdx: Integer;
begin
  Result := CallNextHookEx(FHook, ACode, AWParam, ALParam);
  if ACode <> HC_ACTION then Exit;
  if AWParam <> WM_MOUSEMOVE then Exit;

  Info := PMouseLLHookStruct(ALParam);
  if Info = nil then Exit;
  FLastPos := Info^.pt;
  FLastHookEventTick := GetTickCount64;

  // 菜单打开时点击菜单外区域：关闭全部菜单
  case AWParam of
    WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_XBUTTONDOWN:
      TMenuForm.CloseIfClickOutside;
  end;

  if PosInHotZone(Info^.pt, Edge, MIdx) then
  begin
    case FState of
      hsIdle:
        begin
          FState := hsInZone;
          FZoneEdge := Edge;
          FZoneMonitor := MIdx;
          FEnterTick := GetTickCount;
        end;
      hsInZone:
        // 换了热区（理论上可能），重置计时
        if (MIdx <> FZoneMonitor) or (Edge <> FZoneEdge) then
        begin
          FZoneEdge := Edge;
          FZoneMonitor := MIdx;
          FEnterTick := GetTickCount;
        end;
      hsCooldown:
        ; // 等离开迟滞区
    end;
  end
  else
  begin
    // 迟滞：只有移出迟滞区（HOT_EXIT）才重置状态，边缘微抖动不打断计时
    case FState of
      hsInZone, hsCooldown:
        if not PosNearEdge(FLastPos, Edge, MIdx) then
          FState := hsIdle;
    end;
  end;
end;

procedure StartHooks;
begin
  RefreshMonitors;
  // 防止看门狗在启动瞬间误判：光标不在原点，须先同步基准
  GetCursorPos(FLastPos);
  FLastHookEventTick := GetTickCount64;
  if FHook = 0 then
  begin
    FHook := SetWindowsHookExW(WH_MOUSE_LL, @LowLevelMouseProc, HInstance, 0);
    DebugLog(Format('StartHooks: handle=%d', [PtrUInt(FHook)]));
  end;
end;

procedure StopHooks;
begin
  if FHook <> 0 then
  begin
    UnhookWindowsHookEx(FHook);
    FHook := 0;
  end;
end;

procedure CheckDwell;
var
  Edge: TEdge;
  MIdx: Integer;
  P: TPoint;
begin
  // 看门狗：菜单弹出时的同步 UI 操作可能让钩子回调响应超时，
  // Windows 会静默移除低级钩子且无任何通知。光标位置在变而钩子
  // 超过 1 秒没有任何事件上报，就说明钩子已死——重装并复位状态。
  GetCursorPos(P);
  if ((P.X <> FLastPos.X) or (P.Y <> FLastPos.Y))
     and (GetTickCount64 - FLastHookEventTick > 1000) then
  begin
    DebugLog('watchdog: hook dead -> reinstall');
    FLastPos := P;
    FLastHookEventTick := GetTickCount64;
    if FHook <> 0 then
    begin
      UnhookWindowsHookEx(FHook);
      FHook := 0;
    end;
    FHook := SetWindowsHookExW(WH_MOUSE_LL, @LowLevelMouseProc, HInstance, 0);
    if Length(uMenuWin.OpenMenus) = 0 then
      FState := hsIdle;
    FEnterTick := GetTickCount;
  end;

  if FState = hsMenuOpen then
  begin
    // 兜底：菜单窗口已全部消失却没收到 NotifyMenuClosed（异常路径），
    // 解除卡死，否则热区触发会永久失效
    if Length(uMenuWin.OpenMenus) = 0 then
      FState := hsCooldown;
    Exit;
  end;
  if FState <> hsInZone then Exit;
  if (GetTickCount64 - FEnterTick) < DWORD(Config.DwellMs) then Exit;

  // 确认当前仍在热区外沿内（迟滞区；用最后一次钩子坐标即可，静止也成立）
  if not PosNearEdge(FLastPos, Edge, MIdx) or (MIdx <> FZoneMonitor) then
  begin
    FState := hsIdle;
    Exit;
  end;

  FState := hsMenuOpen; // 先占住状态，防止重复触发
  if Assigned(OnEdgeTrigger) then
    OnEdgeTrigger(FZoneEdge, FMonitors[FZoneMonitor].Bounds, FLastPos);
end;

procedure NotifyMenuClosed;
begin
  if FState = hsMenuOpen then
    FState := hsCooldown;
end;

end.
