\datethis
@* Countdown.

This is a program written in Donald Knuth's {\it literate programming\/}
paradigm.  It displays a live countdown --- days, hours, minutes, and
seconds --- to a fixed future instant.  By default it runs in the
terminal that launched it; given the option \.{-gui} it instead opens a
window on the X~Window System.  The default target is

$$\.{2026-08-19 08:00:00}$$

\noindent (the morning of 19~August 2026), but any target may be supplied
on the command line.  In GUI mode the user starts the countdown with the
keyboard or the mouse, may pause and resume it, and quits when finished;
in terminal mode the countdown runs immediately and the user quits with
\.{Ctrl-C}.

@ {\bf Literate programming.}
Donald Knuth introduced literate programming in 1984 as a way of writing
software meant to be read by human beings first and executed by computers
second.  Rather than annotating code with comments, a literate program
interweaves prose and code in a single source document (conventionally
given the extension \.{.w}).  The prose explains the {\it why}; the code
expresses the {\it how}.  Two companion tools separate them at build time:
\.{ctangle} extracts the compilable C~source, and \.{cweave} produces the
typeset documentation you are now reading.  In this project both are
driven through the \.{cweb.sh} helper script:
$$\.{./cweb.sh ctangle countdown.w}\qquad\.{./cweb.sh cweave countdown.w}$$

@ {\bf A note on module size.}  By project convention every numbered
module (the unit \.{cweave} typesets as one ``section'') contains fewer
than twenty-four lines of code.  Long constructions are therefore split
into several named sections that are stitched together at tangle time.
This keeps each idea small enough to be grasped whole.

@ {\bf Program structure.}  The tangled output is assembled in the order
below.  Each named section is elaborated in its own module further on.

@c
@<Header files@>@/
@<Constants@>@/
@<The application state |App|@>@/
@<Parse the target time@>@/
@<Compute the remaining seconds@>@/
@<Format a duration@>@/
@<Open the display@>@/
@<Create the window@>@/
@<Create the graphics context@>@/
@<Render the display@>@/
@<Handle one X event@>@/
@<The event-and-timer loop@>@/
@<Run the countdown in the terminal@>@/
@<The |main| function@>

@* Header files.
The program draws on three families of declarations: the C~standard
library, the POSIX operating-system interface, and the Xlib client
library for the X~Window System.

@<Header files@>=
#include <stdio.h>      /* |printf|, |fprintf|, |snprintf|, |sscanf|, |fflush| */
#include <stdlib.h>     /* |exit| */
#include <string.h>     /* |memset|, |strlen|, |strcmp| */
#include <time.h>       /* |time|, |mktime|, |localtime|, |clock_gettime| */
#include <unistd.h>     /* POSIX symbolic constants */
#include <sys/select.h> /* |select|, |fd_set|, |FD_SET| */
#include <X11/Xlib.h>   /* the core Xlib client interface */
#include <X11/Xutil.h>  /* |XFontStruct| and window-manager hints */

@* Constants.
A handful of compile-time constants fix the default target instant, the
geometry of the window, and the X11 font we ask the server to load.  The
font \.{10x20} is a fixed-width bitmap font present on virtually every
X~server; if it is unavailable we fall back to the server default.

@d DEFAULT_TARGET "2026-08-19 08:00:00"  /* 19 August 2026, 8:00\thinspace AM */
@d WIN_W 520        /* window width in pixels */
@d WIN_H 220        /* window height in pixels */
@d FONT_NAME "10x20"  /* preferred fixed-width font */
@d TICK_USEC 250000   /* event-loop wake-up interval, microseconds */

@<Constants@>=
/* The constants above are expressed as preprocessor macros so that the
   tangled C~source carries no separate definitions module. */

@* The application state.
All mutable state lives in one |App| structure that is threaded through
the drawing and event-handling routines.  Keeping it in a single record
(rather than in file-scope globals) makes the data flow explicit and the
routines easy to test in isolation.

