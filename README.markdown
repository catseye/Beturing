Beturing
========

a Befunge-flavoured Turing machine
----------------------------------

*v1.1, Chris Pressey, June 8 2005*

### Introduction

Beturing is a programming language based on a "universal" Turing machine
with an unbounded, 2-dimensional "tape". (The Turing machine on which it
is based is "universal" in the sense that the machine's state transition
diagram is stored on the "tape" along with the data.)

### General Layout

This 2-dimensional "tape" is where all the action happens; it is called
the *playfield* and is divided into discrete units called *cells*. Each
cell may store exactly one of a number of *symbols* drawn from a finite
alphabet.

There are two "heads" that access the playfield, one of which (the *data
head*) reads and alters the data (like in a common Turing machine,) the
other of which (the *code head*) reads the state transition diagram.

The state transition diagram is made up of *codes*. Each code is a 2x2
block of cells in the following form:

    ab
    >/

The code head is considered to be over a code when it is over the
upper-left cell of it. The names and meanings of the four parts of the
code are as follows:

-   The upper-left cell of a code contains a symbol to look for, called
    the *seek symbol*. All symbols are valid seek symbols.
-   The upper-right cell of the code contains a symbol to replace it
    with, called the *replacement symbol*. All symbols are valid
    replacement symbols.
-   The lower-left cell of the code contains an indication of how to
    move the data head, called the *data head movement operator*. The
    set of valid data head movement operators is {`>`, `<`, `^`, `v`,
    `.`, `*`}.
-   The lower-right cell of the code contains an indication of what to
    do with the code head, called the *state transition operator*. The
    set of valid state transition operators is {`>`, `<`, `^`, `v`, `/`,
    `@`}.

### Syntax

When a Beturing playfield is loaded from source such as a text file,
lines are translated to rows in the playfield. The first line is loaded
at (0, 0), and subsequent lines are loaded at (0, 1), (0, 2), etc. Lines
which begin with a `#` are not loaded into the playfield. Certain lines
that begin with `#`, listed below, are directives meaningful to any
Beturing interpreter. The rest may have a local interpretation (such as
the `#!` convention on Unix systems,) or be ignored. A line which begins
with `##` is guaranteed to be ignored.

-   Lines of the form `# @(x, y)` where *x* and *y* are integers
    reposition the loading of the text file; subsequent lines will be
    loaded into the playfield at the given position.
-   Lines of the form `# C(x, y)` specify the initial position of the
    code head. The last such line is the one that takes effect.
-   Lines of the form `# D(x, y)` specify the initial position of the
    data head. The last such line is the one that takes effect.

### Semantics

When a Beturing machine is set in motion, it *interprets* the code under
the code head, transitions to a new state by moving the code head, then
repeats indefinitely until the machine enters the *halt* state.

Here is how each code is interpreted:

-   If the data head movement operator is the special symbol `*`, the
    following things happen:
    -   The data head is moved by the positive interpretation of the
        replacement symbol. (Note that this behaviour is new in version
        1.1; no data head movement would occur in the `*` case in v1.0.)
    -   The code head is moved by the positive interpretation (x2) of
        the state transition operator.

-   Otherwise, if the symbol under the data head matches the seek
    symbol, the following things happen:
    -   The replacement symbol is written to the cell under the data
        head.
    -   The data head is moved by the positive interpretation of the
        data head movement operator.
    -   The code head is moved by the positive interpretation (x2) of
        the state transition operator.

-   Otherwise the symbol under the data head does **not** match the seek
    symbol, and the following things happen:
    -   The code head is moved by the negative interpretation (x2) of
        the state transition operator.

The positive and negative interpretations of the data head movement and
state transition operators are given below:

    Symbol    Positive interpretation   Negative interpretation
    --------- ------------------------- -------------------------
    >         Move right                Move right
    <         Move left                 Move left
    ^         Move up                   Move up
    v         Move down                 Move down
    .         Don't move                Don't move
    /         Move right                Move down
    \         Move left                 Move down
    |         Move up                   Move down
    -         Move left                 Move right
    `         Move right                Move up
    '         Move left                 Move up
    @         Halt                      Halt

Note that "x2" in the rules given above means to advance two cells in
the given direction; this is used everywhere for moving the code head
because codes are 2x2 cell blocks.

### Discussion

The Beturing language was designed (in part) as a test of the
wire-crossing problem, in the following manner. Note these things about
Beturing:

-   Unlike Befunge's instruction pointer, the code head does not have
    "direction" or "delta" state; it has only "position" state. Its next
    position (and thus the machine's next state) is determined entirely
    by the state transition operator of the current code.
-   Also unlike Befunge and its `#` instruction, there is no "leap over"
    state transition operator. Therefore the next state must always be
    reachable by a continuous, unbroken path through the playfield.
-   Lastly, unlike Befunge and its torus, the Beturing playfield is
    really unbounded in all four directions - there is no wrapping
    around, making it a true plane.

All this added together means that a Beturing machine is incapable of
having a state transition diagram that is not a planar graph. A state
transition diagram which is a complete 5-vertex graph, for example, is
not planar.

This **might** mean that it is impossible to construct a true universal
Turing machine in Beturing, *if* a universal Turing machine requires a
state diagram that is not a planar graph.

If this were the case then Beturing would not be Turing-complete, and in
fact its level of computational power would probably be difficult to
determine.

### Update

Version 1.0 of the Beturing language, and an interpreter for it written
in Lua 5, was released June 6th 2005.

On June 7th, graue's development of the Archway language, and my
sketches for a Smallfuck interpreter in Beturing have both strongly
suggested that a universal Turing machine's state diagram can indeed be
a planar graph. I'd still like to go ahead and implement the Smallfuck
interpreter, though, since (even if it's a foregone conclusion) it would
be pretty impressive to see in action.

On June 8th I added the "data head can move on `*`" semantics for v1.1,
in preparation for implementing a Smallfuck interpreter from my
sketches. Note that this addition does not constitute an increase in
Beturing's computational power, only its expressiveness. It was possible
to do the same thing in v1.0, but it required one code per symbol in the
alphabet, which was a little excessive.

On June 10th I added extra "decision" state transition operators (shown
with a grey background in the above table) for extra flexibility; there
are some planar graphs that can't be rendered in Beturing with just `/`:
see the diagram of the Uhing 5-state Busy Beaver machine, for example.
As always, you can use the `-o` flag to the interpreter to enforce the
v1.0 semantics where these aren't available, if you're a purist.
