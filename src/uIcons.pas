unit uIcons;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Windows, Classes, Generics.Collections, Graphics;

type
  TBuiltInKind = (bkUrl, bkDir);

  TIconCache = specialize TDictionary<string, HICON>;
  TIconPair = specialize TPair<string, HICON>;

// 取软件 exe 图标句柄（带缓存），调用方仅绘制、不销毁句柄
function GetAppIcon(const APath: string): HICON;
// 直接在 DC 上绘制内置图标（网址/目录）
procedure DrawBuiltInIcon(DC: HDC; Kind: TBuiltInKind; const R: TRect);
// 程序退出时统一释放缓存图标
procedure FreeIconCache;

implementation

uses
  ShellApi;

var
  IconCache: TIconCache;

function GetAppIcon(const APath: string): HICON;
var
  Key: string;
  Info: TSHFileInfoW;
  Flags: UINT;
begin
  Result := 0;
  if APath = '' then Exit;
  Key := LowerCase(ExpandUNCFileName(APath));
  if IconCache.TryGetValue(Key, Result) and (Result <> 0) then
    Exit;

  Flags := SHGFI_ICON or SHGFI_LARGEICON;
  if SHGetFileInfoW(PWideChar(APath), 0, Info, SizeOf(Info), Flags) <> 0 then
    Result := Info.hIcon
  else
  begin
    // 文件不存在时用文件属性兜底拿通用图标
    Flags := SHGFI_ICON or SHGFI_LARGEICON or SHGFI_USEFILEATTRIBUTES;
    if SHGetFileInfoW(PWideChar(ExtractFileName(APath)), FILE_ATTRIBUTE_NORMAL,
      Info, SizeOf(Info), Flags) <> 0 then
      Result := Info.hIcon;
  end;
  if Result <> 0 then
    IconCache.AddOrSetValue(Key, Result);
end;

procedure DrawGlobe(DC: HDC; const R: TRect);
var
  C: TCanvas;
  cx, cy, rx, ry: Integer;
  SavedDC: HDC;
begin
  // 保存/恢复完整 DC 状态，防止画笔/画刷/背景模式污染调用方画布
  SavedDC := SaveDC(DC);
  C := TCanvas.Create;
  try
    C.Handle := DC;
    cx := (R.Left + R.Right) div 2;
    cy := (R.Top + R.Bottom) div 2;
    rx := (R.Right - R.Left) div 2;
    ry := (R.Bottom - R.Top) div 2;
    C.Pen.Color := RGB(100, 190, 230);
    C.Pen.Width := 2;
    C.Brush.Style := bsClear;
    C.Ellipse(cx - rx, cy - ry, cx + rx, cy + ry);
    C.Ellipse(cx - rx div 3, cy - ry, cx + rx div 3, cy + ry);
    C.MoveTo(R.Left, cy);
    C.LineTo(R.Right, cy);
    C.Handle := 0;
  finally
    C.Free;
    RestoreDC(DC, SavedDC);
  end;
end;

procedure DrawFolder(DC: HDC; const R: TRect);
var
  C: TCanvas;
  W, H, TabW: Integer;
  SavedDC: HDC;
begin
  SavedDC := SaveDC(DC);
  C := TCanvas.Create;
  try
    C.Handle := DC;
    W := R.Right - R.Left;
    H := R.Bottom - R.Top;
    TabW := W div 3;
    C.Brush.Color := RGB(240, 190, 80);
    C.Pen.Color := RGB(200, 150, 50);
    // folder tab
    C.Rectangle(R.Left, R.Top, R.Left + TabW, R.Top + H div 3 + 2);
    // folder body
    C.Rectangle(R.Left, R.Top + H div 3, R.Right, R.Bottom);
    C.Handle := 0;
  finally
    C.Free;
    RestoreDC(DC, SavedDC);
  end;
end;

procedure DrawBuiltInIcon(DC: HDC; Kind: TBuiltInKind; const R: TRect);
begin
  case Kind of
    bkUrl: DrawGlobe(DC, R);
    bkDir: DrawFolder(DC, R);
  end;
end;

procedure FreeIconCache;
var
  Pair: TIconPair;
begin
  for Pair in IconCache do
    if Pair.Value <> 0 then
      DestroyIcon(Pair.Value);
  IconCache.Clear;
end;

initialization
  IconCache := TIconCache.Create;

finalization
  FreeIconCache;
  IconCache.Free;

end.
