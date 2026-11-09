$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $PSScriptRoot
$InstallerDir = $PSScriptRoot
$DistDir = Join-Path $RootDir 'dist'

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

Write-Host "==> [1/5] Generando iconos multi-resolucion (app.ico, favicon.ico, icon-32.png, icon-192.png, icon-512.png)..." -ForegroundColor Cyan
Add-Type -AssemblyName System.Drawing

$logoPath = Join-Path $RootDir 'logo.png'
$icoPath = Join-Path $InstallerDir 'app.ico'
$faviconPath = Join-Path $RootDir 'favicon.ico'
$icon32Path = Join-Path $RootDir 'icon-32.png'
$icon192Path = Join-Path $RootDir 'icon-192.png'
$icon512Path = Join-Path $RootDir 'icon-512.png'

$srcBmp = [System.Drawing.Bitmap]::FromFile($logoPath)

function New-SquareLogoBitmap([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::White)

    $pad = [Math]::Max(2, [int]([Math]::Round($size * 0.08)))
    $availW = $size - ($pad * 2)
    $availH = $size - ($pad * 2)
    $ratio = [Math]::Min($availW / [double]$srcBmp.Width, $availH / [double]$srcBmp.Height)
    $drawW = [Math]::Max(1, [int]([Math]::Round($srcBmp.Width * $ratio)))
    $drawH = [Math]::Max(1, [int]([Math]::Round($srcBmp.Height * $ratio)))
    $drawX = [int](($size - $drawW) / 2)
    $drawY = [int](($size - $drawH) / 2)

    $g.DrawImage($srcBmp, $drawX, $drawY, $drawW, $drawH)
    $g.Dispose()
    return $bmp
}

# Guardar PNGs para web/manifest/app window
$bmp32 = New-SquareLogoBitmap 32
$bmp32.Save($icon32Path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp32.Dispose()

$bmp192 = New-SquareLogoBitmap 192
$bmp192.Save($icon192Path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp192.Dispose()

$bmp512 = New-SquareLogoBitmap 512
$bmp512.Save($icon512Path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp512.Dispose()

# Construir archivo .ICO multi-resolucion (16, 24, 32, 48, 64, 256)
$icoSizes = @(16, 24, 32, 48, 64, 256)
$pngPayloads = @()

foreach ($sz in $icoSizes) {
    $b = New-SquareLogoBitmap $sz
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngPayloads += ,($ms.ToArray())
    $ms.Dispose()
    $b.Dispose()
}

$srcBmp.Dispose()

$fsIco = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fsIco)
$count = $icoSizes.Count

# ICONDIR Header (6 bytes)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$count)

$offset = 6 + (16 * $count)
for ($i = 0; $i -lt $count; $i++) {
    $sz = $icoSizes[$i]
    $bytes = $pngPayloads[$i]
    $dimByte = if ($sz -ge 256) { [byte]0 } else { [byte]$sz }

    $bw.Write($dimByte)                     # Width
    $bw.Write($dimByte)                     # Height
    $bw.Write([byte]0)                      # ColorCount
    $bw.Write([byte]0)                      # Reserved
    $bw.Write([UInt16]1)                    # Planes
    $bw.Write([UInt16]32)                   # BitCount
    $bw.Write([UInt32]$bytes.Length)        # BytesInRes
    $bw.Write([UInt32]$offset)              # ImageOffset
    $offset += $bytes.Length
}

for ($i = 0; $i -lt $count; $i++) {
    $bw.Write($pngPayloads[$i])
}

$bw.Flush()
$bw.Close()
$fsIco.Close()

Copy-Item $icoPath -Destination $faviconPath -Force
Write-Host "    Iconos multi-resolucion generados: app.ico, favicon.ico, icon-32.png, icon-192.png, icon-512.png" -ForegroundColor Green

$cscPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $cscPath)) {
    throw "No se encontro el compilador nativo de .NET en $cscPath"
}

Write-Host "==> [2/5] Empaquetando archivos de la aplicacion en payload_app.zip..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$appPayloadZip = Join-Path $InstallerDir 'payload_app.zip'
if (Test-Path $appPayloadZip) { Remove-Item $appPayloadZip -Force }

$stagingApp = Join-Path $InstallerDir '_staging_app'
if (Test-Path $stagingApp) { Remove-Item $stagingApp -Recurse -Force }
New-Item -ItemType Directory -Path $stagingApp | Out-Null

$filesToBundle = @(
    'index.html',
    'manifest.json',
    'favicon.ico',
    'icon-32.png',
    'icon-192.png',
    'icon-512.png',
    'jsbarcode.min.js',
    'firebase-app-compat.js',
    'firebase-firestore-compat.js',
    'logo.png',
    'README.md',
    'firebase.json',
    'firestore.rules'
)

foreach ($f in $filesToBundle) {
    $srcFile = Join-Path $RootDir $f
    if (Test-Path $srcFile) {
        Copy-Item $srcFile -Destination (Join-Path $stagingApp $f) -Force
    }
}

Copy-Item $icoPath -Destination (Join-Path $stagingApp 'app.ico') -Force

