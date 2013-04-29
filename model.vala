using Gee;

/**
 * The piece, actually only its color.
 */
public enum Piece {
    VIOLET, RED, GREEN, YELLOW, BLUE, HOLE
}

/**
 * A position on the board.
 */
public class Position: Object {
    public int x {get; set;}
    public int y {get; set;}

    public Position(int x, int y) {
        this.x = x;
        this.y = y;
    }

    /**
     * Generate a random, valid position
     */
    public static Position get_random() {
        var r = new Rand();
        var x = r.int_range(0, SIZE);
        var y = r.int_range(0, SIZE);
        Position p = new Position(x, y);
        return p;
    }

    public string to_string() {
        return "[%d, %d]".printf(this.x, this.y);
    }

    public bool equals(Position p2) {
        return (x == p2.x && y == p2.y);
    }
}

const int SIZE = 7;
const int MIN_SEQ = 4;
const int MAX_PENDING = 6;
const int INITIAL_UNDOS = 2;
const int INITIAL_MOVE_ANYWHERES = 2;
const int INITIAL_PIECES = 3;

/**
 * The game "model", a logical abstraction of the 7squared game.
 */
public class GameModel: Object {
    public string save_file_name {get; set;}
    private Piece [, ] board = new Piece[7, 7];
    public int level {get; private set;}
    public int moves {get; private set;}
    private int lines;
    private int occupied;
    public int undos {get; set;}
    public int move_anywheres {get; set;}
    public int score {get; private set;}
    public int high_score {get; set;}
    public bool game_finished {get; private set;}
    public Piece [] pending_pieces {get; private set;}

    public string to_json() {
        var o = new Json.Object();
        o.set_int_member("level", level);
        o.set_int_member("moves", moves);
        o.set_int_member("lines", lines);
        o.set_int_member("occupied", occupied);
        o.set_int_member("undos", undos);
        o.set_int_member("move_anywheres", move_anywheres);
        o.set_int_member("score", score);
        o.set_int_member("high_score", high_score);
        o.set_boolean_member("game_finished", game_finished);
        var pending_pieces_array = new Json.Array.sized(MAX_PENDING);
        foreach (Piece p in pending_pieces) {
            pending_pieces_array.add_int_element((int) p);
        }
        o.set_array_member("pending_pieces", pending_pieces_array);
        var board_rows = new Json.Array.sized(SIZE);
        for (int x=0; x < SIZE; x++) {
            var row_array = new Json.Array.sized(SIZE);
            for (int y = 0; y < SIZE; y++) {
                row_array.add_int_element((int) board[x, y]);
            }
            board_rows.add_array_element(row_array);
        }
        o.set_array_member("board", board_rows);

        var n = new Json.Node(Json.NodeType.OBJECT);
        n.set_object(o);
        var generator = new Json.Generator();
        generator.set_pretty(true);
        generator.set_root(n);
        size_t len;
        return generator.to_data(out len);
    }

    public GameModel(string save_file_name) {
        this.save_file_name = save_file_name;
    }

    public GameModel.from_json(string json, string save_file_name) {
        this(save_file_name);
        var parser = new Json.Parser();
        try {
            parser.load_from_data(json);
        } catch (GLib.Error e) {
            stderr.printf("Could not read JSON: %s\n", e.message);
            Process.exit(1);
        }
        var root = parser.get_root();
        var o = root.get_object();
        level = (int) o.get_int_member("level"); // this returns int64
        moves = (int) o.get_int_member("moves");
        lines = (int) o.get_int_member("lines");
        occupied = (int) o.get_int_member("occupied");
        undos = (int) o.get_int_member("undos");
        move_anywheres = (int) o.get_int_member("move_anywheres");
        score = (int) o.get_int_member("score");
        high_score = (int) o.get_int_member("high_score");
        game_finished = (bool) o.get_boolean_member("game_finished");
        var pending_pieces_array = o.get_array_member("pending_pieces");
        pending_pieces = new Piece[MAX_PENDING];
        for (int i=0; i<MAX_PENDING; i++) {
            this.pending_pieces[i] = (Piece) (pending_pieces_array.get_int_element(i));
        }
        var board_array = o.get_array_member("board");
        this.board = new Piece[SIZE, SIZE];
        for (int x=0; x<SIZE; x++)
            for (int y=0; y<SIZE; y++)
                board[x, y] = (Piece) (board_array.get_array_element(x).get_int_element(y));
    }

