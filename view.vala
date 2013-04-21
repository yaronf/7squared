using Gtk;
using Cairo;

/**
 * A GTK button in the shape of a simple square.
 */
public class Square: Button {
    private static const int BORDER_WIDTH = 1;
    private static const int WIDTH = 45;
    private int html_color = 0x808080; // some grey
    public Position position;
    private bool strong; // emphasize - used for selected squares

    public Square(Position position) {
        set_has_window(false);
        this.set_size_request(WIDTH, WIDTH);
        this.position = position;
    }

    public Square.with_color(int html_color, int width, Position position, bool strong) {
        this.html_color = html_color;
        set_has_window (false);
        this.set_size_request(width, width);
        this.position = position;
        this.strong = strong;
    }

    public override bool draw (Cairo.Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();

        int color_r = (this.html_color >> 16) & 0xFF;
        int color_g = (this.html_color >>  8) & 0xFF;
        int color_b = (this.html_color >>  0) & 0xFF;
        cr.set_source_rgba (color_r / 256.0, color_g / 256.0, color_b / 256.0, 1);
        cr.rectangle(BORDER_WIDTH, BORDER_WIDTH,
                      width - 2 * BORDER_WIDTH,
                      height - 2 * BORDER_WIDTH);
        cr.set_line_width(1.0);
        cr.set_line_join(LineJoin.ROUND);
        cr.fill_preserve();
        if (strong) {
            cr.set_source_rgba(0, 0, 0, 1); // black
            cr.stroke();
        }
        return true;
    }

    /*
     * This method gets called by Gtk+ when the actual size is known
     * and the widget is told how much space could actually be allocated.
     * It is called every time the widget size changes, for example when the
     * user resizes the window.
     */
    public override void size_allocate (Allocation allocation) {
        // The base method will save the allocation and move/resize the
        // widget's GDK window if the widget is already realized.
        base.size_allocate (allocation);

        // Move/resize other realized windows if necessary
    }
}

/**
 * The game's graphical view.
 */
public class GameView: Object {
    private GameModel model;
    private Builder builder;
    private Position selected_position = null;
    private Grid board;
    private Grid pending;
    private Box header_box;
    private Gtk.Window window;
    private Label score_label;
    private Label level_label;
    private Label to_next_level_label;
    private Label undo_label;
    private Label move_anywhere_label;
    private ToggleButton move_anywhere_button;
    private Button new_game_button;
    private Window score_dialog;
    const int BOARD_SQUARE_WIDTH = 45;
    const int PENDING_SQUARE_WIDTH = 30;

    /**
     * Create a new view, mostly based on a Glade-constructed "builder" file.
     */
    public GameView(GameModel model, Builder builder) {
        this.model = model;
        this.builder = builder;
        this.window = builder.get_object("window") as Gtk.Window;
        this.board = builder.get_object("game-board") as Grid;
        this.pending = builder.get_object("pending") as Grid;
        this.header_box = builder.get_object("header-box") as Box;
        this.score_label = builder.get_object("score-label") as Label;
        this.level_label = builder.get_object("level-label") as Label;
        this.to_next_level_label = builder.get_object("to-next-level-label") as Label;
        this.undo_label = builder.get_object("undo-label") as Label;
        this.move_anywhere_label = builder.get_object("move-anywhere-label") as Label;
        this.move_anywhere_button = builder.get_object("move-anywhere-button") as ToggleButton;
        move_anywhere_button.clicked.connect(move_anywhere_clicked);
        this.new_game_button = builder.get_object("new-game-button") as Button;
        new_game_button.clicked.connect(on_new_game_clicked);
        connect_model_signals(model);
    }

    private void connect_model_signals(GameModel m) {
        m.model_changed.connect(on_model_changed);
        m.model_finished.connect(on_model_finished);
    }

    private void on_new_game_clicked(Button b) {
        /* Ask user to confirm if game in progress */
        if (!model.game_finished) {
            bool confirm = false;
            var are_you_sure = new MessageDialog(window, Gtk.DialogFlags.MODAL, Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO,
            "Really restart the game?");
            are_you_sure.response.connect((response_id) => {
                confirm = (response_id == Gtk.ResponseType.YES);
                are_you_sure.destroy();});

            are_you_sure.run();
            if (!confirm)
                return;
        }

        /* Restart game*/
        int high_score = model.high_score;
        var new_model = new GameModel();
        new_model.high_score = high_score;
        new_model.initialize_game();
        connect_model_signals(new_model);
        model = new_model;
        on_model_changed(model);
    }

    /**
     * redraw the view when the model changes.
     */
    private void on_model_changed(GameModel m) {
        // stdout.printf("on_model_changed\n");

        //stdout.printf("model: " + model.serialize() + "\n");

//~         string json = model.to_json();
//~         stdout.printf("model: %s\n", json);
//~         GameModel model2 = new model.from_json(json);
//~         stdout.printf("deser done\n");
//~         string json2 = model2.to_json();
//~         stdout.printf("model2: " + json2 + "\n");

        this.draw_view();
    }

