using System;
using System.Runtime.InteropServices;
public class Sim {
  [StructLayout(LayoutKind.Sequential)]
  public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)]
  public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
  public const uint MOUSEEVENTF_MOVE = 0x0001;
  public const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP = 0x0004;
  public const int INPUT_MOUSE = 0;
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);

  static void MoveAbs(int x, int y) {
    // normalize over the whole VIRTUAL desktop (multi-monitor correct)
    int vx = GetSystemMetrics(76), vy = GetSystemMetrics(77);
    int vw = GetSystemMetrics(78), vh = GetSystemMetrics(79);
    var inp = new INPUT[1];
    inp[0].type = INPUT_MOUSE;
    inp[0].mi.dx = ((vx + x) * 65535) / (vw - 1);
    inp[0].mi.dy = ((vy + y) * 65535) / (vh - 1);
    inp[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
    SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
  }
  // jump directly to the edge point (single event), park, so dwell triggers at that exact spot
  public static void TriggerEdge(int x, int y, int dwellMs) {
    MoveAbs(x, y);
    System.Threading.Thread.Sleep(dwellMs);
  }
  public static void Click(int x, int y) {
    MoveAbs(x, y);
    System.Threading.Thread.Sleep(80);
    var down = new INPUT[1]; down[0].type = INPUT_MOUSE; down[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    var up = new INPUT[1]; up[0].type = INPUT_MOUSE; up[0].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(1, down, Marshal.SizeOf(typeof(INPUT)));
    System.Threading.Thread.Sleep(60);
    SendInput(1, up, Marshal.SizeOf(typeof(INPUT)));
  }
  public static void Park(int x, int y) { MoveAbs(x, y); }

  // move in steps so the LL hook sees a natural event stream
  public static void MoveTo(int tx, int ty, int steps) {
    int w = GetSystemMetrics(0), h = GetSystemMetrics(1);
    for (int i = 1; i <= steps; i++) {
      double t = (double)i / steps;
      int cx = (int)(tx * t);
      int cy = (int)(ty * t);
      MoveAbs(cx, cy);
      System.Threading.Thread.Sleep(15);
    }
  }
}
