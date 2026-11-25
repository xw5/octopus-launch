unit uWinEx;

{$mode objfpc}{$H+}

interface

uses
  Windows;

const
  WH_MOUSE_LL = 14;
  MONITOR_DEFAULTTONULL = 0;
  MONITOR_DEFAULTTONEAREST = 2;
  MONITOR_DEFAULTTOPRIMARY = 1;

type
  PMouseLLHookStruct = ^TMouseLLHookStruct;
  TMouseLLHookStruct = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    extraInfo: ULONG_PTR;
  end;

  TMonitorEnumProc = function(hMonitor: THandle; hdc: HDC;
    lprcMonitor: PRect; dwData: LPARAM): BOOL; stdcall;

  PMonitorInfoW = ^TMonitorInfoW;
  TMonitorInfoW = record
    cbSize: DWORD;
    rcMonitor: TRect;
    rcWork: TRect;
    dwFlags: DWORD;
  end;

function GetMonitorInfoW(hMonitor: THandle; lpmi: PMonitorInfoW): BOOL; stdcall;
function EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: TMonitorEnumProc; dwData: LPARAM): BOOL; stdcall;
function MonitorFromRect(lprc: PRect; dwFlags: DWORD): THandle; stdcall;
function GetTickCount64: QWORD; stdcall;

implementation

function GetMonitorInfoW(hMonitor: THandle; lpmi: PMonitorInfoW): BOOL; stdcall;
  external user32 name 'GetMonitorInfoW';
function EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: TMonitorEnumProc; dwData: LPARAM): BOOL; stdcall;
  external user32 name 'EnumDisplayMonitors';
function MonitorFromRect(lprc: PRect; dwFlags: DWORD): THandle; stdcall;
  external user32 name 'MonitorFromRect';
function GetTickCount64: QWORD; stdcall;
  external kernel32 name 'GetTickCount64';

end.