    public void initialize_game() {
        this.level = 1;
        this.moves = 0;
        this.lines = 0;
        this.occupied = 0;
        this.undos = INITIAL_UNDOS;
        this.move_anywheres = INITIAL_MOVE_ANYWHERES;
        this.score = 0;
        this.game_finished = false;
        for (int i=0; i<SIZE; i++)
            for (int j=0; j<SIZE; j++)
                board[i, j] = Piece.HOLE;
        this.pending_pieces = new Piece[MAX_PENDING];
        prepare_pending();
        place_random_pieces(INITIAL_PIECES);
    }

    int number_of_pending() {
        switch(level) {
            case 1:
                return 3;
            case 2:
                return 4;
            case 3:
                return 5;
            default:
                return 6;
        }
    }

    private void prepare_pending() {
        int n = number_of_pending();
        for (int i = 0; i < n; i++) {
            pending_pieces[i] = random_piece();
        }
        for (int j = n; j < MAX_PENDING; j++) {
            pending_pieces[j] = Piece.HOLE;
        }
    }

    /**
     * The model was changed.
     *
     * This signal should be emitted whenever a change is made to the model that
     * potentially necessitates redrawing on the view.
     */
    public signal void model_changed();

    public signal void model_finished();

    private Piece random_piece() {
        var r = new Rand();
        return (Piece) r.int_range(Piece.VIOLET, Piece.HOLE);
    }

    public Piece get_piece_at(Position p) {
        return board[p.x, p.y];
    }

    public void set_piece_at(Position pos, Piece p) {
        board[pos.x, pos.y] = p;
        model_changed();
    }

    /**
     * Place pieces at random positions on the board.
     *
     * @param num Number of pieces.
     */
    public void place_random_pieces(int num) {
        // This only works if the board is reasonably empty
        var filled = 0;
        assert (occupied+num < SIZE*SIZE);
        while (filled < num) {
            Position pos = Position.get_random();
            var p = this.random_piece();
            if (get_piece_at(pos) == Piece.HOLE) {
                set_piece_at(pos, p);
                filled++;
                occupied++;
            }
        }
    }

    public void move(Position from, Position to) {
        // Assumes move is legal
        Piece p = get_piece_at(from);
        set_piece_at(to, p);
        set_piece_at(from, Piece.HOLE);
    }

    /**
     * Place all pending pieces on the board.
     *
     * Determine what are the remaining holes, and then fill as many as necessary by
     * pieces from the "pending" structure.
     */
    private void place_pending_pieces() {
        var r = new Rand();
        var holes = new ArrayList<Position>();
        for (int x=0; x<SIZE; x++) {
            for (int y=0; y<SIZE; y++) {
                var p = new Position(x, y);
                if (get_piece_at(p) == Piece.HOLE) {
                    holes.add(p);
                }
            }
        }
        foreach (Piece p in pending_pieces) {
            if (p != Piece.HOLE && occupied < SIZE*SIZE) {
                var random_hole_idx = r.int_range(0, holes.size);
                var random_hole = holes.get(random_hole_idx);
                set_piece_at(random_hole, p);
                holes.remove_at(random_hole_idx);
                occupied++;
            }
        }
    }

    private bool on_board(int x, int y) {
        return (x >= 0 && x < SIZE && y >= 0 && y < SIZE);
    }

    private static bool pos_equal(Position a, Position b) {
        return a.equals(b);
    }

    /**
     * Compute legal moves from a given position.
     *
     * Compute the legal moves from th eposition, that is,
     * all positions that are on a continuous area that contains
     * the source position.
     *
     * @param from The position to start from.
     */
    public ArrayList<Position> legal_moves(Position from) {
        var moves = new ArrayList<Position>((EqualFunc) pos_equal);
        var shadow = new bool[SIZE, SIZE];
        for (int x=0; x<SIZE; x++) {
            for (int y=0; y<SIZE; y++) {
                shadow[x, y] = false;
            }
        }
        shadow[from.x, from.y] = true;
        bool added = false;
        do {
            added = false;
            for (int x=0; x<SIZE; x++) {
                for (int y=0; y<SIZE; y++) {
                    if (!shadow[x, y] && (this.board[x, y] == Piece.HOLE)) {
                        if ((on_board(x-1, y) && shadow[x-1, y]) ||
                            (on_board(x+1, y) && shadow[x+1, y]) ||
                            (on_board(x, y-1) && shadow[x, y-1]) ||
                            (on_board(x, y+1) && shadow[x, y+1])) {
                                shadow[x, y] = true;
                                added = true;
                                var p = new Position(x, y);
                                // stdout.printf("added " + p.to_string() + "\n");
                                moves.add(p);
                            }
                    }
                }
            }
        } while (added);
        return moves;
    }

