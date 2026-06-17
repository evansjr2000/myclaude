@* Hello X11.

This is a small graphical program written in standard~C using
Donald Knuth's literate programming paradigm.  It opens a single
top-level window via the X~Window~System and draws two clickable
buttons inside it:

\medskip
$${\vbox{
\item{} {\bf Hello} --- prints
        \.{Hello World, and the current local time.}
        (followed by the current local time) to standard output.

\item{} {\bf Exit}  --- closes the window and terminates the program.
}}$$

\medskip\noindent
The window may also be closed via the standard window-manager close
gesture (the \.{WM\_DELETE\_WINDOW} protocol), in which case the program
exits cleanly as if {\bf Exit} had been clicked.  All graphics and event
handling are performed with raw \.{Xlib} calls (\.{libX11}); no toolkit
(Xt, Motif, GTK, Qt) is involved.

@ {\bf How it works.}
The program is a textbook Xlib client.  It performs four phases in
sequence:

\medskip\item{1.}  Connect to the X~display server and discover screen
  defaults (root window, default colours, default font).

\item{2.}  Create a top-level window, install a graphics context, and
  request the events of interest (exposure, button presses, structure
  notifications).

\item{3.}  Enter an event loop: each event is dispatched to a handler
  that either repaints the buttons (\.{Expose}), checks for a button
  click (\.{ButtonPress}), or terminates the loop
  (\.{ClientMessage} with \.{WM\_DELETE\_WINDOW}).

\item{4.}  On exit, release the graphics context and close the display.
\medskip

@ {\bf Literate programming.}
Donald Knuth introduced {\it literate programming\/} in 1984 as a way of
writing software that is meant to be read by human beings first and
executed by computers second.  Rather than annotating code with
comments, a literate program interweaves prose and code in a single
source document.  The prose explains the {\it why\/}---the motivation,
the design decisions, the mathematical reasoning---while the code
expresses the {\it how}.  The two live together in one file
(conventionally given the extension \.{.w}) and are separated only at
build time by two companion tools: \.{ctangle} and \.{cweave}.

@ {\bf ctangle.}
\.{ctangle} is the {\it tangling\/} tool.  It reads a \.{.w} source
file and extracts the C~code sections, assembling them in the order
dictated by named chunk references rather than the order in which they
appear in the document.  The result is a plain \.{.c} file that a
standard C~compiler can process without any knowledge of literate
programming.  In this project, running
$$\.{ctangle hello-x11.w}$$
produces \.{hello-x11.c}, which is then compiled with \.{cc} and linked
against \.{libX11} to create the \.{hello-x11} executable.  The
generated \.{.c} file should be treated as a build artefact: the
\.{.w} file is the true source of record.

@ {\bf cweave.}
\.{cweave} is the {\it weaving\/} tool.  It reads the same \.{.w} source
and produces a \.{.tex} file formatted for \.{pdftex} using the
\.{cwebmac} macro package.  \.{cweave} pretty-prints all C~code with
bold keywords, italic identifiers, and cross-references, and numbers
every named chunk so the reader can follow the program's logical
structure independently of its physical layout.  An index of identifiers
and a table of contents are generated automatically.  Running
$$\.{cweave hello-x11.w}$$
produces \.{hello-x11.tex}; running \.{pdftex} on that file yields the
typeset documentation you are reading now.

@ {\bf Compilation.}  After tangling with \.{ctangle}:
$$\.{cc -O2 -o hello-x11 hello-x11.c -lX11}$$
On systems where \.{X11/Xlib.h} is not on the default include path, add
\.{-I/usr/X11R6/include -L/usr/X11R6/lib} (Linux/BSD) or
\.{-I/opt/X11/include -L/opt/X11/lib} (macOS with XQuartz).

@ {\bf Program structure.}  The top-level arrangement of the tangled
output is:

@c
@<Includes@> @/
@<Constants@> @/
@<Type definitions@> @/
@<Globals@> @/
@<Time helper@> @/
@<Hit testing@> @/
@<Drawing routines@> @/
@<Event handlers@> @/
@<Display setup@> @/
@<Display teardown@> @/
@<Main function@>

@* Includes and constants.

@ Three standard headers cover the C~runtime; \.{Xlib.h} is the only
X~Window header needed for this program (the higher-level \.{Xutil.h}
is pulled in for the \.{XSizeHints} structure used to suggest a fixed
window size to the window manager).

@<Includes@>=
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

@ The window dimensions and the geometry of the two buttons are fixed
at compile time --- the program is not designed to be resized.  The
buttons are stacked vertically with a uniform margin.