$docsSrc = Join-Path $RootDir 'docs'
if (Test-Path $docsSrc) {
    Copy-Item $docsSrc -Destination (Join-Path $stagingApp 'docs') -Recurse -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($stagingApp, $appPayloadZip)
Remove-Item $stagingApp -Recurse -Force
Write-Host "    Payload de aplicacion listo: $appPayloadZip" -ForegroundColor Green

Write-Host "==> [3/5] Compilando ejecutables PTI-Packing-AGV.exe y Uninstall-PTI-Packing-AGV.exe..." -ForegroundColor Cyan

$launcherCsPath = Join-Path $InstallerDir 'Launcher.cs'
$launcherCs = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: AssemblyTitle("PTI Packing AGV")]
[assembly: AssemblyDescription("Sistema Operativo de Emision y Trazabilidad PTI 4x2 - Agrovision Mexico")]
[assembly: AssemblyCompany("Agrovision Mexico")]
[assembly: AssemblyProduct("PTI Packing AGV")]
[assembly: AssemblyVersion("2.6.0.0")]
[assembly: AssemblyFileVersion("2.6.0.0")]

namespace PtiPackingAgv
{
    static class Win32IconHelper
    {
        private const uint WM_SETICON = 0x0080;
        private const int ICON_SMALL = 0;
        private const int ICON_BIG = 1;
        private const int GCLP_HICON = -14;
        private const int GCLP_HICONSM = -34;

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder strText, int maxCount);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll", EntryPoint = "SetClassLongPtrW")]
        private static extern IntPtr SetClassLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