    public bool is_legal_move(Position from, Position to, bool move_anywhere) {
        if (move_anywhere) {
            return true;
        } else {
            var moves = this.legal_moves(from);
            return moves.contains(to);
        }
    }

    [CCode (has_target=false)]
    delegate void Incrementor(int x1, int y1, out int x2, out int y2);

    private ArrayList<Position> traverse_line(int x0, int y0, Incrementor inc) {
        var positions = new ArrayList<Position>();
        int startx = x0;
        int starty = y0;
        int endx = x0;
        int endy = y0;
        var seq = new ArrayList<Position>();
        if (get_piece_at(new Position(startx, starty)) != Piece.HOLE) {
            seq.add(new Position(startx, starty));
        }
        do {
            int new_endx, new_endy;
            inc(endx, endy, out new_endx, out new_endy);
            endx = new_endx;
            endy = new_endy;
            var color_start = get_piece_at(new Position(startx, starty));
            var color_end = on_board(endx, endy)?get_piece_at(new Position(endx, endy)):Piece.HOLE;
            if (color_start != color_end) {
                // if (seq.size>1) stdout.printf("seq size %d\n", seq.size);
                if (seq.size >= MIN_SEQ) {
                    positions.add_all(seq);
                }
                startx = endx;
                starty = endy;
                // stdout.printf("setting start %d %d\n", startx, starty);
                seq = new ArrayList<Position>();
                if (get_piece_at(new Position(startx, starty)) != Piece.HOLE) {
                    seq.add(new Position(startx, starty));
                }
            } else  if (color_end != Piece.HOLE) {
                seq.add(new Position(endx, endy));
            }
        } while (on_board(endx, endy));
        return positions;
    }

    public void find_complete_lines(out ArrayList<Position> positions, out int count_lines) {
        ArrayList<Position> p;
        positions = new ArrayList<Position>();
        count_lines = 0;

        for (int x = 0; x < SIZE; x++) {
            p = traverse_line(x, 0, (x, y, out a, out b) => {a = x; b = y+1;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }

        for (int y = 0; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }

        for (int x = 0; x < SIZE; x++) {
            p = traverse_line(x, 0, (x, y, out a, out b) => {a = x+1; b = y+1;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }

        for (int y = 1; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y+1;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }

        for (int y = 0; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y-1;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }

        for (int x = 1; x < SIZE; x++) {
            p = traverse_line(x, SIZE-1, (x, y, out a, out b) => {a = x+1; b = y-1;});
            if (p.size > 0) count_lines++;
            positions.add_all(p);
        }
    }

    private int calculate_score(int level, ArrayList<Position> positions) {
        // TODO: we cannot figure out the scoring in the original game
        return 5 * positions.size;
    }

    void clear_complete_lines(out int count_lines, out int score) {
        ArrayList<Position> positions;
        find_complete_lines(out positions, out count_lines);
        foreach (Position p in positions) {
            if (get_piece_at(p) != Piece.HOLE) {
                set_piece_at(p, Piece.HOLE);
                occupied--;
            }
        }
        score = calculate_score(level, positions);
    }

    void increment_move_count() {
        this.moves++;
    }

    /**
     * How many lines should be completed before user moves to next level?
     */
    public int lines_to_next_level() {
        return 40 * level - lines;
    }

    /*
     * Do nothing, just signal that some change occured to the model.
     */
    public void nop() {
        model_changed();
    }

    private void finish_game() {
        game_finished = true;
        if (score > high_score) {
            high_score = score;
        }
        model_finished();
    }

    private void save_game_to_file() {
        var save_data = this.to_json();
        bool ret;
        try {
            ret = FileUtils.set_contents(this.save_file_name, save_data);
        } catch (GLib.Error e) {
            ret = false;
        }
        if (!ret) {
            stderr.printf("Could not write save file");
            Process.exit(1);
        }
    }

    public void complete_round() {
        int delta_score;
        int count_lines;
        int lines_this_move;
        clear_complete_lines(out count_lines, out delta_score);
        score += delta_score;
        lines_this_move = count_lines;
        if (count_lines > 1) { // only user-initiated combos count
            move_anywheres++;
        }
        if (count_lines == 0) {
            // user could not complete a line, so finish the move
            place_pending_pieces();
            clear_complete_lines(out count_lines, out delta_score); // again!
            lines_this_move += count_lines;
            prepare_pending();
            level = lines / 40 + 1;
            increment_move_count();
        }
        lines += lines_this_move;
        level = lines / 40 + 1;
        score += delta_score;
        save_game_to_file();
        model_changed();
        if (occupied == SIZE*SIZE) {
            finish_game();
        }
    }
}