@<Constants@>=
#define WIN_W      320     /* top-level window width in pixels         */
#define WIN_H      160     /* top-level window height in pixels        */
#define BTN_W      120     /* button width in pixels                   */
#define BTN_H       40     /* button height in pixels                  */
#define MARGIN      20     /* margin around and between buttons        */
#define WIN_TITLE   "Hello X11"

@ Each button has its origin at the top-left corner of its rectangle.
|HELLO_X|/|HELLO_Y| place the {\bf Hello} button in the upper region
of the window; |EXIT_X|/|EXIT_Y| place the {\bf Exit} button directly
below it.  Both buttons are horizontally centred.

@<Constants@>+=
#define HELLO_X    ((WIN_W - BTN_W) / 2)
#define HELLO_Y    MARGIN
#define EXIT_X     ((WIN_W - BTN_W) / 2)
#define EXIT_Y     (MARGIN + BTN_H + MARGIN)

@* Data structures.

@ A |Button| record bundles the four geometry fields and the label
string for a single clickable rectangle.  Storing the geometry in a
struct (rather than chasing six bare \.{\#define}s through every event
handler) keeps the hit-test routine to a single line.

@<Type definitions@>=
typedef struct {
    int         x, y;     /* top-left corner, in window coordinates    */
    int         w, h;     /* width and height in pixels                */
    const char *label;    /* null-terminated text drawn inside         */
} Button;

@ Two globals hold the X~Window state: the open display connection and
the graphics context used for every draw call.  They are initialised
by |display_open| and released by |display_close|; in between they are
read by the drawing and event-handling routines.  Keeping them at file
scope avoids threading them through every callback as parameters.

@<Globals@>=
static Display *g_dpy = NULL;     /* connection to the X~server         */
static GC       g_gc  = NULL;     /* graphics context for all drawing   */
static Window   g_win = 0;        /* the top-level window               */
static Atom     g_wm_delete = 0;  /* \.{WM\_DELETE\_WINDOW} client atom */

@ The two buttons are file-scope so that |draw_buttons| and |hit_test|
can iterate over them without rebuilding the array on every event.
The order in this array also determines paint order (top to bottom).

@<Globals@>+=
static const Button g_buttons[2] = {
    { HELLO_X, HELLO_Y, BTN_W, BTN_H, "Hello"  },
    { EXIT_X,  EXIT_Y,  BTN_W, BTN_H, "Exit"   }
};
#define N_BUTTONS ((int)(sizeof g_buttons / sizeof g_buttons[0]))

@* Time helper.

@ |format_local_time| writes the current local time into |out| as
\.{YYYY-MM-DD HH:MM:SS}.  |out| must hold at least 20 bytes
(19~characters plus a null terminator).  The format string is
deliberately unambiguous --- ISO~8601 date plus 24-hour time --- so
the line printed by the {\bf Hello} button is locale-independent.

@<Time helper@>=
static void format_local_time(char *out, size_t max_len)
{
    time_t     now = time(NULL);
    struct tm *lt  = localtime(&now);
    if (lt) strftime(out, max_len, "%Y-%m-%d %H:%M:%S", lt);
    else    snprintf(out, max_len, "(time unavailable)");
}

@* Hit testing.

@ |hit_test| returns the index of the button containing the point
$(x,y)$, or $-1$ if no button is hit.  The buttons do not overlap, so
the first match wins.

@<Hit testing@>=
static int hit_test(int x, int y)
{
    for (int i = 0; i < N_BUTTONS; i++) {
        const Button *b = &g_buttons[i];
        if (x >= b->x && x < b->x + b->w &&
            y >= b->y && y < b->y + b->h)
            return i;
    }
    return -1;
}

@* Drawing routines.

@ |draw_button| paints a single button: an outlined rectangle with the
label centred horizontally and vertically.  The label is centred by
querying the font metrics of the current graphics context with
|XQueryTextExtents|; this avoids hard-coding a font width and keeps the
labels centred even if the user installs a different default font.

@<Drawing routines@>=
static void draw_button(const Button *b)
{
    XDrawRectangle(g_dpy, g_win, g_gc, b->x, b->y, b->w, b->h);
    @<Centre and draw the button label@>
}

@ The text-extents query reports the label's bounding box in the
current font.  The horizontal centre is straightforward; the vertical
centre uses the font's ascent so the label sits on a baseline that
splits the button cleanly.

@<Centre and draw the button label@>=
int          dir, ascent, descent;
XCharStruct  ext;
int          len = (int)strlen(b->label);
XQueryTextExtents(g_dpy, XGContextFromGC(g_gc),
                  b->label, len, &dir, &ascent, &descent, &ext);
int tx = b->x + (b->w - ext.width) / 2;
int ty = b->y + (b->h + ascent - descent) / 2;
XDrawString(g_dpy, g_win, g_gc, tx, ty, b->label, len);

@ |draw_buttons| repaints every button.  It is called on every
\.{Expose} event so the window can recover from being uncovered or
resized by the window manager.

@<Drawing routines@>+=
static void draw_buttons(void)
{
    for (int i = 0; i < N_BUTTONS; i++)
        draw_button(&g_buttons[i]);
}

@* Event handlers.

@ |on_hello_click| prints the greeting and the current local time to
standard output.  |fflush| is called explicitly because \.{stdout} is
typically line-buffered when attached to a terminal but
{\it block\/}-buffered when redirected to a pipe or file --- without
the flush, a user redirecting the output to \.{tee} would see nothing
until the program exited.

@<Event handlers@>=
static void on_hello_click(void)
{
    char ts[32];
    format_local_time(ts, sizeof ts);
    printf("Hello World, and the current local time: %s\n", ts);
    fflush(stdout);
}

@ |on_button_press| dispatches a \.{ButtonPress} event to the
appropriate handler.  Returning non-zero asks the main loop to exit;
this is how the {\bf Exit} button terminates the program.  Clicks
outside any button are silently ignored.

@<Event handlers@>+=
static int on_button_press(const XButtonEvent *ev)
{
    int idx = hit_test(ev->x, ev->y);
    if (idx < 0) return 0;
    if (strcmp(g_buttons[idx].label, "Hello") == 0) {
        on_hello_click();
        return 0;
    }
    if (strcmp(g_buttons[idx].label, "Exit") == 0) {
        return 1;
    }
    return 0;
}

@ |on_client_message| handles the \.{WM\_DELETE\_WINDOW} protocol:
when the user clicks the window manager's close decoration, the server
delivers a \.{ClientMessage} carrying the |g_wm_delete| atom.  We
return non-zero to break out of the event loop so the close button
behaves identically to the in-window {\bf Exit} button.

@<Event handlers@>+=
static int on_client_message(const XClientMessageEvent *ev)
{
    if ((Atom)ev->data.l[0] == g_wm_delete) return 1;
    return 0;
}

@* Display setup.

@ |display_open| performs all four pre-loop X~Window steps: open the
display, create the window, create the graphics context, and register
for the \.{WM\_DELETE\_WINDOW} protocol.  The body is split into four
sub-modules so no single chunk exceeds twenty-four lines.  The function
returns 1 on success or 0 on any failure, with a diagnostic on
\.{stderr}.

@<Display setup@>=
static int display_open(void)
{
    @<Open the X display@>
    @<Create the top-level window@>
    @<Create the graphics context@>
    @<Register for window-manager close@>
    XMapWindow(g_dpy, g_win);
    return 1;
}

@ The display name is read from the |DISPLAY| environment variable when
the argument to |XOpenDisplay| is |NULL|.  A failure here typically
means \.{DISPLAY} is unset or the user lacks permission to connect to
the named server.

@<Open the X display@>=
g_dpy = XOpenDisplay(NULL);
if (!g_dpy) {
    fputs("Error: cannot open X display "
          "(is $DISPLAY set?)\n", stderr);
    return 0;
}

@ The window is created as a child of the screen's root window, with a
white background and a one-pixel black border.  We immediately call
|XSelectInput| to subscribe to the three event masks the program needs:
\.{ExposureMask} (initial paint and repaints),
\.{ButtonPressMask} (mouse clicks), and
\.{StructureNotifyMask} (the window-manager close gesture is delivered
as a structure-notify-class \.{ClientMessage}).
The title is set with |XStoreName| so window managers display
\.{Hello X11} in the title bar.

@<Create the top-level window@>=
int     scr   = DefaultScreen(g_dpy);
Window  root  = RootWindow(g_dpy, scr);
g_win = XCreateSimpleWindow(g_dpy, root, 0, 0, WIN_W, WIN_H, 1,
                            BlackPixel(g_dpy, scr),
                            WhitePixel(g_dpy, scr));
XStoreName(g_dpy, g_win, WIN_TITLE);
XSelectInput(g_dpy, g_win,
             ExposureMask | ButtonPressMask | StructureNotifyMask);

@ The graphics context is created against the window's drawable.  We
pre-set the foreground colour to black --- the default is
implementation-defined.  All draw calls (rectangles and strings) reuse
this single GC; there is no need for separate contexts since the
program draws in only one colour and one font.

@<Create the graphics context@>=
g_gc = XCreateGC(g_dpy, g_win, 0, NULL);
if (!g_gc) {
    fputs("Error: cannot create graphics context\n", stderr);
    XDestroyWindow(g_dpy, g_win);
    XCloseDisplay(g_dpy);
    g_dpy = NULL;
    return 0;
}
XSetForeground(g_dpy, g_gc, BlackPixel(g_dpy, DefaultScreen(g_dpy)));

@ The \.{WM\_DELETE\_WINDOW} protocol is the standard way for an
X~client to learn that the user has clicked the window manager's
close decoration.  We intern the atom and register it on the window;
the server will then deliver a \.{ClientMessage} carrying that atom
instead of summarily destroying the window.

@<Register for window-manager close@>=
g_wm_delete = XInternAtom(g_dpy, "WM_DELETE_WINDOW", False);
XSetWMProtocols(g_dpy, g_win, &g_wm_delete, 1);

@* Display teardown.

@ |display_close| is the symmetric counterpart to |display_open|.  It
releases the graphics context, destroys the window, and closes the
display.  Each step is guarded so the function is safe to call after
a partial setup failure.

@<Display teardown@>=
static void display_close(void)
{
    if (g_dpy) {
        if (g_gc)  { XFreeGC(g_dpy, g_gc); g_gc = NULL; }
        if (g_win) { XDestroyWindow(g_dpy, g_win); g_win = 0; }
        XCloseDisplay(g_dpy);
        g_dpy = NULL;
    }
}

@* Main function.

@ |main| ignores its arguments --- the program takes no command-line
options.  After a successful display setup it enters a blocking event
loop driven by |XNextEvent|; each event is dispatched to the
appropriate handler.  The loop terminates when either the {\bf Exit}
button is clicked or the window-manager close gesture is received.

@<Main function@>=
int main(int argc, char **argv)
{
    (void)argc; (void)argv;
    if (!display_open()) return 1;
    @<Run the event loop@>
    display_close();
    return 0;
}

@ The event loop dispatches three event types and silently drops the
rest.  A non-zero return from a handler breaks the loop.

@<Run the event loop@>=
for (;;) {
    XEvent ev;
    XNextEvent(g_dpy, &ev);
    int quit = 0;
    switch (ev.type) {
    case Expose:
        if (ev.xexpose.count == 0) draw_buttons();
        break;
    case ButtonPress:
        quit = on_button_press(&ev.xbutton);
        break;
    case ClientMessage:
        quit = on_client_message(&ev.xclient);
        break;
    default:
        break;
    }
    if (quit) break;
}

@* Xlib API Calls.
This program uses the synchronous core of \.{libX11}.  All identifiers
listed here are declared in \.{<X11/Xlib.h>} (or \.{<X11/Xutil.h>} for
the few utility types).

\medskip
\item{$\bullet$} {\tt Display *XOpenDisplay(const char *name)}.
  \par\noindent Parameter: {\tt name} --- display string such as
  \.{":0"} or \.{NULL} to read \.{\$DISPLAY}.
  Returns a connection handle, or \.{NULL} on failure.

\item{$\bullet$} {\tt int XCloseDisplay(Display *dpy)}.
  Closes the connection and frees all server-side resources still
  associated with it.

\item{$\bullet$} {\tt int DefaultScreen(Display *dpy)} (macro).
  Returns the integer index of the user's default screen, used as the
  second argument to many other macros.

\item{$\bullet$} {\tt Window RootWindow(Display *dpy, int scr)} (macro).
  Returns the screen's root window, used as the parent of every
  top-level application window.

\item{$\bullet$} {\tt unsigned long BlackPixel(Display *dpy, int scr)}
  / {\tt WhitePixel(Display *dpy, int scr)} (macros).
  Return colormap entries for pure black / pure white on the named
  screen.  Used here for the window border, foreground, and background.

\item{$\bullet$} {\tt Window XCreateSimpleWindow(Display *dpy,
  Window parent, int x, int y, unsigned w, unsigned h, unsigned bw,
  unsigned long border, unsigned long bg)}.
  Allocates a new \.{InputOutput} window with the given geometry,
  border width, and pixel colours.  The window is created
  {\it unmapped}: it does not appear until |XMapWindow|.

\item{$\bullet$} {\tt int XStoreName(Display *dpy, Window w,
  const char *name)}.
  Sets the \.{WM\_NAME} property; window managers display this in the
  title bar.

\item{$\bullet$} {\tt int XSelectInput(Display *dpy, Window w,
  long mask)}.
  Specifies which event classes the server should deliver for the
  window.  This program ORs three mask bits.

\item{$\bullet$} {\tt int XMapWindow(Display *dpy, Window w)}.
  Requests that the window be made visible (subject to the window
  manager's policy).

\item{$\bullet$} {\tt int XDestroyWindow(Display *dpy, Window w)}.
  Removes the window and any descendants.

\item{$\bullet$} {\tt GC XCreateGC(Display *dpy, Drawable d,
  unsigned long valuemask, XGCValues *values)}.
  Allocates a graphics context.  This program passes
  |valuemask = 0| and |values = NULL| to accept all server defaults,
  then customises the foreground via |XSetForeground|.

\item{$\bullet$} {\tt int XSetForeground(Display *dpy, GC gc,
  unsigned long pixel)}.
  Sets the foreground pixel value used by subsequent draw calls.

\item{$\bullet$} {\tt int XFreeGC(Display *dpy, GC gc)}.
  Releases a graphics context allocated by |XCreateGC|.

\item{$\bullet$} {\tt int XDrawRectangle(Display *dpy, Drawable d,
  GC gc, int x, int y, unsigned w, unsigned h)}.
  Draws the {\it outline\/} of a rectangle.  The rectangle covers
  $w+1$ columns and $h+1$ rows of pixels.

\item{$\bullet$} {\tt int XDrawString(Display *dpy, Drawable d,
  GC gc, int x, int y, const char *string, int length)}.
  Draws an 8-bit text string at the given baseline position using
  the GC's current font.

\item{$\bullet$} {\tt int XQueryTextExtents(Display *dpy,
  XID font\_id, const char *string, int len,
  int *direction, int *ascent, int *descent,
  XCharStruct *overall)}.
  Asks the server for the metrics of a string in the named font.
  Used here to centre the button label.

\item{$\bullet$} {\tt GContext XGContextFromGC(GC gc)} (macro).
  Returns the X resource ID associated with a graphics context, used
  here as the |font_id| argument to |XQueryTextExtents|.

\item{$\bullet$} {\tt Atom XInternAtom(Display *dpy,
  const char *name, Bool only\_if\_exists)}.
  Returns the unique server-wide atom for a string property name.
  Used to obtain \.{WM\_DELETE\_WINDOW}.

\item{$\bullet$} {\tt Status XSetWMProtocols(Display *dpy, Window w,
  Atom *protocols, int count)}.
  Tells the server which window-manager protocols this client is
  willing to handle, here just \.{WM\_DELETE\_WINDOW}.

\item{$\bullet$} {\tt int XNextEvent(Display *dpy, XEvent *ev\_return)}.
  Blocks until an event is available for the connection, then writes
  it into the supplied union.

@ {\bf POSIX System Calls and Library Functions.}
The following identifiers from the POSIX.1-2008 standard are used
directly in this program.

\medskip
\item{$\bullet$} {\tt time\_t time(time\_t *t)}.
  Returns the current calendar time (seconds since the Epoch).

\item{$\bullet$} {\tt struct tm *localtime(const time\_t *clock)}.
  Converts a calendar time into broken-down local time in a static
  buffer.

\item{$\bullet$} {\tt size\_t strftime(char *s, size\_t max,
  const char *fmt, const struct tm *tm)}.
  Formats a broken-down time into a character buffer using a
  \.{printf}-like format string.  This program uses
  \.{"\%Y-\%m-\%d \%H:\%M:\%S"}.

\item{$\bullet$} {\tt int printf(const char *fmt, ...)}.
  Writes formatted output to standard output.

\item{$\bullet$} {\tt int snprintf(char *s, size\_t n,
  const char *fmt, ...)}.
  Bounded \.{sprintf}; used as a fallback when |localtime| fails.

\item{$\bullet$} {\tt int fputs(const char *s, FILE *stream)}.
  Writes a string without a trailing newline; used for diagnostics
  on \.{stderr}.

\item{$\bullet$} {\tt int fflush(FILE *stream)}.
  Flushes the buffered output of |stream|; called after each
  {\bf Hello} click so the line appears immediately even when
  \.{stdout} is piped.

\item{$\bullet$} {\tt size\_t strlen(const char *s)}.
  Returns the number of bytes in the string before its null
  terminator.

\item{$\bullet$} {\tt int strcmp(const char *a, const char *b)}.
  Lexicographic byte-wise comparison; used to dispatch button clicks
  by label.

@* Index.
