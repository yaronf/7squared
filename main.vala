using Gtk;
using Cairo;

/**
 * The game's main driver.
 */
public class Main {
    const string save_file_suffix = ".7squared";

    /**
     * The exit button was clicked.
     *
     * This is the signal handler for the GUI's Exit button. You can ignore the compilation warning.
     */
    [CCode (instance_pos = -1)]
    public void exit_clicked() {
        Gtk.main_quit();
    }

    static int main (string[] args) {
        GameModel model;
        Gtk.init(ref args);

        string home = Environment.get_home_dir();
        string save_file_name = GLib.Path.build_filename(home, save_file_suffix);
        if (FileUtils.test(save_file_name, FileTest.EXISTS)) {
            string save_data;
            size_t len;
            var ret = FileUtils.get_contents(save_file_name, out save_data, out len);
            if (!ret) {
                stderr.printf("Could not read save file.");
                Process.exit(1);
            }
            model = new GameModel.from_json(save_data, save_file_name);
        } else {
            model = new GameModel(save_file_name);
            model.initialize_game();
        }

        try {
            var builder = new Builder();
            builder.add_from_file("main.ui");
            builder.connect_signals(null);
            var window = builder.get_object("main-window") as Gtk.Window;
            window.destroy.connect(Gtk.main_quit);

            var view = new GameView(model, builder);
            model.model_changed();

            window.show_all();
            Gtk.main();
        } catch (Error e) {
            stderr.printf ("Could not load UI: %s\n", e.message);
            return 1;
        }

        return 0;
    }
}