        [DllImport("user32.dll", EntryPoint = "SetClassLongW")]
        private static extern IntPtr SetClassLong32(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

        [DllImport("shell32.dll", SetLastError = true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        [DllImport("shell32.dll", SetLastError = true)]
        private static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [Out, MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);

        [ComImport]
        [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IPropertyStore
        {
            int GetCount(out uint cProps);
            int GetAt(uint iProp, out PROPERTYKEY pkey);
            int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
            int SetValue(ref PROPERTYKEY key, ref PROPVARIANT pv);
            int Commit();
        }

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        private struct PROPERTYKEY
        {
            public Guid fmtid;
            public uint pid;
            public PROPERTYKEY(Guid guid, uint id)
            {
                fmtid = guid;
                pid = id;
            }
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct PROPVARIANT
        {
            [FieldOffset(0)] public ushort vt;
            [FieldOffset(8)] public IntPtr pszVal;

            public static PROPVARIANT FromString(string val)
            {
                PROPVARIANT pv = new PROPVARIANT();
                pv.vt = 31; // VT_LPWSTR
                pv.pszVal = Marshal.StringToCoTaskMemUni(val);
                return pv;
            }

            public void Clear()
            {
                if (vt == 31 && pszVal != IntPtr.Zero)
                {
                    Marshal.FreeCoTaskMem(pszVal);
                    pszVal = IntPtr.Zero;
                }
            }
        }

        private static IntPtr SetClassLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong)
        {
            if (IntPtr.Size == 8)
                return SetClassLongPtr64(hWnd, nIndex, dwNewLong);
            return SetClassLong32(hWnd, nIndex, dwNewLong);
        }

        public static void ApplyIconToMatchingWindows(Icon smallIcon, Icon bigIcon, string iconFilePath, string exePath)
        {
            if (smallIcon == null || bigIcon == null) return;
            IntPtr hSmall = smallIcon.Handle;
            IntPtr hBig = bigIcon.Handle;

            EnumWindows((hWnd, lParam) =>
            {
                try
                {
                    if (!IsWindowVisible(hWnd)) return true;
                    StringBuilder sb = new StringBuilder(256);
                    if (GetWindowText(hWnd, sb, sb.Capacity) > 0)
                    {
                        string title = sb.ToString();
                        if (title.IndexOf("PTI PACKING AGV", StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            // 1. Establecer icono en el marco superior izquierdo (ICON_SMALL) y en la barra de tareas (ICON_BIG)
                            SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_SMALL, hSmall);
                            SendMessage(hWnd, WM_SETICON, (IntPtr)ICON_BIG, hBig);
                            try
                            {
                                SetClassLongPtr(hWnd, GCLP_HICONSM, hSmall);
                                SetClassLongPtr(hWnd, GCLP_HICON, hBig);
                            }
                            catch { }

                            // 2. Establecer propiedades de barra de tareas de Windows 10/11 (AppUserModel)
                            ApplyWindowTaskbarProperties(hWnd, iconFilePath, exePath);
                        }
                    }
                }
                catch { }
                return true;
            }, IntPtr.Zero);
        }

        private static void ApplyWindowTaskbarProperties(IntPtr hWnd, string iconFilePath, string exePath)
        {
            if (string.IsNullOrEmpty(iconFilePath) || !File.Exists(iconFilePath)) return;
            try
            {
                Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
                IPropertyStore store;
                if (SHGetPropertyStoreForWindow(hWnd, ref iid, out store) == 0 && store != null)
                {
                    Guid appUserModelGuid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
                    PROPERTYKEY pkAppId = new PROPERTYKEY(appUserModelGuid, 5);
                    PROPERTYKEY pkRelaunchCmd = new PROPERTYKEY(appUserModelGuid, 2);
                    PROPERTYKEY pkRelaunchIcon = new PROPERTYKEY(appUserModelGuid, 3);
                    PROPERTYKEY pkRelaunchName = new PROPERTYKEY(appUserModelGuid, 4);

                    PROPVARIANT pvId = PROPVARIANT.FromString("Agrovision.PTIPackingAGV.App");
                    PROPVARIANT pvIcon = PROPVARIANT.FromString(iconFilePath + ",0");
                    PROPVARIANT pvName = PROPVARIANT.FromString("PTI Packing AGV");
                    PROPVARIANT pvCmd = PROPVARIANT.FromString("\"" + exePath + "\"");

                    try
                    {
                        store.SetValue(ref pkAppId, ref pvId);
                        store.SetValue(ref pkRelaunchIcon, ref pvIcon);
                        store.SetValue(ref pkRelaunchName, ref pvName);
                        if (!string.IsNullOrEmpty(exePath))
                            store.SetValue(ref pkRelaunchCmd, ref pvCmd);
                        store.Commit();
                    }
                    finally
                    {
                        pvId.Clear();
                        pvIcon.Clear();
                        pvName.Clear();
                        pvCmd.Clear();
                        Marshal.ReleaseComObject(store);
                    }
                }
            }
            catch { }
        }
    }

    static class Program
    {
        private static TcpListener _listener;
        private static bool _running = true;
        private static string _webRoot;
        private static int _port = 58420;
        private static DateTime _lastActivity = DateTime.UtcNow;
        private static Icon _smallIcon;
        private static Icon _bigIcon;
        private static string _icoFilePath;

        [STAThread]
        static void Main(string[] args)
        {
            try { Win32IconHelper.SetCurrentProcessExplicitAppUserModelID("Agrovision.PTIPackingAGV.App"); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            try
            {
                string exeDir = AppDomain.CurrentDomain.BaseDirectory;
                string localIndex = Path.Combine(exeDir, "index.html");
                string localFavicon = Path.Combine(exeDir, "favicon.ico");

                if (File.Exists(localIndex) && File.Exists(localFavicon))
                {
                    _webRoot = exeDir;
                }
                else
                {
                    string fallbackDir = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "Programs",
                        "PTI-Packing-AGV"
                    );
                    EnsureExtractedPayload(fallbackDir);
                    _webRoot = fallbackDir;
                }

                _icoFilePath = Path.Combine(_webRoot, "app.ico");
                if (!File.Exists(_icoFilePath))
                {
                    _icoFilePath = Path.Combine(_webRoot, "favicon.ico");
                }
                LoadAppIcons(_icoFilePath);

                _port = StartServer(_webRoot);
                string url = "http://127.0.0.1:" + _port + "/index.html";

                Process browserProc = LaunchAppWindow(url);

                // Hilo que aplica el icono de Agrovision al marco superior izquierdo y a la barra de tareas
                Thread iconWatchThread = new Thread(() =>
                {
                    for (int i = 0; i < 40 && _running; i++)
                    {
                        Win32IconHelper.ApplyIconToMatchingWindows(_smallIcon, _bigIcon, _icoFilePath, Application.ExecutablePath);
                        Thread.Sleep(i < 15 ? 250 : 1000);
                    }
                    while (_running)
                    {
                        Win32IconHelper.ApplyIconToMatchingWindows(_smallIcon, _bigIcon, _icoFilePath, Application.ExecutablePath);
                        Thread.Sleep(2500);
                    }
                });
                iconWatchThread.IsBackground = true;
                iconWatchThread.Start();

                if (browserProc != null)
                {
                    try { browserProc.WaitForExit(); } catch { }
                    Thread.Sleep(2500);
                }
                else
                {
                    Thread.Sleep(5000);
                }

                WaitUntilClientCloses();
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Error al iniciar PTI Packing AGV:\n" + ex.Message,
                    "PTI Packing AGV",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
            finally
            {
                _running = false;
                try { if (_listener != null) _listener.Stop(); } catch { }
            }
        }

        private static void LoadAppIcons(string icoPath)
        {
            try
            {
                if (File.Exists(icoPath))
                {
                    _smallIcon = new Icon(icoPath, new Size(16, 16));
                    _bigIcon = new Icon(icoPath, new Size(48, 48));
                    return;
                }
            }
            catch { }

            try
            {
                using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.ico"))
                {
                    if (s != null)
                    {
                        Icon baseIcon = new Icon(s);
                        _smallIcon = new Icon(baseIcon, new Size(16, 16));
                        _bigIcon = new Icon(baseIcon, new Size(48, 48));
                    }
                }
            }
            catch { }
        }

        private static void WaitUntilClientCloses()
        {
            string profileDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PTI-Packing-AGV-Profile-v2"
            );
            string lockFile = Path.Combine(profileDir, "SingletonLock");
            string devToolsPortFile = Path.Combine(profileDir, "DevToolsActivePort");

            int idleChecks = 0;
            while (_running)
            {
                Thread.Sleep(2000);
                bool hasBrowser = IsAppBrowserRunning() || File.Exists(lockFile) || File.Exists(devToolsPortFile);
                double secsSinceReq = (DateTime.UtcNow - _lastActivity).TotalSeconds;
                if (!hasBrowser && secsSinceReq > 8)
                {
                    idleChecks++;
                    if (idleChecks >= 2) break;
                }
                else
                {
                    idleChecks = 0;
                }
            }
        }

        private static bool IsAppBrowserRunning()
        {
            try
            {
                foreach (string procName in new string[] { "msedge", "chrome" })
                {
                    Process[] procs = Process.GetProcessesByName(procName);
                    if (procs != null)
                    {
                        foreach (var p in procs)
                        {
                            try
                            {
                                if (!p.HasExited && p.MainWindowTitle != null &&
                                    p.MainWindowTitle.IndexOf("PTI PACKING AGV", StringComparison.OrdinalIgnoreCase) >= 0)
                                {
                                    return true;
                                }
                            }
                            catch { }
                        }
                    }
                }
            }
            catch { }
            return false;
        }

        private static void EnsureExtractedPayload(string targetDir)
        {
            Directory.CreateDirectory(targetDir);
            using (Stream res = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload_app.zip"))
            {
                if (res == null) return;
                string tmpZip = Path.Combine(Path.GetTempPath(), "pti_agv_" + Guid.NewGuid().ToString("N") + ".zip");
                using (FileStream fs = File.Create(tmpZip))
                {
                    res.CopyTo(fs);
                }
                try
                {
                    using (ZipArchive archive = ZipFile.OpenRead(tmpZip))
                    {
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            string destPath = Path.Combine(targetDir, entry.FullName);
                            string destFolder = Path.GetDirectoryName(destPath);
                            if (!string.IsNullOrEmpty(destFolder))
                                Directory.CreateDirectory(destFolder);
                            if (!string.IsNullOrEmpty(entry.Name))
                                entry.ExtractToFile(destPath, true);
                        }
                    }
                }
                finally
                {
                    try { File.Delete(tmpZip); } catch { }
                }
            }
        }

        private static int StartServer(string rootDir)
        {
            int[] candidatePorts = new int[] { 58420, 58421, 58422, 58423, 0 };
            foreach (int p in candidatePorts)
            {
                try
                {
                    TcpListener l = new TcpListener(IPAddress.Loopback, p);
                    l.Start();
                    _listener = l;
                    int boundPort = ((IPEndPoint)l.LocalEndpoint).Port;
                    Thread serverThread = new Thread(AcceptLoop);
                    serverThread.IsBackground = true;
                    serverThread.Start();
                    return boundPort;
                }
                catch { }
            }
            throw new Exception("No se pudo abrir un puerto local para el servidor PTI.");
        }

        private static void AcceptLoop()
        {
            while (_running)
            {
                try
                {
                    TcpClient client = _listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(HandleClient, client);
                }
                catch
                {
                    if (!_running) break;
                }
            }
        }

        private static void HandleClient(object obj)
        {
            _lastActivity = DateTime.UtcNow;
            using (TcpClient client = (TcpClient)obj)
            using (NetworkStream stream = client.GetStream())
            using (StreamReader reader = new StreamReader(stream, Encoding.UTF8, false, 4096, true))
            {
                try
                {
                    string requestLine = reader.ReadLine();
                    if (string.IsNullOrEmpty(requestLine)) return;

                    int contentLength = 0;
                    string line;
                    while (!string.IsNullOrEmpty(line = reader.ReadLine()))
                    {
                        if (line.StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
                        {
                            int.TryParse(line.Substring(15).Trim(), out contentLength);
                        }
                    }

                    string[] parts = requestLine.Split(' ');
                    if (parts.Length < 2) return;

                    string method = parts[0].ToUpperInvariant();
                    string rawPath = Uri.UnescapeDataString(parts[1]);
                    int qIdx = rawPath.IndexOf('?');
                    if (qIdx >= 0) rawPath = rawPath.Substring(0, qIdx);

                    if (rawPath.Equals("/api/machine-info", StringComparison.OrdinalIgnoreCase))
                    {
                        string json = GetMachineInfoJson();
                        byte[] jsonBytes = Encoding.UTF8.GetBytes(json);
                        WriteHeader(stream, "200 OK", "application/json; charset=utf-8", jsonBytes.Length);
                        stream.Write(jsonBytes, 0, jsonBytes.Length);
                        return;
                    }

                    if (rawPath.Equals("/api/license-state", StringComparison.OrdinalIgnoreCase))
                    {
                        string licFile = Path.Combine(_webRoot, "system_licenses.json");
                        if (method == "POST" && contentLength > 0 && contentLength < 5 * 1024 * 1024)
                        {
                            char[] buf = new char[contentLength];
                            int readTotal = 0;
                            while (readTotal < contentLength)
                            {
                                int r = reader.Read(buf, readTotal, contentLength - readTotal);
                                if (r <= 0) break;
                                readTotal += r;
                            }
                            string bodyJson = new string(buf, 0, readTotal);
                            try { File.WriteAllText(licFile, bodyJson, Encoding.UTF8); } catch { }
                            byte[] okBytes = Encoding.UTF8.GetBytes("{\"ok\":true}");
                            WriteHeader(stream, "200 OK", "application/json; charset=utf-8", okBytes.Length);
                            stream.Write(okBytes, 0, okBytes.Length);
                            return;
                        }
                        else
                        {
                            string savedJson = "{}";
                            try { if (File.Exists(licFile)) savedJson = File.ReadAllText(licFile, Encoding.UTF8); } catch { }
                            byte[] respBytes = Encoding.UTF8.GetBytes(savedJson);
                            WriteHeader(stream, "200 OK", "application/json; charset=utf-8", respBytes.Length);
                            stream.Write(respBytes, 0, respBytes.Length);
                            return;
                        }
                    }

                    if (rawPath == "/" || string.IsNullOrEmpty(rawPath))
                        rawPath = "/index.html";

                    string relPath = rawPath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                    string fullPath = Path.GetFullPath(Path.Combine(_webRoot, relPath));

                    if (!fullPath.StartsWith(Path.GetFullPath(_webRoot), StringComparison.OrdinalIgnoreCase) || !File.Exists(fullPath))
                    {
                        byte[] notFound = Encoding.UTF8.GetBytes("404 Not Found");
                        WriteHeader(stream, "404 Not Found", "text/plain; charset=utf-8", notFound.Length);
                        stream.Write(notFound, 0, notFound.Length);
                        return;
                    }

                    byte[] body = File.ReadAllBytes(fullPath);
                    string mime = GetMimeType(Path.GetExtension(fullPath));
                    WriteHeader(stream, "200 OK", mime, body.Length);
                    stream.Write(body, 0, body.Length);
                }
                catch { }
            }
        }

        private static string GetMachineInfoJson()
        {
            string machineGuid = "";
            try
            {
                using (RegistryKey baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64))
                using (RegistryKey subKey = baseKey.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography"))
                {
                    if (subKey != null)
                    {
                        object val = subKey.GetValue("MachineGuid");
                        if (val != null) machineGuid = val.ToString();
                    }
                }
            }
            catch { }

            if (string.IsNullOrEmpty(machineGuid))
            {
                try
                {
                    using (RegistryKey subKey = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography"))
                    {
                        if (subKey != null)
                        {
                            object val = subKey.GetValue("MachineGuid");
                            if (val != null) machineGuid = val.ToString();
                        }
                    }
                }
                catch { }
            }

            string hostname = Environment.MachineName ?? "PC-PLANTA";
            string osUser = Environment.UserName ?? "Operador";
            string rawSeed = (machineGuid + "|" + hostname).ToUpperInvariant();
            string codePart1 = "0000";
            string codePart2 = "0000";

            try
            {
                using (SHA256 sha = SHA256.Create())
                {
                    byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(rawSeed));
                    string hex = BitConverter.ToString(hash).Replace("-", "").ToUpperInvariant();
                    codePart1 = hex.Substring(0, 4);
                    codePart2 = hex.Substring(4, 4);
                }
            }
            catch { }

            string machineId = "AGV-" + codePart1 + "-" + codePart2;
            string safeHost = hostname.Replace("\\", "\\\\").Replace("\"", "\\\"");
            string safeUser = osUser.Replace("\\", "\\\\").Replace("\"", "\\\"");

            return "{\"machineId\":\"" + machineId + "\",\"hostname\":\"" + safeHost + "\",\"osUser\":\"" + safeUser + "\",\"platform\":\"Windows Desktop (.exe)\",\"version\":\"2.6.0\"}";
        }

        private static void WriteHeader(Stream stream, string status, string contentType, int contentLength)
        {
            string hdr =
                "HTTP/1.1 " + status + "\r\n" +
                "Content-Type: " + contentType + "\r\n" +
                "Content-Length: " + contentLength + "\r\n" +
                "Cache-Control: no-cache\r\n" +
                "Connection: close\r\n\r\n";
            byte[] hdrBytes = Encoding.ASCII.GetBytes(hdr);
            stream.Write(hdrBytes, 0, hdrBytes.Length);
        }

        private static string GetMimeType(string ext)
        {
            switch ((ext ?? "").ToLowerInvariant())
            {
                case ".html":
                case ".htm": return "text/html; charset=utf-8";
                case ".js": return "application/javascript; charset=utf-8";
                case ".css": return "text/css; charset=utf-8";
                case ".json":
                case ".webmanifest": return "application/manifest+json; charset=utf-8";
                case ".png": return "image/png";
                case ".jpg":
                case ".jpeg": return "image/jpeg";
                case ".svg": return "image/svg+xml";
                case ".ico": return "image/x-icon";
                case ".md": return "text/markdown; charset=utf-8";
                default: return "application/octet-stream";
            }
        }

        private static Process LaunchAppWindow(string url)
        {
            string profileDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "PTI-Packing-AGV-Profile-v2"
            );
            Directory.CreateDirectory(profileDir);

            string[] candidateBrowsers = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe")
            };

            foreach (string browserExe in candidateBrowsers)
            {
                if (File.Exists(browserExe))
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = browserExe,
                        Arguments = string.Format("--app=\"{0}\" --user-data-dir=\"{1}\" --window-size=1360,860 --no-first-run --no-default-browser-check", url, profileDir),
                        UseShellExecute = false
                    };
                    return Process.Start(psi);
                }
            }

            return Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
        }
    }
}
'@
Set-Content -Path $launcherCsPath -Value $launcherCs -Encoding UTF8