@<The application state |App|@>=
typedef struct {
  Display *dpy;        /* connection to the X~server */
  Window win;          /* our top-level window */
  GC gc;               /* graphics context for text */
  XFontStruct *font;   /* loaded font, or |NULL| */
  int screen;          /* default screen number */
  time_t target;       /* the instant we count down to */
  int running;         /* 1 while counting, 0 while paused or armed */
  int started;         /* 1 once the user has begun the countdown */
  long frozen;         /* remaining seconds captured at the last pause */
} App;

@* Parsing the target time.
The target is given as the calendar string \.{"YYYY-MM-DD HH:MM:SS"} in
{\it local\/} time.  We decompose it with |sscanf|, populate a |struct tm|,
and convert it to a |time_t| with the POSIX function |mktime|.  Setting
|tm_isdst| to $-1$ asks |mktime| to determine for itself whether daylight
saving time is in effect on that date.

@<Parse the target time@>=
static time_t parse_target(const char *s)
{
  struct tm tm;
  int yr, mo, dy, hr, mi, se;
  memset(&tm, 0, sizeof tm);
  if (sscanf(s, "%d-%d-%d %d:%d:%d",
             &yr, &mo, &dy, &hr, &mi, &se) != 6) {
    fprintf(stderr, "countdown: bad target \"%s\" "
                    "(want YYYY-MM-DD HH:MM:SS)\n", s);
    exit(2);
  }
  @<Fill the broken-down time and convert it@>@;
}

@ The fields of |struct tm| count years from 1900 and months from zero,
so we adjust accordingly before calling |mktime|.  A return value of
$(time_t)(-1)$ signals an unrepresentable date.

@<Fill the broken-down time and convert it@>=
{
  time_t t;
  tm.tm_year = yr - 1900;
  tm.tm_mon  = mo - 1;
  tm.tm_mday = dy;
  tm.tm_hour = hr;
  tm.tm_min  = mi;
  tm.tm_sec  = se;
  tm.tm_isdst = -1;            /* let |mktime| decide about DST */
  t = mktime(&tm);
  if (t == (time_t) -1) {
    fprintf(stderr, "countdown: target is not a valid date\n");
    exit(2);
  }
  return t;
}

@* Computing the remaining seconds.
The number of whole seconds still to run is the difference between the
target and the current instant, clamped at zero so the display never goes
negative.  We read the wall clock with the POSIX |time| call.

@<Compute the remaining seconds@>=
static long remaining_secs(time_t target)
{
  time_t now = time(NULL);
  double d = difftime(target, now);
  return d > 0.0 ? (long) d : 0L;
}

@* Formatting a duration.
A count of seconds is rendered as days plus a 24-hour clock.  The result
is written into a caller-supplied buffer with the bounds-checked
|snprintf|, so no overflow is possible regardless of the magnitude.

@<Format a duration@>=
static void fmt_duration(long secs, char *buf, size_t n)
{
  long d = secs / 86400;
  long r = secs % 86400;
  long h = r / 3600;
  long m = (r % 3600) / 60;
  long s = r % 60;
  snprintf(buf, n, "%ld d  %02ld:%02ld:%02ld", d, h, m, s);
}

@* Opening the display.
Connecting to the X~server is the first Xlib act.  |XOpenDisplay(NULL)|
honours the |DISPLAY| environment variable, which POSIX makes available
through |getenv| inside Xlib.  A null return means no server could be
reached, which is fatal.

@<Open the display@>=
static void open_display(App *a)
{
  a->dpy = XOpenDisplay(NULL);
  if (a->dpy == NULL) {
    fprintf(stderr, "countdown: cannot open X display "
                    "(is DISPLAY set and an X server running?)\n");
    exit(1);
  }
  a->screen = DefaultScreen(a->dpy);
}

@* Creating the window.
We ask for a simple top-level window with a white background and a thin
black border, give it a title for the window manager, and declare which
event categories we wish to receive: exposures (redraw requests), key and
button presses, and structure-change notifications (resizing).

