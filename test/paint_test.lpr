{$APPTYPE CONSOLE}
program paint_test;
{ 离屏复现：用真实 DrawItems 渲染配置菜单到位图，检测橙黄伪影 }
uses
  Interfaces, Forms, Windows, SysUtils, Classes, Graphics, LCLType,
  uConfig, uMenuWin, uLauncher, uHooks, uIcons, uWinEx;

procedure Analyze(const AFile: string);
var
  Im: TBitmap;
begin
  // 交给外部分析，这里只保存
end;

var
  F: TMenuForm;
  Bmp: TBitmap;
  I: Integer;
begin
  Application.Initialize;

  Config.LoadFromFile('C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\config.json');
  Writeln('config items=', Config.Items.Count);
  for I := 0 to Config.Items.Count - 1 do
    Writeln('  [', Config.Items[I].Typ, '] children=', Config.Items[I].Children.Count);

  F := TMenuForm.CreateNew(nil);
  F.Items := Config.Items;
  F.Layout;
  Writeln('menu size: ', F.Width, 'x', F.Height);

  // 正常渲染
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(F.Width, F.Height);
    Bmp.PixelFormat := pf24bit;
    F.DrawItems(Bmp.Canvas);
    Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\out_root.bmp');
    Writeln('saved out_root.bmp');

    // 悬停第 2 项（Doc，itDir 类型）
    F.HoverIndex := 1;
    F.DrawItems(Bmp.Canvas);
    Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\out_hover.bmp');
    Writeln('saved out_hover.bmp');
  finally
    Bmp.Free;
  end;
  Writeln('done');
end.