$launcherExe = Join-Path $DistDir 'PTI-Packing-AGV.exe'
& $cscPath /nologo /target:winexe /optimize+ `
    /out:$launcherExe `
    /win32icon:$icoPath `
    /resource:$appPayloadZip,payload_app.zip `
    /resource:$icoPath,app.ico `
    /r:System.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll `
    $launcherCsPath

if ($LASTEXITCODE -ne 0) { throw "Error compilando PTI-Packing-AGV.exe" }
Write-Host "    Ejecutable principal generado: $launcherExe" -ForegroundColor Green

# Compilar Desinstalador con icono embebido
$uninstallerCsPath = Join-Path $InstallerDir 'Uninstaller.cs'
$uninstallerCs = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Desinstalador PTI Packing AGV")]
[assembly: AssemblyCompany("Agrovision Mexico")]
[assembly: AssemblyProduct("PTI Packing AGV")]
[assembly: AssemblyVersion("2.6.0.0")]

namespace PtiPackingAgvUninstall
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            DialogResult res = MessageBox.Show(
                "¿Desea desinstalar PTI Packing AGV de este equipo?\n\n(Los datos sincronizados en la nube de Agrovision se conservarán intactos).",
                "Desinstalar PTI Packing AGV",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question
            );
            if (res != DialogResult.Yes) return;

            try
            {
                string desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "PTI Packing AGV.lnk");
                if (File.Exists(desktopShortcut)) File.Delete(desktopShortcut);

                string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "PTI Packing AGV");
                if (Directory.Exists(startMenuDir)) Directory.Delete(startMenuDir, true);

                string appDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = "/C timeout /t 2 /nobreak > NUL & rmdir /s /q \"" + appDir + "\"",
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                    UseShellExecute = false
                };
                Process.Start(psi);

                MessageBox.Show(
                    "PTI Packing AGV se ha desinstalado correctamente.",
                    "PTI Packing AGV",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                );
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error durante la desinstalación: " + ex.Message, "PTI Packing AGV", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
    }
}
'@
Set-Content -Path $uninstallerCsPath -Value $uninstallerCs -Encoding UTF8

