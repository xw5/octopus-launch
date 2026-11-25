using System;
using System.Runtime.InteropServices;
public class Sim {
  [StructLayout(LayoutKind.Sequential)]
  public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)]
  public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
  public const uint MOUSEEVENTF_MOVE = 0x0001;
  public const uint MOUSEEVENTF_ABSOLUTE = 0x8000;
  public const int INPUT_MOUSE = 0;
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);

  // move in steps so the LL hook sees a natural path
  public static void MoveTo(int tx, int ty, int steps) {
    int w = GetSystemMetrics(0), h = GetSystemMetrics(1);
    for (int i = 1; i <= steps; i++) {
      double t = (double)i / steps;
      int cx = (int)(tx * t);  // start approx from 0,0-ish; good enough for edge test
      int cy = (int)(ty * t);
      var inp = new INPUT[1];
      inp[0].type = INPUT_MOUSE;
      inp[0].mi.dx = (cx * 65535) / (w - 1);
      inp[0].mi.dy = (cy * 65535) / (h - 1);
      inp[0].mi.dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE;
      SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
      System.Threading.Thread.Sleep(15);
    }
  }
}
