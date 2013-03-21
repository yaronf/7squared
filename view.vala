using Gtk;
using Cairo;

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

class GameView {
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
    const int BOARD_SQUARE_WIDTH = 45;
    const int PENDING_SQUARE_WIDTH = 30;

    public GameView(GameModel model, Builder builder) {
        this.model = model;
        this.builder = builder;
        this.window = builder.get_object("window") as Gtk.Window;
        AspectFrame board_frame = builder.get_object("board-frame") as AspectFrame;
        this.board = builder.get_object("game-board") as Grid;
        this.pending = builder.get_object("pending") as Grid;
        this.header_box = builder.get_object("header-box") as Box;
        this.score_label = builder.get_object("score-label") as Label;
        this.level_label = builder.get_object("level-label") as Label;
        this.to_next_level_label = builder.get_object("to-next-level-label") as Label;
        model.model_changed.connect(on_model_changed);
    }

    private void on_model_changed(GameModel m) {
        // stdout.printf("on_model_changed\n");
        this.draw_view();
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

    private void on_clicked(Button source) {
        assert(source is Square);
        Position position = ((Square) source).position;
        // stdout.printf("Clicked: %s\n", position.to_string());
        if (selected_position == null) {
            if (model.get_piece_at(position) != Piece.HOLE) {
                selected_position = position;
                model.nop();
            } // else do nothing
        } else if (selected_position != null && selected_position.equals(position)) { // do nothing, other than deselcting the piece
            selected_position = null;
            model.nop();
        } else if ((selected_position != null) && (model.get_piece_at(position) == Piece.HOLE)) {
            if (model.is_legal_move(selected_position, position)) {
                model.move(selected_position, position);
                selected_position = null;
                model.complete_round();
            } else {
                selected_position = null;
            }
        }
    }

    public void draw_view() {
        draw_board();
        draw_pending();
        draw_header();
        board.show_all();
        pending.show_all();
        header_box.show_all();
    }

    private void draw_header() {
        score_label.set_text("Score: " + model.score.to_string());
        level_label.set_text("Level " + model.level.to_string());
        to_next_level_label.set_text(model.lines_to_next_level().to_string() + " lines to next level");
    }

    public void draw_board() {
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