$uninstallerExe = Join-Path $InstallerDir 'Uninstall-PTI-Packing-AGV.exe'
& $cscPath /nologo /target:winexe /optimize+ `
    /out:$uninstallerExe `
    /win32icon:$icoPath `
    /r:System.dll /r:System.Windows.Forms.dll `
    $uninstallerCsPath

if ($LASTEXITCODE -ne 0) { throw "Error compilando Uninstall-PTI-Packing-AGV.exe" }

Write-Host "==> [4/5] Empaquetando payload completo del instalador (payload_setup.zip)..." -ForegroundColor Cyan
$setupZip = Join-Path $InstallerDir 'payload_setup.zip'
if (Test-Path $setupZip) { Remove-Item $setupZip -Force }

$stagingSetup = Join-Path $InstallerDir '_staging_setup'
if (Test-Path $stagingSetup) { Remove-Item $stagingSetup -Recurse -Force }
New-Item -ItemType Directory -Path $stagingSetup | Out-Null

foreach ($f in $filesToBundle) {
    $srcFile = Join-Path $RootDir $f
    if (Test-Path $srcFile) {
        Copy-Item $srcFile -Destination (Join-Path $stagingSetup $f) -Force
    }
}
Copy-Item $icoPath -Destination (Join-Path $stagingSetup 'app.ico') -Force
Copy-Item $launcherExe -Destination (Join-Path $stagingSetup 'PTI-Packing-AGV.exe') -Force
Copy-Item $uninstallerExe -Destination (Join-Path $stagingSetup 'Uninstall-PTI-Packing-AGV.exe') -Force
if (Test-Path $docsSrc) {
    Copy-Item $docsSrc -Destination (Join-Path $stagingSetup 'docs') -Recurse -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($stagingSetup, $setupZip)
Remove-Item $stagingSetup -Recurse -Force

Write-Host "==> [5/5] Compilando instalador grafico PTI-Packing-AGV-Setup.exe..." -ForegroundColor Cyan

$setupCsPath = Join-Path $InstallerDir 'Setup.cs'
$setupCs = @'
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("Instalador PTI Packing AGV")]
[assembly: AssemblyDescription("Instalador Oficial de PTI Packing AGV - Agrovision Mexico")]
[assembly: AssemblyCompany("Agrovision Mexico")]
[assembly: AssemblyProduct("PTI Packing AGV")]
[assembly: AssemblyVersion("2.6.0.0")]
[assembly: AssemblyFileVersion("2.6.0.0")]

