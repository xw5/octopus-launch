{$APPTYPE CONSOLE}
program micro_test;
{ 微测试：二分定位 TextOut 黄底来源 }
uses
  Interfaces, Forms, Windows, SysUtils, Classes, Graphics, LCLType,
  uIcons;

procedure Save(const AFile: string);
var
  Im: TBitmap;
begin
  // placeholder
end;

var
  Bmp: TBitmap;
  C: TCanvas;
  IR: TRect;

begin
  Application.Initialize;

  // A: 纯 bsClear + TextOut
  Bmp := TBitmap.Create;
  Bmp.SetSize(60, 30);
  Bmp.PixelFormat := pf24bit;
  C := Bmp.Canvas;
  C.Brush.Color := $26201C; C.Brush.Style := bsSolid;
  C.FillRect(Rect(0,0,60,30));
  C.Font.Size := 11; C.Font.Color := $F0E4E4;
  C.Brush.Style := bsClear;
  C.TextOut(10, 8, 'Doc');
  Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\microA.bmp');
  Bmp.Free;

  // B: DrawFolder 后 bsClear + TextOut
  Bmp := TBitmap.Create;
  Bmp.SetSize(120, 30);
  Bmp.PixelFormat := pf24bit;
  C := Bmp.Canvas;
  C.Brush.Color := $26201C; C.Brush.Style := bsSolid;
  C.FillRect(Rect(0,0,120,30));
  IR := Rect(5, 5, 25, 25);
  DrawBuiltInIcon(C.Handle, bkDir, IR);
  C.Font.Size := 11; C.Font.Color := $F0E4E4;
  C.Brush.Style := bsClear;
  C.TextOut(40, 8, 'Doc');
  Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\microB.bmp');
  Bmp.Free;

  // C: DrawGlobe 后 bsClear + TextOut
  Bmp := TBitmap.Create;
  Bmp.SetSize(120, 30);
  Bmp.PixelFormat := pf24bit;
  C := Bmp.Canvas;
  C.Brush.Color := $26201C; C.Brush.Style := bsSolid;
  C.FillRect(Rect(0,0,120,30));
  IR := Rect(5, 5, 25, 25);
  DrawBuiltInIcon(C.Handle, bkUrl, IR);
  C.Font.Size := 11; C.Font.Color := $F0E4E4;
  C.Brush.Style := bsClear;
  C.TextOut(40, 8, 'Doc');
  Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\microC.bmp');
  Bmp.Free;

  // D: DrawFolder 后 bsClear，改 Font.Size 再 TextOut（模拟箭头）
  Bmp := TBitmap.Create;
  Bmp.SetSize(120, 30);
  Bmp.PixelFormat := pf24bit;
  C := Bmp.Canvas;
  C.Brush.Color := $26201C; C.Brush.Style := bsSolid;
  C.FillRect(Rect(0,0,120,30));
  IR := Rect(5, 5, 25, 25);
  DrawBuiltInIcon(C.Handle, bkDir, IR);
  C.Font.Size := 11; C.Font.Color := $F0E4E4;
  C.Brush.Style := bsClear;
  C.TextOut(40, 8, 'Doc');
  C.Font.Size := 14;
  C.TextOut(100, 8, '>');
  Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\microD.bmp');
  Bmp.Free;

  Writeln('done');
end.
