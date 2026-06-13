# countdown

A literate-program X Window countdown timer. Given a fixed future instant
— by default **2026-08-19 08:00:00** local time — it opens a window and
displays the time remaining (days and `HH:MM:SS`), updating live. Start,
pause, and resume with the **space bar** or a **mouse click**; quit with
**q** or **Escape**.

```
./countdown                       # count down to the default 2026-08-19 08:00
./countdown "2026-12-31 23:59:59" # count down to a custom instant
```

## Source of record

The program is written in Donald Knuth's literate-programming style as a
single CWEB document, **`countdown.w`**. Every other source file is a build
artefact regenerable from it. Each woven module is under 24 lines of code,
and the POSIX system calls (`time`, `mktime`, `localtime`, `select`,
`getenv`) are documented in their own section and entered in the index.

## Building

The build is driven by the `Makefile` through the project `cweb.sh` helper
(containerised CWEB). To use a locally installed CWEB instead, override the
tangle/weave commands.

```bash
make tangle        # ctangle countdown.w -> countdown.c
make compile       # cc + Xlib          -> countdown
make weave pdf     # cweave + pdftex     -> countdown.pdf (typeset program)
make run           # build and launch the GUI

# local CWEB fallback (no Docker):
make all CTANGLE=ctangle
```

X11 headers/libraries are taken from `/opt/X11` on macOS (XQuartz) or the
default paths on Linux; override `X11_PREFIX` for other locations.

## Documentation (IEEE standards, Parnas–Clements rational process)

| File | Document | Standard |
|------|----------|----------|
| `countdown-conops.tex` | Concept of Operations | IEEE Std 1362-1998 |
| `countdown-srs.tex`    | Software Requirements Specification | IEEE Std 830-1998 |
| `countdown-sdd.tex`    | Software Design Document | IEEE Std 1016-2009 |
| `countdown-stp.tex`    | Software Test Plan | ISO/IEC/IEEE 29119-3 |

Build any with `pdflatex <file>` (run twice for the table of contents).

## Testing

```bash
./run-stp.sh           # run the full Software Test Plan (CD-STP-001)
./test-countdown.sh    # just the automated harness
```

`test-countdown.sh` verifies the SRS requirements: it tangles and compiles
the program, checks the literate-program constraints (module size, POSIX
section and index), the default target, command-line and error handling,
the time/format logic, and the `select`-based loop. GUI requirements are
smoke-tested when a display is present and otherwise listed as the manual
checklist that `run-stp.sh` prints.
