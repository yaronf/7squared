using Gtk;
using Cairo;

/**
 * The game's main driver.
 */
public class Main {
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
            Gtk.init(ref args);
            var model = new GameModel();

        try {
            var builder = new Builder();
            builder.add_from_file("main.ui");
            builder.connect_signals(null);
            var window = builder.get_object("main-window") as Gtk.Window;
            window.destroy.connect(Gtk.main_quit);

            var view = new GameView(model, builder);

            model.initialize_game();
            model.place_random_pieces(3);

            window.show_all();
            Gtk.main();
        } catch (Error e) {
            stderr.printf ("Could not load UI: %s\n", e.message);
            return 1;
        }

        return 0;
    }
}
