using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace OarSetup;

internal sealed class InstallRecord
{
    public string Relative { get; set; } = "";
    public string InstalledHash { get; set; } = "";
    public string? Backup { get; set; }
    public string? OriginalHash { get; set; }
}
internal sealed class InstallState
{
    public string Version { get; set; } = "1.0.0";
    public string GameRoot { get; set; } = "";
    public bool AddedLoader { get; set; }
    public List<InstallRecord> Files { get; set; } = [];
}
internal static class InstallEngine
{
    internal const string StateName = "OARPracticeMenu.install.json";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true, PropertyNameCaseInsensitive = true };
    private static readonly HashSet<string> LoaderFiles = new(StringComparer.OrdinalIgnoreCase) { "UE4SS.dll", "dwmapi.dll", "UE4SS-settings.ini" };
    internal static string Normalize(string path) => Path.TrimEndingDirectorySeparator(Path.GetFullPath(path));
    internal static string Child(string root, string relative)
    {
        if (Path.IsPathRooted(relative) || relative.Contains(':')) throw new IOException("Ruta de archivo no válida.");
        var normalized = Normalize(root);
        var full = Path.GetFullPath(Path.Combine(normalized, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!full.StartsWith(normalized + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) throw new IOException("La ruta sale de la carpeta de instalación.");
        if (File.Exists(full) && File.GetAttributes(full).HasFlag(FileAttributes.ReparsePoint)) throw new IOException("La ruta de archivo es un enlace simbólico.");
        // Do not follow directory junctions or symlinks while changing files.
        for (var parent = Path.GetDirectoryName(full); parent is not null; parent = Path.GetDirectoryName(parent))
        {
            if (Directory.Exists(parent) && File.GetAttributes(parent).HasFlag(FileAttributes.ReparsePoint)) throw new IOException("La ruta contiene un enlace de directorio. Selecciona la ubicación física del juego.");
            if (parent.Equals(normalized, StringComparison.OrdinalIgnoreCase)) break;
        }
        return full;
    }
    internal static string Bin(string root) => Child(root, "OAR/Binaries/Win64");
    internal static void ValidateGame(string root)
    {
        if (!File.Exists(Child(Bin(root), "OAR-Win64-Shipping.exe"))) throw new IOException("Selecciona la carpeta One-armed robber que contiene OAR\\Binaries\\Win64.");
    }
    internal static void AssertClosed(string root)
    {
        var exe = Child(Bin(root), "OAR-Win64-Shipping.exe");
        foreach (var process in Process.GetProcessesByName("OAR-Win64-Shipping"))
        {
            using (process)
            {
                try
                {
                    if (string.Equals(process.MainModule?.FileName, exe, StringComparison.OrdinalIgnoreCase)) throw new IOException("Cierra One-armed Robber y vuelve a intentarlo.");
                }
                catch (System.ComponentModel.Win32Exception) { throw new IOException("No se puede comprobar el proceso del juego. Cierra One-armed Robber antes de continuar."); }
            }
        }
    }
    internal static List<string> FindGames()
    {
        var roots = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Steam") };
        using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam")) if (key?.GetValue("SteamPath") is string value) roots.Add(value);
        var libraries = new HashSet<string>(roots, StringComparer.OrdinalIgnoreCase);
        foreach (var root in roots)
        {
            var file = Path.Combine(root, "steamapps", "libraryfolders.vdf");
            if (!File.Exists(file)) continue;
            foreach (Match m in Regex.Matches(File.ReadAllText(file), "\"path\"\\s+\"([^\"]+)\"")) libraries.Add(m.Groups[1].Value.Replace(@"\\", @"\"));
        }
        var found = new List<string>();
        foreach (var library in libraries)
        {
            var manifest = Path.Combine(library, "steamapps", "appmanifest_2551020.acf");
            if (!File.Exists(manifest)) continue;
            var m = Regex.Match(File.ReadAllText(manifest), "\"installdir\"\\s+\"([^\"]+)\"");
            if (!m.Success) continue;
            var candidate = Path.Combine(library, "steamapps", "common", m.Groups[1].Value);
            if (File.Exists(Path.Combine(candidate, "OAR", "Binaries", "Win64", "OAR-Win64-Shipping.exe"))) found.Add(Normalize(candidate));
        }
        return found.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }
    private static string Hash(string file) { using var stream = File.OpenRead(file); return Convert.ToHexString(SHA256.HashData(stream)); }
    private static string Hash(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes));
    private static Dictionary<string, byte[]> Payload()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("OARPracticeMenu.Package.zip") ?? throw new IOException("Falta el paquete integrado.");
        using var zip = new ZipArchive(stream, ZipArchiveMode.Read);
        var result = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        foreach (var entry in zip.Entries)
        {
            if (entry.FullName.EndsWith('/')) continue;
            var relative = entry.FullName.Replace('/', '\\');
            if (!LoaderFiles.Contains(relative) && !relative.StartsWith(@"Mods\OARPracticeMenu\", StringComparison.OrdinalIgnoreCase)) throw new IOException("El paquete contiene una ruta no admitida.");
            _ = Child(Path.GetTempPath(), relative);
            using var input = entry.Open(); using var output = new MemoryStream(); input.CopyTo(output);
            if (!result.TryAdd(relative, output.ToArray())) throw new IOException("El paquete contiene rutas duplicadas.");
        }
        if (!result.ContainsKey(@"Mods\OARPracticeMenu\Scripts\main.lua") || !result.ContainsKey("UE4SS.dll")) throw new IOException("El paquete está incompleto.");
        return result;
    }
    private static InstallState? ReadState(string root)
    {
        var statePath = Child(Bin(root), StateName);
        if (!File.Exists(statePath)) return null;
        var text = File.ReadAllText(statePath).TrimStart('\uFEFF');
        var state = JsonSerializer.Deserialize<InstallState>(text, JsonOptions) ?? throw new IOException("Registro de instalación vacío.");
        if (!Normalize(state.GameRoot).Equals(Normalize(root), StringComparison.OrdinalIgnoreCase)) throw new IOException("El registro pertenece a otra instalación.");
        foreach (var file in state.Files)
        {
            _ = Child(Bin(root), file.Relative);
            if (!LoaderFiles.Contains(file.Relative) && !file.Relative.StartsWith(@"Mods\OARPracticeMenu\", StringComparison.OrdinalIgnoreCase) && !file.Relative.StartsWith(@"ue4ss\Mods\OARPracticeMenu\", StringComparison.OrdinalIgnoreCase)) throw new IOException("Registro con una ruta no admitida.");
            if (file.Backup is not null) _ = BackupPath(Bin(root), file.Backup);
        }
        return state;
    }
    private static string BackupPath(string bin, string backup)
    {
        var full = Path.GetFullPath(backup);
        var backupRoot = Child(bin, "OARPracticeBackups");
        if (!full.StartsWith(backupRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) throw new IOException("Copia de seguridad fuera de la instalación.");
        return Child(backupRoot, Path.GetRelativePath(backupRoot, full));
    }
    private static void WriteState(string path, InstallState state)
    {
        var temporary = path + ".tmp-" + Guid.NewGuid().ToString("N");
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(state, JsonOptions), new System.Text.UTF8Encoding(false));
            File.Move(temporary, path, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    internal static string Install(string gameRoot)
    {
        var root = Normalize(gameRoot); ValidateGame(root); AssertClosed(root);
        var bin = Bin(root); var previous = ReadState(root); var payload = Payload();
        var hasRootLoader = File.Exists(Child(bin, "UE4SS.dll"));
        var hasNestedLoader = File.Exists(Child(bin, "ue4ss/UE4SS.dll"));
        var manageLoader = !hasNestedLoader && (previous?.AddedLoader == true || !hasRootLoader);
        if (manageLoader && previous is null && File.Exists(Child(bin, "dwmapi.dll"))) throw new IOException("Ya existe dwmapi.dll de otro mod. Instala UE4SS por separado para conservarlo.");
        if (hasNestedLoader && hasRootLoader) throw new IOException("Hay dos instalaciones de UE4SS. Conserva una sola antes de instalar el menú; no se han modificado sus archivos.");
        var modPrefix = hasNestedLoader ? @"ue4ss\Mods\OARPracticeMenu\" : @"Mods\OARPracticeMenu\";
        if (!manageLoader)
        {
            var existingLoader = Child(bin, hasNestedLoader ? "ue4ss/UE4SS.dll" : "UE4SS.dll");
            if (Hash(existingLoader) != Hash(payload["UE4SS.dll"])) throw new IOException("La versión de UE4SS existente no coincide con la comprobada para este menú. Se ha conservado. Usa la compilación 3.0.1-1190-gf673aac0 o instala el mod manualmente desde el ZIP portátil.");
        }
        var chosen = payload.Where(p => manageLoader || !LoaderFiles.Contains(p.Key)).Select(p => new KeyValuePair<string, byte[]>(p.Key.StartsWith(@"Mods\OARPracticeMenu\", StringComparison.OrdinalIgnoreCase) ? modPrefix + p.Key[@"Mods\OARPracticeMenu\".Length..] : p.Key, p.Value)).ToList();
        if (previous is not null && chosen.All(p => File.Exists(Child(bin, p.Key)) && Hash(Child(bin, p.Key)) == Hash(p.Value))) return "v1.0.0 ya está instalada y sus archivos coinciden.";
        var backupRoot = Child(bin, "OARPracticeBackups/" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N")[..8]);
        var state = new InstallState { GameRoot = root, AddedLoader = manageLoader };
        var rollback = new List<(string Target, string? Backup)>();
        try
        {
            foreach (var (relative, bytes) in chosen)
            {
                var target = Child(bin, relative); string? immediateBackup = null;
                if (File.Exists(target))
                {
                    immediateBackup = Child(backupRoot, relative); Directory.CreateDirectory(Path.GetDirectoryName(immediateBackup)!);
                    File.Copy(target, immediateBackup);
                }
                rollback.Add((target, immediateBackup));
                var oldRecord = previous?.Files.FirstOrDefault(f => f.Relative.Equals(relative, StringComparison.OrdinalIgnoreCase));
                state.Files.Add(new InstallRecord { Relative = relative, InstalledHash = Hash(bytes),
                    Backup = oldRecord is not null ? oldRecord.Backup : immediateBackup,
                    OriginalHash = oldRecord is not null ? oldRecord.OriginalHash : immediateBackup is null ? null : Hash(immediateBackup) });
                Directory.CreateDirectory(Path.GetDirectoryName(target)!); File.WriteAllBytes(target, bytes);
            }
            WriteState(Child(bin, StateName), state);
        }
        catch
        {
            foreach (var (target, backup) in rollback.AsEnumerable().Reverse())
                if (backup is not null) File.Copy(backup, target, true); else if (File.Exists(target)) File.Delete(target);
            throw;
        }
        return "Instalado. Abre el juego desde Steam y pulsa F6. F4 cambia de sección.";
    }
    internal static string Uninstall(string gameRoot)
    {
        var root = Normalize(gameRoot); ValidateGame(root); AssertClosed(root);
        var bin = Bin(root); var state = ReadState(root);
        if (state is null) return "No hay una instalación registrada de este menú.";
        var otherMods = new[] { "Mods", "ue4ss/Mods" }.Select(p => Child(bin, p)).Where(Directory.Exists)
            .Any(mods => Directory.EnumerateDirectories(mods).Any(p => Path.GetFileName(p) is not ("OARPracticeMenu" or "shared")));
        var remaining = new List<InstallRecord>();
        // Validate every restore before changing any installed file.
        foreach (var file in state.Files)
            if (file.Backup is not null && (!File.Exists(BackupPath(bin, file.Backup)) || Hash(BackupPath(bin, file.Backup)) != file.OriginalHash))
                throw new IOException("Falta una copia de seguridad o ha sido modificada: " + file.Relative);
        foreach (var file in state.Files)
        {
            var target = Child(bin, file.Relative);
            if (LoaderFiles.Contains(file.Relative) && otherMods) continue;
            if (File.Exists(target) && Hash(target) != file.InstalledHash) { remaining.Add(file); continue; }
            if (file.Backup is not null) { Directory.CreateDirectory(Path.GetDirectoryName(target)!); File.Copy(BackupPath(bin, file.Backup), target, true); }
            else if (File.Exists(target)) File.Delete(target);
        }
        foreach (var relative in new[] { "Mods/OARPracticeMenu/Scripts", "Mods/OARPracticeMenu", "ue4ss/Mods/OARPracticeMenu/Scripts", "ue4ss/Mods/OARPracticeMenu" })
        {
            var directory = Child(bin, relative);
            if (Directory.Exists(directory) && !Directory.EnumerateFileSystemEntries(directory).Any()) Directory.Delete(directory);
        }
        var stateFile = Child(bin, StateName);
        if (remaining.Count > 0) { state.Files = remaining; WriteState(stateFile, state); return "Se ha retirado el menú. Se conservan archivos modificados y su registro para revisarlos."; }
        File.Delete(stateFile);
        return otherMods ? "Menú desinstalado. Se conserva UE4SS para los otros mods." : "Menú desinstalado. Se conservan las copias de seguridad.";
    }
}