@<Create the window@>=
static void create_window(App *a)
{
  unsigned long white = WhitePixel(a->dpy, a->screen);
  unsigned long black = BlackPixel(a->dpy, a->screen);
  a->win = XCreateSimpleWindow(a->dpy, RootWindow(a->dpy, a->screen),
                               0, 0, WIN_W, WIN_H, 2, black, white);
  XStoreName(a->dpy, a->win, "Countdown");
  XSelectInput(a->dpy, a->win,
               ExposureMask | KeyPressMask |
               ButtonPressMask | StructureNotifyMask);
  XMapWindow(a->dpy, a->win);
}

@* Creating the graphics context.
The graphics context (GC) holds the drawing attributes --- foreground
colour and font --- used by every text-drawing call.  We load the
preferred font and, if it is present, bind it to the GC; otherwise Xlib's
default font is used.

@<Create the graphics context@>=
static void create_gc(App *a)
{
  a->gc = XCreateGC(a->dpy, a->win, 0, NULL);
  XSetForeground(a->dpy, a->gc, BlackPixel(a->dpy, a->screen));
  a->font = XLoadQueryFont(a->dpy, FONT_NAME);
  if (a->font != NULL)
    XSetFont(a->dpy, a->gc, a->font->fid);
}

@* Rendering the display.
Each repaint clears the window, prints the target instant on the first
line, the remaining time in large digits on the second, and a status and
hint on the lower lines.  When the countdown has not yet started, or is
paused, the figure is taken from |frozen| rather than recomputed, so it
holds still.

@<Render the display@>=
static void render(App *a)
{
  static const char *hint = "[Space] or click: start/pause    [q]: quit";
  char hdr[80], big[48], status[64];
  long secs = (a->running) ? remaining_secs(a->target) : a->frozen;
  @<Build the header and status strings@>@;
  XClearWindow(a->dpy, a->win);
  XDrawString(a->dpy, a->win, a->gc, 24,  40, hdr, strlen(hdr));
  XDrawString(a->dpy, a->win, a->gc, 24, 110, big, strlen(big));
  XDrawString(a->dpy, a->win, a->gc, 24, 150, status, strlen(status));
  XDrawString(a->dpy, a->win, a->gc, 24, 195, hint, strlen(hint));
  XFlush(a->dpy);
}

@ The header restates the target in a human-readable form produced by
|localtime| and |strftime|.  The status line names the current phase and,
when the countdown has reached zero, announces that the moment has
arrived.

@<Build the header and status strings@>=
{
  struct tm *lt = localtime(&a->target);
  strftime(hdr, sizeof hdr, "Target: %a %d %b %Y  %H:%M:%S", lt);
  fmt_duration(secs, big, sizeof big);
  if (secs == 0 && a->started)
    snprintf(status, sizeof status, "Status: THE MOMENT HAS ARRIVED");
  else if (!a->started)
    snprintf(status, sizeof status, "Status: ready -- press Space to start");
  else
    snprintf(status, sizeof status, "Status: %s",
             a->running ? "running" : "paused");
}

@* Handling one X event.
The dispatcher reacts to the four event categories we subscribed to.  An
|Expose| or |ConfigureNotify| simply triggers a repaint.  A key press of
\.{q} or \.{Escape} requests quit (by returning 0); the space bar toggles
the run state.  A mouse click anywhere also toggles the run state.  Any
other event leaves the loop running.

@<Handle one X event@>=
static int handle_event(App *a, XEvent *ev)
{
  switch (ev->type) {
  case Expose: case ConfigureNotify:
    render(a);
    break;
  case KeyPress:
    @<React to a key press@>@;
    break;
  case ButtonPress:
    toggle_run(a);
    render(a);
    break;
  }
  return 1;                     /* keep looping */
}

@ A key press is decoded to a |KeySym|.  We treat \.{q} and the escape key
as quit requests, and the space bar as the run/pause toggle.

@<React to a key press@>=
{
  KeySym k = XLookupKeysym(&ev->xkey, 0);
  if (k == XK_q || k == XK_Escape)
    return 0;                   /* signal the caller to quit */
  if (k == XK_space) {
    toggle_run(a);
    render(a);
  }
}