    private void on_model_finished(GameModel m) {
        var builder = new Builder();
        builder.add_from_file("score.ui");
        var score_close_button = builder.get_object("score-close-button") as Button;
        builder.connect_signals(null);
        score_close_button.clicked.connect(() => {score_dialog.destroy();});
        this.score_dialog = builder.get_object("score-dialog") as Gtk.Window;
        var score_label = builder.get_object("score-label") as Label;
        var high_score_label = builder.get_object("high-score-label") as Label;
        var moves_label = builder.get_object("moves-label") as Label;
        score_label.set_text(this.model.score.to_string());
        high_score_label.set_text(this.model.high_score.to_string());
        moves_label.set_text(this.model.moves.to_string());

        score_dialog.show_all();
    }

    /**
     * Convert well-known colors into RGB values.
     */
    int color_for_piece(Piece p) {
        switch (p) {
            case Piece.VIOLET:  return 0xaa66cc;
            case Piece.RED:  return 0xff4444;
            case Piece.GREEN:  return 0x99cc00;
            case Piece.YELLOW:  return 0xffbb33;
            case Piece.BLUE:  return 0x33b5e5;
            case Piece.HOLE:  return 0xe0e0e0;
            default: stderr.printf("Unknown piece???");
                return 0;
        }
    }

    [CCode (instance_pos = -1)]
    public void move_anywhere_clicked(Button source) {
        model.nop();
    }

    /**
     * A game piece was clicked.
     */
    private void on_clicked(Button source) {
        assert(source is Square);
        Position position = ((Square) source).position;
        // stdout.printf("Clicked: %s\n", position.to_string());
        if (selected_position == null) {
            // no selected position, select
            if (model.get_piece_at(position) != Piece.HOLE) {
                selected_position = position;
                model.nop();
            } // else do nothing
        } else if (selected_position != null && selected_position.equals(position)) {
            // clicked on selected position: deselct the piece
            selected_position = null;
            model.nop();
        } else if ((selected_position != null) && (model.get_piece_at(position) != Piece.HOLE)) {
            // illegal, deselect
            selected_position = null;
            model.nop();
        } else {
            // trying to move into a hole. Can we make this move?
            var move_anywhere = move_anywhere_button.get_active();
            if (move_anywhere) {
                model.move_anywheres--;
                move_anywhere_button.set_active(false);
            }
            // stdout.printf("move anywhere: " + move_anywhere.to_string() + "\n");
            if (model.is_legal_move(selected_position, position, move_anywhere)) {
                model.move(selected_position, position);
                selected_position = null;
                model.complete_round();
            } else {
                selected_position = null;
                model.nop();
            }
        }
    }

    /**
     * Draw the whole view.
     */
    public void draw_view() {
        draw_board();
        draw_pending();
        draw_header();
        board.show_all();
        pending.show_all();
        header_box.show_all();
    }

    /**
     * Draw the top part of the view
     */
    private void draw_header() {
        score_label.set_text("Score: " + model.score.to_string());
        level_label.set_text("Level " + model.level.to_string());
        to_next_level_label.set_text(model.lines_to_next_level().to_string() + " lines to next level");
        undo_label.set_text(model.undos.to_string());
        move_anywhere_label.set_text(model.move_anywheres.to_string());
        move_anywhere_button.set_sensitive(model.move_anywheres > 0);
        // TODO: we try to color the button when it is active
        if (!move_anywhere_button.get_active()) {
            move_anywhere_button.override_background_color(StateFlags.NORMAL, null);
        } else {
            Gdk.Color red;
            Gdk.Color.parse("red", out red);
            var style = move_anywhere_button.get_style();
            style.bg[StateFlags.NORMAL] = red;
            move_anywhere_button.set_style(style);
        }
    }

    /**
     * Draw the board.
     */
    void draw_board() {
        for (int x = 0; x < SIZE; x++) {
            for (int y = 0; y < SIZE; y++) {
                var position = new Position(x, y);
                Widget old_square = board.get_child_at(x, y);
                if (old_square != null) {
                    old_square.destroy();
                }
                Piece p = model.get_piece_at(position);
                int color = color_for_piece(p);
                var square = new Square.with_color(color, BOARD_SQUARE_WIDTH, position, selected_position != null && position.equals(selected_position));
                square.clicked.connect(on_clicked);
                board.attach(square, x, y, 1, 1);
            }
        }
    }

    /**
     * Draw the pending pieces (those that will be placed on the board in the next round).
     */
    void draw_pending() {
        for (int x = 0; x < 3; x++) {
            for (int y = 0; y < 2; y++) {
                var seq = 3 * y + x;
                Widget old_square = pending.get_child_at(x, y);
                if (old_square != null) {
                    old_square.destroy();
                }
                Piece p = model.pending_pieces[seq];
                int color = color_for_piece(p);
                var square = new Square.with_color(color, PENDING_SQUARE_WIDTH, new Position(x, y), false);
                pending.attach(square, x, y, 1, 1);
            }
        }
    }
}
