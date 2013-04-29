using Gtk;
using Gdk;
using Cairo;

/*
 * Drag and drop constants
 */

const int BYTE_BITS = 8;
const int WORD_BITS = 16;
const int DWORD_BITS = 32;

/**
 * Define a list of data types called "targets" that a destination widget will
 * accept. The string type is arbitrary, and negotiated between DnD widgets by
 * the developer. An enum or Quark can serve as the integer target id.
 */
enum Target {
    INT32,
    STRING,
    ROOTWIN
}

/* datatype (string), restrictions on DnD (Gtk.TargetFlags), datatype (int) */
const TargetEntry[] target_list = {
    { "INTEGER",    0, Target.INT32 },
    { "STRING",     0, Target.STRING },
    { "text/plain", 0, Target.STRING },
    { "application/x-rootwindow-drop", 0, Target.ROOTWIN }
};

/**
 * A GTK button in the shape of a simple square.
 */
public class Square: Button {
    private static const int BORDER_WIDTH = 1;
    private int html_color = 0x808080; // some grey
    public Position position;
    private bool strong; // emphasize - used for selected squares

    public Square(Position position, int width, bool is_drag_src = false, bool is_drag_dest = false) {
        set_has_window(false);
        this.set_size_request(width, width);
        this.position = position;

        if (is_drag_src) {
            // Make the this widget a DnD source.
            // Why doesn't Gtk.Label work here?
            Gtk.drag_source_set (
                    this,                      // widget will be drag-able
                    ModifierType.BUTTON1_MASK, // modifier that will start a drag
                    target_list,               // lists of target to support
                    DragAction.COPY            // what to do with data after dropped
            );
            // All possible source signals
            this.drag_begin.connect(on_drag_begin);
            this.drag_data_get.connect(on_drag_data_get);
//~             this.drag_data_delete.connect(on_drag_data_delete);
            this.drag_end.connect(on_drag_end);
        }
        if (is_drag_dest) {
            // Make this widget a DnD destination.
            Gtk.drag_dest_set (
                    this,                     // widget that will accept a drop
                    DestDefaults.MOTION       // default actions for dest on DnD
                    | DestDefaults.HIGHLIGHT,
                    target_list,              // lists of target to support
                    DragAction.COPY           // what to do with data after dropped
            );
            // All possible destination signals
//~             this.drag_motion.connect(this.on_drag_motion);
//~             this.drag_leave.connect(this.on_drag_leave);
            this.drag_drop.connect(this.on_drag_drop);
//~             this.drag_data_received.connect(this.on_drag_data_received);
        }
    }

