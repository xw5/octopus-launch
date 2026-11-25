using System;
using System.Runtime.InteropServices;
public class HungCheck {
  [DllImport("user32.dll")] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam, uint flags, uint timeout, out IntPtr result);
  public static string Test(IntPtr h) {
    IntPtr res;
    IntPtr ok = SendMessageTimeout(h, 0x0000, IntPtr.Zero, IntPtr.Zero, 0x0008 | 0x0010, 2000, out res);
    return ok == IntPtr.Zero ? "HUNG (no response in 2s)" : "RESPONSIVE";
  }
}
