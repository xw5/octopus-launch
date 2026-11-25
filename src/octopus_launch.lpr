program octopus_launch;

{$mode objfpc}{$H+}
{$APPTYPE GUI}
{$R octopus.res}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Windows, SysUtils, ActiveX,
  uConfig, uHooks, uMenuWin, uLauncher, uIcons, uMain, uSettings;

var
  Mutex: THandle;
begin
  // 单实例
  Mutex := CreateMutexW(nil, True, 'octopus-launch-mutex');
  if (Mutex = 0) or (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    if Mutex <> 0 then
      CloseHandle(Mutex);
    Halt(0);
  end;

  RequireDerivedFormResource := False;
  Application.Scaled := False;
  Application.Title := 'octopus-launch';
  Application.Initialize;
  Application.ShowMainForm := False;
  // ShellExecute 打开 URL 等协议处理器依赖 COM，必须初始化
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;

  CloseHandle(Mutex);
end.