@ Toggling the run state has three cases.  Starting for the first time
arms the countdown and marks it started.  Pausing captures the current
remaining seconds into |frozen| so the display holds.  Resuming simply
sets |running| again.

@<Compute the remaining seconds@>+=
static void toggle_run(App *a)
{
  if (!a->started) {
    a->started = 1;
    a->running = 1;
  } else if (a->running) {
    a->frozen = remaining_secs(a->target);
    a->running = 0;
  } else {
    a->running = 1;
  }
}

@* The event-and-timer loop.
A countdown must both react to user input {\it and\/} tick forward on its
own.  Pure |XNextEvent| would block until the next event, so the clock
would freeze whenever the user sat still.  Instead we multiplex the X
connection's file descriptor against a timer using the POSIX |select|
call: |select| returns either when an event is readable or when the
timeout lapses, and in the latter case we repaint to advance the clock.

@<The event-and-timer loop@>=
static void run_loop(App *a)
{
  int xfd = ConnectionNumber(a->dpy);
  for (;;) {
    @<Drain all pending X events; quit if asked@>@;
    @<Wait up to one tick for the next event@>@;
    if (a->running) render(a);
  }
}

@ Before sleeping we must process every event already queued, because
|select| reports readability only for bytes still in the socket, not for
events Xlib has already buffered.  |XPending| reports the buffered count.

@<Drain all pending X events; quit if asked@>=
while (XPending(a->dpy) > 0) {
  XEvent ev;
  XNextEvent(a->dpy, &ev);
  if (!handle_event(a, &ev)) {
    @<Tear down and exit cleanly@>@;
  }
}

@ The timeout is rebuilt on every iteration because |select| may modify
the |timeval| it is given.  A quarter-second tick keeps the seconds digit
visually crisp without busy-waiting.  An interruption by a signal
(|EINTR|) is harmless: the loop simply comes round again.

@<Wait up to one tick for the next event@>=
{
  fd_set rfds;
  struct timeval tv;
  FD_ZERO(&rfds);
  FD_SET(xfd, &rfds);
  tv.tv_sec = 0;
  tv.tv_usec = TICK_USEC;
  select(xfd + 1, &rfds, NULL, NULL, &tv);
}

@ Quitting releases the resources we acquired, in the reverse order of
acquisition, then leaves the program.

@<Tear down and exit cleanly@>=
{
  if (a->font) XFreeFont(a->dpy, a->font);
  XFreeGC(a->dpy, a->gc);
  XDestroyWindow(a->dpy, a->win);
  XCloseDisplay(a->dpy);
  exit(0);
}

@* Running in the terminal.
When the program is invoked without \.{-gui} it counts down in the
controlling terminal instead of opening a window.  This is the default
mode: it needs no X~server and is convenient over a plain login shell or
in a script.  The same |remaining_secs| and |fmt_duration| routines feed a
single line that is rewritten in place once per second with a carriage
return, so the terminal shows a steadily ticking figure without scrolling.

@<Run the countdown in the terminal@>=
static void run_terminal(App *a)
{
  char hdr[80], big[48];
  struct tm *lt = localtime(&a->target);
  strftime(hdr, sizeof hdr, "Target: %a %d %b %Y  %H:%M:%S", lt);
  printf("%s\n", hdr);
  @<Loop until the terminal countdown arrives@>@;
}

@ Each pass recomputes the remaining seconds, reprints the figure over the
previous one, and sleeps a tick.  The loop ends once the target is reached;
a final newline leaves the cursor on a fresh line.  |fflush| forces each
update out, since standard output to a terminal is line-buffered and the
carriage-return updates carry no newline.

@<Loop until the terminal countdown arrives@>=
for (;;) {
  long secs = remaining_secs(a->target);
  fmt_duration(secs, big, sizeof big);
  printf("\rRemaining: %s   ", big);
  fflush(stdout);
  if (secs == 0) break;
  @<Sleep one tick in the terminal@>@;
}
printf("\rRemaining: %s   -- THE MOMENT HAS ARRIVED\n", big);