namespace PtiPackingAgvSetup
{
    public class SetupForm : Form
    {
        private TextBox txtInstallDir;
        private CheckBox chkDesktopShortcut;
        private CheckBox chkStartMenuShortcut;
        private CheckBox chkLaunchNow;
        private ProgressBar progressBar;
        private Label lblStatus;
        private Button btnInstall;
        private Button btnCancel;

        public SetupForm()
        {
            Text = "PTI Packing AGV — Instalador Oficial";
            Size = new Size(575, 440);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Color.White;
            Font = new Font("Segoe UI", 9.5F, FontStyle.Regular);

            try
            {
                using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("app.ico"))
                {
                    if (s != null)
                        Icon = new Icon(s);
                    else
                        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
                }
            }
            catch { }

            Panel headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 96,
                BackColor = Color.FromArgb(248, 250, 252)
            };

            PictureBox picLogo = new PictureBox
            {
                Location = new Point(22, 18),
                Size = new Size(64, 60),
                SizeMode = PictureBoxSizeMode.Zoom,
                BackColor = Color.Transparent
            };
            try
            {
                using (Stream sLogo = Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.png"))
                {
                    if (sLogo != null)
                        picLogo.Image = Image.FromStream(sLogo);
                }
            }
            catch { }

            Label lblTitle = new Label
            {
                Text = "PTI Packing AGV",
                Font = new Font("Segoe UI", 16F, FontStyle.Bold),
                ForeColor = Color.FromArgb(15, 23, 42),
                Location = new Point(98, 20),
                AutoSize = true
            };

            Label lblSub = new Label
            {
                Text = "Agrovision México · Emisión y Trazabilidad PTI 4\" × 2\" (GS1-128 / ZPL)",
                Font = new Font("Segoe UI", 9.5F, FontStyle.Regular),
                ForeColor = Color.FromArgb(100, 116, 139),
                Location = new Point(100, 54),
                AutoSize = true
            };

            headerPanel.Controls.Add(picLogo);
            headerPanel.Controls.Add(lblTitle);
            headerPanel.Controls.Add(lblSub);
            Controls.Add(headerPanel);

            Label lblFolder = new Label
            {
                Text = "Carpeta de instalación:",
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                ForeColor = Color.FromArgb(30, 41, 59),
                Location = new Point(26, 114),
                AutoSize = true
            };
            Controls.Add(lblFolder);

            string defaultDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "PTI-Packing-AGV"
            );

