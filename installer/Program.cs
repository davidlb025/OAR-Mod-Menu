using System.Text.Json;

namespace OarSetup;
internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        string? Value(string key)
        {
            var index = Array.IndexOf(args, key);
            return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
        }
        if (args.Length > 0)
        {
            try
            {
                string result;
                if (args.Contains("--install")) result = InstallEngine.Install(Value("--game-dir") ?? throw new ArgumentException("Falta --game-dir."));
                else if (args.Contains("--uninstall")) result = InstallEngine.Uninstall(Value("--game-dir") ?? throw new ArgumentException("Falta --game-dir."));
                else throw new ArgumentException("Opciones: --install|--uninstall --game-dir RUTA.");
                if (Value("--report") is string report) File.WriteAllText(report, JsonSerializer.Serialize(new { success = true, result }));
                Console.WriteLine(result);
                return 0;
            }
            catch (Exception error)
            {
                if (Value("--report") is string report) File.WriteAllText(report, JsonSerializer.Serialize(new { success = false, error = error.Message }));
                Console.Error.WriteLine(error.Message);
                return 1;
            }
        }
        ApplicationConfiguration.Initialize();
        Application.Run(new SetupForm());
        return 0;
    }
}
