{$APPTYPE CONSOLE}
program menuio_test;
{ 验证菜单导入/导出往返：导出→清空→导入，及完整配置对象格式兼容 }
uses
  SysUtils, Classes, uConfig, uLang;

procedure Dump(List: TMenuItemList; Depth: Integer);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
  begin
    Writeln(StringOfChar(' ', Depth * 2), List[I].Caption, ' [', ItemTypeToStr(List[I].Typ), ']');
    Dump(List[I].Children, Depth + 1);
  end;
end;

var
  F, ConfigFile: string;
begin
  ConfigFile := 'C:\Users\Administrator\AppData\Local\octopus-launch\octopus-launch\config.json';
  F := ExtractFilePath(ParamStr(0)) + 'menu_roundtrip.json';

  Config.LoadFromFile(ConfigFile);
  Writeln('--- original menu ---');
  Dump(Config.Items, 0);

  // 1) 导出 → 清空 → 导入（纯数组格式）
  SaveMenuToJSON(F, Config.Items);
  Config.Items.Clear;
  LoadMenuFromJSON(F, Config.Items);
  Writeln('--- after roundtrip (array format) ---');
  Dump(Config.Items, 0);

  // 2) 从完整配置对象导入（含 menu 字段）
  Config.Items.Clear;
  LoadMenuFromJSON(ConfigFile, Config.Items);
  Writeln('--- import from full config object ---');
  Dump(Config.Items, 0);

  // 3) 非法 JSON 应抛异常
  with TStringList.Create do
  try
    Text := '{ not valid json';
    SaveToFile(F);
  finally
    Free;
  end;
  try
    Config.Items.Clear;
    LoadMenuFromJSON(F, Config.Items);
    Writeln('ERROR: invalid json did not raise');
  except
    on E: Exception do
      Writeln('invalid json raised as expected: ', E.ClassName);
  end;
  Writeln('done');
end.
