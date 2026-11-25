unit uLauncher;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Windows, uConfig, uLang;

// 执行一个菜单项：url 打默认浏览器、dir 打 explorer、app 带参数/工作目录/提权启动
procedure LaunchItem(AItem: TMenuItem);

implementation

uses
  ShellApi;

// 注意：FPC objfpc 模式下 string=AnsiString(UTF-8)，直接 PWideChar(s) 强转
// 会把字节流重解释成 UTF-16 变乱码（ShellExecute 返回 2/FILE_NOT_FOUND）。
// 必须经 UnicodeString 显式转码。
procedure ShellOpen(const AVerb, AFile, AParams, AWorkDir: string);
var
  Verb: PWideChar;
  UVerb: UnicodeString;
begin
  if AVerb = '' then
    Verb := nil
  else
  begin
    UVerb := UnicodeString(AVerb);
    Verb := PWideChar(UVerb);
  end;
  ShellExecuteW(0, Verb,
    PWideChar(UnicodeString(AFile)),
    PWideChar(UnicodeString(AParams)),
    PWideChar(UnicodeString(AWorkDir)),
    SW_SHOWNORMAL);
end;

procedure LaunchItem(AItem: TMenuItem);
var
  Target, WorkDir: string;
  Ret: Integer;
begin
  case AItem.Typ of
    itUrl:
      begin
        Target := Trim(AItem.Target);
        if Target = '' then Exit;
        if (Pos('://', Target) = 0) and (Pos('mailto:', LowerCase(Target)) <> 1) then
          Target := 'https://' + Target;
        Ret := ShellExecuteW(0, 'open', PWideChar(UnicodeString(Target)),
          nil, nil, SW_SHOWNORMAL);
        DebugLog(Format('LaunchItem url ret=%d target=%s', [Ret, Target]));
        if Ret <= 32 then
        begin
          // 兜底：交给 cmd start 调默认浏览器
          Ret := ShellExecuteW(0, 'open', 'cmd.exe',
            PWideChar(UnicodeString('/c start "" "' + Target + '"')),
            nil, SW_HIDE);
          DebugLog(Format('LaunchItem url fallback ret=%d', [Ret]));
        end;
      end;
    itDir:
      begin
        Target := Trim(AItem.Target);
        if not DirectoryExists(Target) then
        begin
          MessageBoxW(0, PWideChar(WideString(L(lkDirNotExist) + Target)),
            'octopus-launch', MB_ICONWARNING);
          Exit;
        end;
        ShellOpen('open', 'explorer.exe', '"' + Target + '"', '');
      end;
    itApp:
      begin
        Target := Trim(AItem.Target);
        if not FileExists(Target) then
        begin
          MessageBoxW(0, PWideChar(WideString(L(lkAppNotExist) + Target)),
            'octopus-launch', MB_ICONWARNING);
          Exit;
        end;
        WorkDir := Trim(AItem.WorkDir);
        if WorkDir = '' then
          WorkDir := ExtractFilePath(Target);
        if AItem.Admin then
          ShellOpen('runas', Target, AItem.Params, WorkDir)
        else
          ShellOpen('open', Target, AItem.Params, WorkDir);
      end;
  end;
end;

end.
