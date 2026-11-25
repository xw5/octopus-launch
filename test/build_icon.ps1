# Rebuild the octopus icon: draw a 256px master, export multi-size .ico (uncompressed
# BMP frames so the old FPC windres can embed it) plus README PNG.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File test\build_icon.ps1 [-Sizes "16,24,32,48,64,128,256"]
param([string]$Sizes = '16,24,32,48,64,128,256')

Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class IconBuilder
{
    // Draw the 256px design master.
    public static Bitmap DrawMaster(int size)
    {
        var bmp = new Bitmap(size, size);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            float k = size / 256f;

            Color bgC = Color.FromArgb(255, 30, 34, 45);
            Color teal = Color.FromArgb(255, 46, 196, 182);
            Color eye = Color.FromArgb(255, 24, 30, 40);
            using (var bgB = new SolidBrush(bgC))
            using (var tealB = new SolidBrush(teal))
            using (var eyeB = new SolidBrush(eye))
            {
                // Rounded-square background (radius 56) via rect + 4 corner pies
                float m = 56f * k;
                g.FillRectangle(bgB, m, 0, size - m * 2, size);
                g.FillRectangle(bgB, 0, m, size, size - m * 2);
                g.FillPie(bgB, 0, 0, m * 2, m * 2, 180, 90);
                g.FillPie(bgB, size - m * 2, 0, m * 2, m * 2, 270, 90);
                g.FillPie(bgB, size - m * 2, size - m * 2, m * 2, m * 2, 0, 90);
                g.FillPie(bgB, 0, size - m * 2, m * 2, m * 2, 90, 90);

                // Head: big circle centered at (128,116) r=92
                float hx = 128f * k, hy = 116f * k, hr = 92f * k;
                g.FillEllipse(tealB, hx - hr, hy - hr, hr * 2, hr * 2);

                // Three tentacle bumps on the lower-left rim
                float[][] tentacles = new float[][]
                {
                    new float[] { 52f, 172f, 26f },
                    new float[] { 84f, 208f, 24f },
                    new float[] { 122f, 222f, 22f },
                };
                foreach (var t in tentacles)
                {
                    float r = t[2] * k;
                    g.FillEllipse(tealB, t[0] * k - r, t[1] * k - r, r * 2, r * 2);
                }

                // Eyes
                float er = 14f * k;
                g.FillEllipse(eyeB, 96f * k - er, 100f * k - er, er * 2, er * 2);
                g.FillEllipse(eyeB, 156f * k - er, 100f * k - er, er * 2, er * 2);
            }
        }
        return bmp;
    }

    static Bitmap Resize(Bitmap src, int s)
    {
        var small = new Bitmap(s, s);
        using (var g = Graphics.FromImage(small))
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(src, new Rectangle(0, 0, s, s), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel);
        }
        return small;
    }

    static void W32(MemoryStream ms, int v)
    {
        ms.WriteByte((byte)v); ms.WriteByte((byte)(v >> 8));
        ms.WriteByte((byte)(v >> 16)); ms.WriteByte((byte)(v >> 24));
    }
    static void W16(MemoryStream ms, int v)
    {
        ms.WriteByte((byte)v); ms.WriteByte((byte)(v >> 8));
    }

    // One icon frame: BITMAPINFOHEADER + 32bpp bottom-up XOR + empty AND mask
    static byte[] Frame(Bitmap b)
    {
        int s = b.Width;
        int xor = s * s * 4;
        int andStride = ((s + 31) / 32) * 4;
        int and = andStride * s;
        var ms = new MemoryStream(40 + xor + and);

        W32(ms, 40); W32(ms, s); W32(ms, s * 2);
        W16(ms, 1); W16(ms, 32);
        W32(ms, 0); W32(ms, xor + and);
        W32(ms, 0); W32(ms, 0); W32(ms, 0);

        var rect = new Rectangle(0, 0, s, s);
        var data = b.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int stride = data.Stride;
        byte[] buf = new byte[stride * s];
        System.Runtime.InteropServices.Marshal.Copy(data.Scan0, buf, 0, buf.Length);
        b.UnlockBits(data);
        for (int y = s - 1; y >= 0; y--)
            ms.Write(buf, y * stride, s * 4);

        ms.Write(new byte[and], 0, and);
        return ms.ToArray();
    }

    // Multi-size ico, uncompressed BMP frames (compatible with the old FPC windres).
    public static void SaveIco(Bitmap master, string path, int[] sizes)
    {
        using (var fs = File.Create(path))
        using (var bw = new BinaryWriter(fs))
        {
            bw.Write((ushort)0); bw.Write((ushort)1); bw.Write((ushort)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            var frames = new byte[sizes.Length][];
            for (int i = 0; i < sizes.Length; i++)
            {
                int s = sizes[i];
                using (var small = Resize(master, s))
                    frames[i] = Frame(small);
                int w = s >= 256 ? 0 : s;
                bw.Write((byte)w); bw.Write((byte)w);
                bw.Write((byte)0); bw.Write((byte)0);   // color count, reserved
                bw.Write((ushort)1); bw.Write((ushort)32);
                bw.Write((uint)frames[i].Length); bw.Write((uint)offset);
                offset += frames[i].Length;
            }
            foreach (var f in frames) bw.Write(f);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing

$root   = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$srcDir = Join-Path $root 'src'

$master = [IconBuilder]::DrawMaster(256)

$docsDir = Join-Path $root 'docs'
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
$master.Save((Join-Path $docsDir 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)

[IconBuilder]::SaveIco($master, (Join-Path $srcDir 'octopus.ico'), ($Sizes.Split(',') | ForEach-Object { [int]$_.Trim() }))

$master.Dispose()
Write-Host "OK -> docs\logo.png"
Write-Host "OK -> src\octopus.ico"