@ The terminal loop has no file descriptor to watch, so it simply sleeps a
tick with |select| and a null descriptor set --- the same POSIX call used
by the GUI loop, here serving only as a portable sub-second sleep.

@<Sleep one tick in the terminal@>=
{
  struct timeval tv;
  tv.tv_sec = 0;
  tv.tv_usec = TICK_USEC;
  select(0, NULL, NULL, NULL, &tv);
}

@* The main function.
|main| selects the target (command-line argument or default), decides
between terminal and GUI mode from the \.{-gui} option, initialises the
|App| record, and dispatches accordingly.

@<The |main| function@>=
int main(int argc, char **argv)
{
  App a;
  int gui = 0;
  const char *spec = DEFAULT_TARGET;
  @<Scan the command-line arguments@>@;
  memset(&a, 0, sizeof a);
  a.target = parse_target(spec);
  a.frozen = remaining_secs(a.target);
  if (gui) { @<Start the GUI and run@>@; }
  else run_terminal(&a);
  return 0;
}

@ The option \.{-gui} selects the windowed mode; any other non-option
argument is taken as the target specification.  Scanning the arguments in
a small loop keeps the option and the optional target independent of their
order on the command line.

@<Scan the command-line arguments@>=
{
  int i;
  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-gui") == 0)
      gui = 1;
    else
      spec = argv[i];
  }
}

@ The startup sequence opens the server connection, creates the window
and its graphics context, draws the initial frame, and hands control to
the loop, which never returns normally.

@<Start the GUI and run@>=
{
  open_display(&a);
  create_window(&a);
  create_gc(&a);
  render(&a);
  run_loop(&a);
}

@* POSIX system services.
This program rests on a small, deliberately chosen set of POSIX operating
system services.  They are gathered and explained here, and each is also
entered in the index under the heading {\it system call}, so that a reader
auditing the program's interaction with the operating system can find
every one of them from a single place.

@ |time(2)| --- {\it get the current calendar time.}
@^system call: \.{time}@>
|time(NULL)| returns the number of seconds since the Unix epoch
(1970-01-01T00:00:00\thinspace UTC) as a |time_t|.  We use it in
|remaining_secs| to learn how far the present is from the target.  It
cannot fail when given a null argument on a conforming system.

@ |mktime(3)| --- {\it convert broken-down local time to |time_t|.}
@^system call: \.{mktime}@>
Given a |struct tm| expressed in local time, |mktime| returns the
corresponding |time_t|, normalising out-of-range fields and consulting the
|TZ| timezone database to apply the correct UTC offset and daylight-saving
rule.  We call it once, in |parse_target|, to turn the user's calendar
string into an absolute instant.

@ |localtime(3)| --- {\it convert |time_t| to broken-down local time.}
@^system call: \.{localtime}@>
|localtime| is the inverse of |mktime|: it explodes a |time_t| into a
|struct tm| in the local zone, which |strftime| then formats for the
header line.  The returned pointer addresses a static buffer that may be
overwritten by later calls; we consume it immediately.

@ |select(2)| --- {\it synchronous I/O multiplexing with a timeout.}
@^system call: \.{select}@>
|select| watches a set of file descriptors and returns when one becomes
ready or when a timeout expires.  We watch the single descriptor returned
by |ConnectionNumber| (the socket to the X~server) with a quarter-second
timeout, so the program wakes either to service user input or to advance
the clock --- never busy-waiting, never sleeping through an event.  The
|fd_set| is populated with the POSIX macros |FD_ZERO| and |FD_SET|.
@^system call: \.{FD\_ZERO}@>
@^system call: \.{FD\_SET}@>

@ |getenv(3)| --- {\it look up an environment variable.}
@^system call: \.{getenv}@>
We do not call |getenv| directly, but Xlib calls it on our behalf inside
|XOpenDisplay| to read the |DISPLAY| variable, which names the X~server to
contact.  It is documented here for completeness because it governs which
display the program attaches to.

@* Index.
The cross-reference index is generated automatically by \.{cweave}.
Identifiers appear in {\it italic}, named sections by the module in which
they are defined, and the POSIX system services under the heading
{\it system call} as described above.
