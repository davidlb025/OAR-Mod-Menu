using System.Diagnostics;

namespace OarSetup;
internal sealed class SetupForm : Form
{
    private readonly TextBox gamePath = new() { Dock = DockStyle.Fill, AccessibleName = "Carpeta del juego" };
    private readonly TextBox status = new() { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, BorderStyle = BorderStyle.None, BackColor = SystemColors.Window, ScrollBars = ScrollBars.Vertical, TabStop = false };
    private readonly Button install = new() { Text = "Instalar / actualizar", AutoSize = true, Padding = new Padding(12, 6, 12, 6) };
    private readonly Button uninstall = new() { Text = "Desinstalar", AutoSize = true, Padding = new Padding(12, 6, 12, 6) };
    private readonly Button browse = new() { Text = "Examinar…", AutoSize = true };
    private readonly ProgressBar progress = new() { Dock = DockStyle.Fill, Visible = false, Style = ProgressBarStyle.Marquee };
    private bool busy;
    internal SetupForm()
    {
        Text = "OAR Mod Menu · v1.0.0";
        StartPosition = FormStartPosition.CenterScreen;
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(740, 510);
        MinimumSize = new Size(650, 480);
        Font = new Font("Segoe UI", 10);
        BackColor = SystemColors.Window;
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(28), ColumnCount = 1, RowCount = 8 };
        foreach (var height in new[] { 46, 56, 26, 38, 24 }) layout.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 14));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
        layout.Controls.Add(new Label { Text = "OAR Mod Menu", Font = new Font(Font.FontFamily, 22, FontStyle.Bold), Dock = DockStyle.Fill, AutoSize = true }, 0, 0);
        layout.Controls.Add(new Label { Text = "v1.0.0 · One-armed Robber para Windows\nMapas y probador del catálogo completo de cosméticos.", Dock = DockStyle.Fill, ForeColor = Color.FromArgb(70, 74, 80) }, 0, 1);
        layout.Controls.Add(new Label { Text = "Carpeta de One-armed Robber", Dock = DockStyle.Fill }, 0, 2);
        var pathRow = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1 };
        pathRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        pathRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 116));
        pathRow.Controls.Add(gamePath, 0, 0); pathRow.Controls.Add(browse, 1, 0);
        layout.Controls.Add(pathRow, 0, 3);
        layout.Controls.Add(new Label { Text = "Cierra el juego antes de instalar o desinstalar.", Dock = DockStyle.Fill, ForeColor = Color.FromArgb(70, 74, 80) }, 0, 4);
        layout.Controls.Add(status, 0, 5); layout.Controls.Add(progress, 0, 6);
        var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
        actions.Controls.Add(install); actions.Controls.Add(uninstall); layout.Controls.Add(actions, 0, 7);
        Controls.Add(layout);
        var games = InstallEngine.FindGames();
        gamePath.Text = games.FirstOrDefault() ?? "";
        status.Text = "F6 abre el menú. F5 cambia de sección.\r\nF7/F8 eligen; F9 carga o prueba.\r\n\r\nPrueba máscaras, gorros, atuendos, gestos y skins de armas del catálogo instalado, aunque no estén en tu inventario. Las Heist Coins no se modifican.\r\n\r\nSe incluye UE4SS y se crean copias de los archivos que se actualicen. La desinstalación conserva los archivos ajenos o modificados.";
        browse.Click += (_, _) => { using var dialog = new FolderBrowserDialog { Description = "Selecciona la carpeta One-armed robber", UseDescriptionForTitle = true, ShowNewFolderButton = false, SelectedPath = gamePath.Text }; if (dialog.ShowDialog(this) == DialogResult.OK) gamePath.Text = dialog.SelectedPath; };
        install.Click += async (_, _) => await RunOperation(false);
        uninstall.Click += async (_, _) => await RunOperation(true);
        FormClosing += (_, e) => { if (busy) e.Cancel = true; };
        AcceptButton = install;
    }
    private async Task RunOperation(bool removing)
    {
        busy = true; install.Enabled = uninstall.Enabled = browse.Enabled = gamePath.Enabled = false; progress.Visible = true;
        var path = gamePath.Text;
        status.Text = removing ? "Retirando los archivos registrados del menú…" : "Comprobando el juego y preparando los archivos…";
        try { status.Text = await Task.Run(() => removing ? InstallEngine.Uninstall(path) : InstallEngine.Install(path)); }
        catch (UnauthorizedAccessException) { status.Text = "Windows no permite escribir en esa carpeta. Cierra este instalador y ábrelo con ‘Ejecutar como administrador’."; }
        catch (Exception error) { status.Text = "No se ha completado la operación.\r\n\r\n" + error.Message; }
        finally { busy = false; install.Enabled = uninstall.Enabled = browse.Enabled = gamePath.Enabled = true; progress.Visible = false; }
    }
}
