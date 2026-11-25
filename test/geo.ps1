Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Geo {
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out P p);
  public struct P { public int X, Y; }
  public static string Dump() {
    var p = new P(); GetCursorPos(out p);
    return string.Format("SM_XVIRT={0} SM_YVIRT={1} SM_CXVIRT={2} SM_CYVIRT={3} SM_CX={4} SM_CY={5} cursor=({6},{7})",
      GetSystemMetrics(76), GetSystemMetrics(77), GetSystemMetrics(78), GetSystemMetrics(79),
      GetSystemMetrics(0), GetSystemMetrics(1), p.X, p.Y);
  }
}
'@
[Geo]::Dump()
