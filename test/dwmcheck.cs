using System;
using System.Runtime.InteropServices;
public class DwmCheck {
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out int val, int size);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
  public static string Info(IntPtr h) {
    int cloaked; DwmGetWindowAttribute(h, 14 /*DWMWA_CLOAKED*/, out cloaked, 4);
    uint pid; GetWindowThreadProcessId(h, out pid);
    return string.Format("cloaked={0} iconic={1} fg={2} style={3:X} exstyle={4:X}",
      cloaked, IsIconic(h), GetForegroundWindow() == h, GetWindowLong(h, -16), GetWindowLong(h, -20));
  }
}