    public Square.with_color(int html_color, int width, Position position,
            bool strong, bool is_drag_src = false, bool is_drag_dest = false) {
        this(position, width, is_drag_src, is_drag_dest);
        this.html_color = html_color;
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

    // Drag source signals

    private void on_drag_begin (Widget widget, DragContext context) {
        print ("%s: on_drag_begin\n", widget.name);
        var icon_window = new Gtk.Window();
        icon_window.set_decorated(false);
        var icon_widget = new Square.with_color(this.html_color, 32, new Position(0, 0), false, false);
        icon_window.add(icon_widget);
        icon_window.show_all();
        Gtk.drag_set_icon_widget(context, icon_window, 16, 16);
    }

    private void on_drag_data_get(Widget widget, DragContext context,
                                   SelectionData selection_data,
                                   uint target_type, uint time) {
        print ("%s: on_drag_data_get\n", widget.name);
        int data_to_send = this.position.x * SIZE + this.position.y; // encode position into a single int
        uchar [] buffer;
        convert_long_to_bytes(Posix.htonl(data_to_send), out buffer);
        selection_data.set (
            selection_data.get_target(),      // target type
            BYTE_BITS,                 // number of bits per 'unit'
            buffer // pointer to data to be sent
        );
    }

    /**
     * Convert a "long" into a buffer of bytes, in "network" order (big endian)
     */
    private void convert_long_to_bytes(uint32 number, out uchar [] buffer) {
        buffer = new uchar[sizeof(uint32)];
        for (int i = 0; i<sizeof(uint32); i++) {
            buffer[i] = (uchar) (number & 0xFF);
            number = number >> 8;
        }
    }

    /** Emitted when DnD ends. This is used to clean up any leftover data. */
    private void on_drag_end(Widget widget, DragContext context) {
        print ("%s: on_drag_end\n", widget.name);
    }

    private bool on_drag_drop(Widget widget, DragContext context,
                               int x, int y, uint time) {
        stderr.printf("on_drag_drop\n");
        var target_type = (Atom) context.list_targets().nth_data (Target.INT32);
        Gtk.drag_get_data(
        widget,         // will receive 'drag_data_received' signal
        context,        // represents the current state of the DnD
        target_type,    // the target type we want
        time            // time stamp
        );

        return true;
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
    private Gtk.Window score_dialog;
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
        string save_file_name = model.save_file_name;
        var new_model = new GameModel(save_file_name);
        new_model.high_score = model.high_score;
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
        this.draw_view();
    }

    private void on_model_finished(GameModel m) {
        var builder = new Builder();
        try {
            builder.add_from_file("score.ui");
        } catch (GLib.Error e) {
            stderr.printf("Could not load score dialog %s\n", e.message);
            Process.exit(1);
        }
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
    public static int color_for_piece(Piece p) {
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
            move_into_hole(selected_position, position);
        }
    }

/**
 * "data received" on a piece: signifies the end of a drag-and-drop handshake.
 */
    private void on_piece_data_received(Widget widget, DragContext context,
                                        int x, int y,
                                        SelectionData selection_data,
                                        uint target_type, uint time) {
        stderr.printf("on_drag_data_received\n");
        bool dnd_success = true;
        assert(target_type == Target.INT32);
        uint32* datap = (uint32*) selection_data.get_data();
        assert(datap != null);
        int32 data = (int) Posix.ntohl(*datap);
        stderr.printf("Got data: %d\n", data);
        int data_x = data / SIZE;
        int data_y = data % SIZE;
        var src_position = new Position(data_x, data_y);
        Gtk.drag_finish(context, dnd_success, true, time);

        // Now, do the actual move
        move_into_hole(src_position, ((Square) widget).position);
    }

    private void move_into_hole(Position src, Position dest) {
        // trying to move into a hole. Can we make this move?
        var move_anywhere = move_anywhere_button.get_active();
        if (move_anywhere) {
            model.move_anywheres--;
            move_anywhere_button.set_active(false);
        }
        // stdout.printf("move anywhere: " + move_anywhere.to_string() + "\n");
        if (model.is_legal_move(src, dest, move_anywhere)) {
            model.move(src, dest);
            selected_position = null;
            model.complete_round();
        } else {
            selected_position = null;
            model.nop();
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
//~         if (!move_anywhere_button.get_active()) {
//~             move_anywhere_button.override_background_color(StateFlags.NORMAL, null);
//~         } else {
//~             Gdk.Color red;
//~             Gdk.Color.parse("red", out red);
//~             var style = move_anywhere_button.get_style();
//~             style.bg[StateFlags.NORMAL] = red;
//~             move_anywhere_button.set_style(style);
//~         }
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
                bool is_drag_src = (p != Piece.HOLE);
                bool is_drag_dest = (p == Piece.HOLE);
                var square = new Square.with_color(color, BOARD_SQUARE_WIDTH, position, selected_position != null && position.equals(selected_position), is_drag_src, is_drag_dest);
                if (is_drag_dest) {
                    square.drag_data_received.connect(on_piece_data_received);
                }
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
                var square = new Square.with_color(color, PENDING_SQUARE_WIDTH, new Position(x, y), false, false, false);
                pending.attach(square, x, y, 1, 1);
            }
        }
    }
}
