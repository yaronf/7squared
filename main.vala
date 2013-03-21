using Gtk;
using Cairo;

void exit_clicked() {
    Gtk.main_quit();
}

int main (string[] args) {
        Gtk.init(ref args);
        var model = new GameModel();

    try {
        var builder = new Builder();
        builder.add_from_file("main.ui");
        builder.connect_signals(null);
        var window = builder.get_object("main_window") as Gtk.Window;
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