            txtInstallDir = new TextBox
            {
                Text = defaultDir,
                Location = new Point(26, 139),
                Size = new Size(405, 26),
                Font = new Font("Consolas", 9.5F)
            };
            Controls.Add(txtInstallDir);

            Button btnBrowse = new Button
            {
                Text = "Examinar...",
                Location = new Point(440, 137),
                Size = new Size(92, 28),
                FlatStyle = FlatStyle.System
            };
            btnBrowse.Click += (s, e) =>
            {
                using (FolderBrowserDialog fbd = new FolderBrowserDialog())
                {
                    fbd.SelectedPath = txtInstallDir.Text;
                    if (fbd.ShowDialog() == DialogResult.OK)
                    {
                        txtInstallDir.Text = Path.Combine(fbd.SelectedPath, "PTI-Packing-AGV");
                    }
                }
            };
            Controls.Add(btnBrowse);

            chkDesktopShortcut = new CheckBox
            {
                Text = "Crear acceso directo en el Escritorio (PTI Packing AGV)",
                Checked = true,
                Location = new Point(28, 184),
                Size = new Size(490, 24),
                ForeColor = Color.FromArgb(15, 23, 42)
            };
            Controls.Add(chkDesktopShortcut);

            chkStartMenuShortcut = new CheckBox
            {
                Text = "Crear carpeta y acceso directo en el Menú Inicio",
                Checked = true,
                Location = new Point(28, 214),
                Size = new Size(490, 24),
                ForeColor = Color.FromArgb(15, 23, 42)
            };
            Controls.Add(chkStartMenuShortcut);

            chkLaunchNow = new CheckBox
            {
                Text = "Iniciar PTI Packing AGV al finalizar la instalación",
                Checked = true,
                Location = new Point(28, 244),
                Size = new Size(490, 24),
                Font = new Font("Segoe UI", 9.5F, FontStyle.Bold),
                ForeColor = Color.FromArgb(21, 128, 61)
            };
            Controls.Add(chkLaunchNow);

            progressBar = new ProgressBar
            {
                Location = new Point(26, 286),
                Size = new Size(506, 20),
                Minimum = 0,
                Maximum = 100,
                Value = 0
            };
            Controls.Add(progressBar);

            lblStatus = new Label
            {
                Text = "Listo para instalar todos los módulos y librerías locales.",
                Location = new Point(26, 312),
                Size = new Size(506, 22),
                ForeColor = Color.FromArgb(71, 85, 105)
            };
            Controls.Add(lblStatus);

            btnInstall = new Button
            {
                Text = "Instalar PTI Packing AGV",
                Location = new Point(322, 346),
                Size = new Size(210, 36),
                BackColor = Color.FromArgb(22, 163, 74),
                ForeColor = Color.White,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 10F, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            btnInstall.FlatAppearance.BorderSize = 0;
            btnInstall.Click += (s, e) => RunInstall();
            Controls.Add(btnInstall);

            btnCancel = new Button
            {
                Text = "Cancelar",
                Location = new Point(216, 346),
                Size = new Size(96, 36),
                FlatStyle = FlatStyle.System
            };
            btnCancel.Click += (s, e) => Close();
            Controls.Add(btnCancel);
        }

