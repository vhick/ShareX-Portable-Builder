// ShareXPortable Community launcher (Windows .NET Framework 4.8).
// ShareX binaries are NOT patched. Never removes system registry entries or host files.
// Direct mode: PersonalPath.cfg points at Data/ShareX without moving the data.
// Conflict mode: when ShareX's host registry configuration takes priority, use the
// developer's built-in -portable mode and move the personal folder safely on exit.
using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class ShareXPortableLauncher
{
    private static string root, appDir, personalDir, appPersonal, cfg, marker;

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            root = Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory);
            appDir = Path.Combine(root, "App", "ShareX");
            personalDir = Path.Combine(root, "Data", "ShareX");
            appPersonal = Path.Combine(appDir, "ShareX");
            cfg = Path.Combine(appDir, "PersonalPath.cfg");
            marker = Path.Combine(appDir, "Portable");
            if (args.Length == 1 && args[0] == "--self-test")
            {
                if (!File.Exists(Path.Combine(appDir, "ShareX.exe"))) return 11;
                if (!File.Exists(Path.Combine(root, "App", "AppInfo", "appinfo.ini"))) return 12;
                if (!Directory.Exists(Path.Combine(root, "Data"))) return 13;
                return 0;
            }
            if (!File.Exists(Path.Combine(appDir, "ShareX.exe")))
                throw new FileNotFoundException("Missing official ShareX.exe", Path.Combine(appDir, "ShareX.exe"));

            Directory.CreateDirectory(Path.Combine(root, "Data"));
            string unique;
            using (SHA256 sha = SHA256.Create())
                unique = BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(root.ToUpperInvariant())), 0, 12).Replace("-", "");
            bool owned;
            using (Mutex mutex = new Mutex(true, "Local\\ShareXPortable_" + unique, out owned))
            {
                if (!owned)
                {
                    MessageBox.Show("This portable ShareX folder is already open. Use the ShareX tray icon.",
                        "ShareX Portable", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return 0;
                }
                try { return Run(args); }
                finally { mutex.ReleaseMutex(); }
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "ShareX Portable - startup error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    private static bool ExistingPersonalPathOverride()
    {
        // ShareX prioritizes HKLM/HKCU PersonalPath over PersonalPath.cfg.
        foreach (RegistryHive hive in new RegistryHive[] { RegistryHive.LocalMachine, RegistryHive.CurrentUser })
        {
            foreach (RegistryView view in new RegistryView[] { RegistryView.Registry64, RegistryView.Registry32 })
            {
                using (RegistryKey baseKey = RegistryKey.OpenBaseKey(hive, view))
                using (RegistryKey key = baseKey.OpenSubKey(@"SOFTWARE\ShareX", false))
                    if (key != null && key.GetValue("PersonalPath") != null) return true;
            }
        }
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (File.Exists(Path.Combine(local, "ShareX", "PersonalPath.cfg"))) return true;
        return false;
    }

    private static int Run(string[] args)
    {
        // If a prior exceptional termination left fallback data in App/, recover it
        // before switching back to the preferred direct-Data mode.
        bool overrideFound = ExistingPersonalPathOverride();
        if (Directory.Exists(appPersonal))
        {
            if (Directory.Exists(personalDir))
                throw new IOException("Two ShareX personal folders were found:\n" + appPersonal + "\n" + personalDir +
                    "\n\nNeither was deleted. Back them up and reconcile before running again.");
            Directory.CreateDirectory(Path.GetDirectoryName(personalDir));
            Directory.Move(appPersonal, personalDir);
        }
        if (overrideFound) return RunFallback(args);
        return RunDirect(args);
    }

    private static int RunDirect(string[] args)
    {
        Directory.CreateDirectory(personalDir);
        // This file only lives inside this portable package's own App folder.
        // No BOM; ShareX reads the single absolute path on every launch.
        File.WriteAllText(cfg, personalDir, new UTF8Encoding(false));
        if (File.Exists(marker)) throw new InvalidOperationException("Unexpected upstream Portable marker. Builder must remove it.");
        return StartChild(args, false);
    }

    private static int RunFallback(string[] args)
    {
        // Source-of-truth remains Data/ShareX while closed. Move it temporarily next
        // to ShareX.exe only when host ShareX configuration prevents direct-Data mode.
        // Directory.Move is same-volume (App and Data live beneath the same root).
        if (Directory.Exists(appPersonal)) throw new IOException("Unexpected app personal folder.");
        Directory.CreateDirectory(personalDir);
        Directory.Move(personalDir, appPersonal);
        bool markerCreated = false;
        try
        {
            File.WriteAllBytes(marker, new byte[0]);
            markerCreated = true;
            // -portable outranks ShareX PersonalPath settings in the Windows registry.
            return StartChild(args, true);
        }
        finally
        {
            try
            {
                if (Directory.Exists(appPersonal) && !Directory.Exists(personalDir))
                    Directory.Move(appPersonal, personalDir);
            }
            finally
            {
                if (markerCreated && File.Exists(marker)) File.Delete(marker);
            }
        }
    }

    private static int StartChild(string[] args, bool forcePortable)
    {
        ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(appDir, "ShareX.exe"));
        psi.WorkingDirectory = appDir;
        psi.UseShellExecute = false;
        // Do not alter APPDATA, LOCALAPPDATA, registry, Startup, or shell associations.
        // No automatic uploads or cleanup. Optional command line actions are user-initiated.
        StringBuilder command = new StringBuilder(forcePortable ? "-portable" : "");
        foreach (string arg in args)
        {
            if (arg.StartsWith("--", StringComparison.Ordinal) && arg == "--self-test") continue;
            if (command.Length != 0) command.Append(' ');
            command.Append(Quote(arg));
        }
        psi.Arguments = command.ToString();
        using (Process process = Process.Start(psi))
        {
            if (process == null) throw new InvalidOperationException("ShareX did not start.");
            // ShareX normally remains running in the tray. Wait until it fully exits.
            process.WaitForExit();
            return process.ExitCode;
        }
    }

    private static string Quote(string input)
    {
        // Standard Windows argument quoting (correctly doubles backslashes at quotes).
        if (input.Length == 0) return "\"\"";
        if (input.IndexOfAny(new[] { ' ', '\t', '\n', '\v', '\"' }) < 0) return input;
        StringBuilder sb = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in input)
        {
            if (c == '\\') { slashes++; continue; }
            if (c == '"') { sb.Append('\\', slashes * 2 + 1); sb.Append('"'); slashes = 0; continue; }
            sb.Append('\\', slashes); slashes = 0; sb.Append(c);
        }
        sb.Append('\\', slashes * 2); sb.Append('"');
        return sb.ToString();
    }
}
