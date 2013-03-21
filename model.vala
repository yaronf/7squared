using Gee;

public enum Piece {
    VIOLET, RED, GREEN, YELLOW, BLUE, HOLE
}

public class Position {
    public int x {get; set;}
    public int y {get; set;}

    public Position(int x, int y) {
        this.x = x;
        this.y = y;
    }

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

public class GameModel: Object {
    private Piece [, ] board = new Piece[7, 7];
    public int level {get; private set;}
    private int moves;
    public int undos {get; private set;}
    public int move_anywheres {get; private set;}
    public int score {get; private set;}
    public Position? new_position {get; private set;}
    private int high_score;
    public Piece [] pending_pieces = new Piece[MAX_PENDING];

    public void initialize_game() {
        this.level = 1;
        this.moves = 0;
        this.undos = 0;
        this.move_anywheres = 0;
        this.score = 0;
        this.new_position = null;
        for (int i=0; i<SIZE; i++)
            for (int j=0; j<SIZE; j++)
                board[i, j] = Piece.HOLE;
        prepare_pending();
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

    public signal void model_changed();

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

    public void place_random_pieces(int num) {
        // This only works if the board is reasonably empty
        var filled = 0;
        while (filled < num) {
            Position pos = Position.get_random();
            var p = this.random_piece();
            if (get_piece_at(pos) == Piece.HOLE) {
                set_piece_at(pos, p);
                filled++;
            }
        }
    }

    public void move(Position from, Position to) {
        // Assumes move is legal
        Piece p = get_piece_at(from);
        set_piece_at(to, p);
        set_piece_at(from, Piece.HOLE);
        this.new_position = to;
    }

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
            if (p != Piece.HOLE) {
                var random_hole_idx = r.int_range(0, holes.size);
                var random_hole = holes.get(random_hole_idx);
                set_piece_at(random_hole, p);
                holes.remove_at(random_hole_idx);
            }
        }
    }

    private bool on_board(int x, int y) {
        return (x >= 0 && x < SIZE && y >= 0 && y < SIZE);
    }

    private static bool pos_equal(Position a, Position b) {
        // stdout.printf("Compare "+a.to_string()+","+b.to_string() + "-> " + a.equals(b).to_string() + "\n");
        return a.equals(b);
    }

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

    public bool is_legal_move(Position from, Position to) {
        var moves = this.legal_moves(from);
        return moves.contains(to);
    }

    static delegate void Incrementor(int x1, int y1, out int x2, out int y2);

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

    public ArrayList<Position> find_complete_lines() {
        var positions = new ArrayList<Position>();
        ArrayList<Position> p;

        for (int x = 0; x < SIZE; x++) {
            p = traverse_line(x, 0, (x, y, out a, out b) => {a = x; b = y+1;});
            positions.add_all(p);
        }

        for (int y = 0; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y;});
            positions.add_all(p);
        }

        for (int x = 0; x < SIZE; x++) {
            p = traverse_line(x, 0, (x, y, out a, out b) => {a = x+1; b = y+1;});
            positions.add_all(p);
        }

        for (int y = 1; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y+1;});
            positions.add_all(p);
        }

        for (int y = 0; y < SIZE; y++) {
            p = traverse_line(0, y, (x, y, out a, out b) => {a = x+1; b = y-1;});
            positions.add_all(p);
        }

        for (int x = 1; x < SIZE; x++) {
            p = traverse_line(x, SIZE-1, (x, y, out a, out b) => {a = x+1; b = y-1;});
            positions.add_all(p);
        }

        return positions;
    }

    private int calculate_score(int level, ArrayList<Position> positions) {
        return 5 * positions.size;
    }

    void clear_complete_lines(out bool found, out int score) {
        var positions = find_complete_lines();
        foreach (Position p in positions) {
            set_piece_at(p, Piece.HOLE);
        }
        found = (positions.size != 0);
        score = calculate_score(level, positions);
    }

    void increment_move_count() {
        this.moves++;
        this.level = 1 + (moves - 1)/40;
    }

    public int lines_to_next_level() {
        return 40 * level - moves;
    }

    public void nop() {
        model_changed();
    }

    public void complete_round() {
        bool found;
        int delta_score;
        clear_complete_lines(out found, out delta_score);
        score += delta_score;
        if (!found) {
            place_pending_pieces();
            clear_complete_lines(out found, out delta_score); // again!
            score += delta_score;
            prepare_pending();
        }
        increment_move_count();
        model_changed();
    }
}