        private void RunInstall()
        {
            btnInstall.Enabled = false;
            btnCancel.Enabled = false;
            try
            {
                string targetDir = txtInstallDir.Text.Trim();
                lblStatus.Text = "Extrayendo archivos e iconos del sistema...";
                progressBar.Value = 25;
                Application.DoEvents();

                Program.PerformInstallation(
                    targetDir,
                    chkDesktopShortcut.Checked,
                    chkStartMenuShortcut.Checked
                );

                progressBar.Value = 100;
                lblStatus.Text = "¡Instalación completada exitosamente!";
                Application.DoEvents();

                string exePath = Path.Combine(targetDir, "PTI-Packing-AGV.exe");
                if (chkLaunchNow.Checked && File.Exists(exePath))
                {
                    Process.Start(new ProcessStartInfo
                    {
                        FileName = exePath,
                        WorkingDirectory = targetDir,
                        UseShellExecute = true
                    });
                }
                else
                {
                    MessageBox.Show(
                        "PTI Packing AGV se ha instalado correctamente en:\n" + targetDir,
                        "Instalación Completada",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Information
                    );
                }
                Close();
            }
            catch (Exception ex)
            {
                btnInstall.Enabled = true;
                btnCancel.Enabled = true;
                lblStatus.Text = "Error en la instalación.";
                MessageBox.Show(
                    "No se pudo completar la instalación:\n" + ex.Message,
                    "Error de Instalación",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }

    static class Program
    {
        [DllImport("shell32.dll", SetLastError = true)]
        private static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);

        [STAThread]
        static void Main(string[] args)
        {
            try { SetCurrentProcessExplicitAppUserModelID("Agrovision.PTIPackingAGV.Setup"); } catch { }
            bool silent = false;
            string customDir = null;

            foreach (string a in args)
            {
                if (a.Equals("/S", StringComparison.OrdinalIgnoreCase) ||
                    a.Equals("--silent", StringComparison.OrdinalIgnoreCase) ||
                    a.Equals("/quiet", StringComparison.OrdinalIgnoreCase))
                {
                    silent = true;
                }
                else if (a.StartsWith("/D=", StringComparison.OrdinalIgnoreCase))
                {
                    customDir = a.Substring(3).Trim('"');
                }
            }

            if (silent)
            {
                string targetDir = customDir ?? Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Programs",
                    "PTI-Packing-AGV"
                );
                PerformInstallation(targetDir, true, true);
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new SetupForm());
        }

        public static void PerformInstallation(string targetDir, bool createDesktop, bool createStartMenu)
        {
            try
            {
                Process[] running = Process.GetProcessesByName("PTI-Packing-AGV");
                if (running != null)
                {
                    foreach (Process p in running)
                    {
                        try { p.Kill(); p.WaitForExit(2000); } catch { }
                    }
                }
            }
            catch { }

            Directory.CreateDirectory(targetDir);

            using (Stream res = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload_setup.zip"))
            {
                if (res == null)
                    throw new Exception("No se encontró el paquete embebido payload_setup.zip.");

                string tmpZip = Path.Combine(Path.GetTempPath(), "pti_setup_" + Guid.NewGuid().ToString("N") + ".zip");
                using (FileStream fs = File.Create(tmpZip))
                {
                    res.CopyTo(fs);
                }

                try
                {
                    using (ZipArchive archive = ZipFile.OpenRead(tmpZip))
                    {
                        foreach (ZipArchiveEntry entry in archive.Entries)
                        {
                            try
                            {
                                string destPath = Path.Combine(targetDir, entry.FullName);
                                string destFolder = Path.GetDirectoryName(destPath);
                                if (!string.IsNullOrEmpty(destFolder))
                                    Directory.CreateDirectory(destFolder);
                                if (!string.IsNullOrEmpty(entry.Name))
                                    entry.ExtractToFile(destPath, true);
                            }
                            catch { }
                        }
                    }
                }
                finally
                {
                    try { File.Delete(tmpZip); } catch { }
                }
            }

            string exePath = Path.Combine(targetDir, "PTI-Packing-AGV.exe");
            string icoPath = Path.Combine(targetDir, "app.ico");

            if (createDesktop)
            {
                try
                {
                    string desktopLnk = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                        "PTI Packing AGV.lnk"
                    );
                    CreateShortcut(desktopLnk, exePath, targetDir, icoPath, "PTI Packing AGV — Agrovision México");
                }
                catch { }
            }

            if (createStartMenu)
            {
                try
                {
                    string startMenuFolder = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                        "PTI Packing AGV"
                    );
                    Directory.CreateDirectory(startMenuFolder);
                    string startLnk = Path.Combine(startMenuFolder, "PTI Packing AGV.lnk");
                    CreateShortcut(startLnk, exePath, targetDir, icoPath, "PTI Packing AGV — Agrovision México");

                    string uninstallExe = Path.Combine(targetDir, "Uninstall-PTI-Packing-AGV.exe");
                    if (File.Exists(uninstallExe))
                    {
                        string uninstallLnk = Path.Combine(startMenuFolder, "Desinstalar PTI Packing AGV.lnk");
                        CreateShortcut(uninstallLnk, uninstallExe, targetDir, icoPath, "Desinstalar PTI Packing AGV");
                    }
                }
                catch { }
            }
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDir, string iconPath, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                dynamic shell = Activator.CreateInstance(shellType);
                dynamic shortcut = shell.CreateShortcut(shortcutPath);
                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workingDir;
                if (File.Exists(iconPath))
                    shortcut.IconLocation = iconPath + ",0";
                shortcut.Description = description;
                shortcut.Save();
            }
            catch { }
        }
    }
}
'@
Set-Content -Path $setupCsPath -Value $setupCs -Encoding UTF8

$setupExe = Join-Path $DistDir 'PTI-Packing-AGV-Setup.exe'
& $cscPath /nologo /target:winexe /optimize+ `
    /out:$setupExe `
    /win32icon:$icoPath `
    /resource:$setupZip,payload_setup.zip `
    /resource:$icoPath,app.ico `
    /resource:$logoPath,logo.png `
    /r:System.dll /r:System.Core.dll /r:Microsoft.CSharp.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll `
    $setupCsPath

if ($LASTEXITCODE -ne 0) { throw "Error compilando PTI-Packing-AGV-Setup.exe" }

# Limpiar artefactos temporales de compilacion
Remove-Item $appPayloadZip, $setupZip, $uninstallerExe, $launcherCsPath, $uninstallerCsPath, $setupCsPath -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host " COMPILACION COMPLETADA EXITOSAMENTE" -ForegroundColor Green
Write-Host " 1. Instalador Windows (.exe): $setupExe" -ForegroundColor Green
Write-Host " 2. Ejecutable Portable (.exe): $launcherExe" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
