{$APPTYPE CONSOLE}
program seq_test;
{ 复刻 DrawItems 完整序列：三轮迭代 + 真实字体 + 箭头 }
uses
  Interfaces, Forms, Windows, SysUtils, Classes, Graphics, LCLType,
  uIcons, uConfig, uMenuWin, uLauncher, uHooks, uWinEx;

var
  Bmp: TBitmap;
  C: TCanvas;
  IR, R: TRect;
  I: Integer;
  Item: TMenuItem;
  IconH: HICON;
  F: TMenuForm;

const
  COLOR_BG    = $26201C;
  COLOR_HOVER = $4A3634;
  COLOR_TEXT  = $F0E4E4;
  ITEM_H = 40; ICON_SIZE = 20; PAD = 6;

begin
  Application.Initialize;

  Config.LoadFromFile('C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\config.json');

  // 用真实 TMenuForm 的 Font（Segoe UI 11）
  F := TMenuForm.CreateNew(nil);
  F.Items := Config.Items;
  F.Layout;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(F.Width, F.Height);
    Bmp.PixelFormat := pf24bit;
    C := Bmp.Canvas;
    C.Brush.Color := COLOR_BG; C.Brush.Style := bsSolid;
    C.FillRect(Rect(0, 0, Bmp.Width, Bmp.Height));
    C.Font := F.Font;

    for I := 0 to Config.Items.Count - 1 do
    begin
      Item := Config.Items[I];
      R := Rect(PAD, I * ITEM_H + PAD, F.Width - PAD, (I + 1) * ITEM_H + PAD);

      C.Font.Color := COLOR_TEXT;

      IR := Rect(R.Left + 8, R.Top + (ITEM_H - ICON_SIZE) div 2,
        R.Left + 8 + ICON_SIZE, R.Top + (ITEM_H + ICON_SIZE) div 2);
      case Item.Typ of
        itApp:
          begin
            IconH := uIcons.GetAppIcon(Item.Target);
            if IconH <> 0 then
              DrawIconEx(C.Handle, IR.Left, IR.Top, IconH,
                ICON_SIZE, ICON_SIZE, 0, HBRUSH(0), DI_NORMAL);
          end;
        itUrl: DrawBuiltInIcon(C.Handle, bkUrl, IR);
        itDir: DrawBuiltInIcon(C.Handle, bkDir, IR);
      end;

      C.Brush.Style := bsSolid;   // 强制 LCL 标记画刷变更
      C.Brush.Style := bsClear;   // 恢复透明，LCL 会重新设置 DC
      C.TextOut(R.Left + 14 + ICON_SIZE, R.Top + (ITEM_H - C.TextHeight('Hg')) div 2,
        Item.Caption);

      if Item.Children.Count > 0 then
      begin
        C.Font.Size := F.Font.Size + 3;
        C.Brush.Style := bsSolid;
        C.Brush.Style := bsClear;
        C.TextOut(R.Right - 18, R.Top + (ITEM_H - C.TextHeight('>')) div 2, '>');
        C.Font.Size := F.Font.Size;
      end;
      Writeln('iter ', I, ' type=', Ord(Item.Typ), ' caption-bytes=', Length(Item.Caption));
    end;
    Bmp.SaveToFile('D:\code\ahk_pro\octopus-launch\test\seq_v14.bmp');
  finally
    Bmp.Free;
  end;
  Writeln('done');
end.
