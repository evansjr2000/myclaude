#!/usr/bin/env bash
# test-countdown.sh
# Automated test harness for the countdown program, exercising the
# requirements defined in CD-SRS-001 (countdown-srs.tex) per the test
# cases of CD-STP-001 (countdown-stp.tex).
#
# Usage:  ./test-countdown.sh
#
# Each automated test case prints one line of the form
#   PASS REQ-X-NN  short description
#   FAIL REQ-X-NN  short description
#   SKIP REQ-X-NN  reason
#
# Exit status: 0 if no case FAILed, 1 otherwise.  A SKIP (absent
# precondition) does not fail the run.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$HERE/countdown.w"
CSRC="$HERE/countdown.c"
BIN="$HERE/countdown"
BUILD_LOG=/tmp/countdown-build.log

PASS=0; FAIL=0; SKIP=0
pass() { printf 'PASS %-10s %s\n' "$1" "$2"; PASS=$((PASS+1)); }
fail() { printf 'FAIL %-10s %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
skip() { printf 'SKIP %-10s %s\n' "$1" "$2"; SKIP=$((SKIP+1)); }
section() { printf '\n=== %s ===\n' "$1"; }

# -----------------------------------------------------------------
# TC-01 / REQ-B-01, REQ-D-04 : tangle + compile via make
# -----------------------------------------------------------------
section "Build (TC-01, TC-02, TC-03)"

if [ ! -f "$SOURCE" ]; then
    fail BUILD "countdown.w not found at $SOURCE"; exit 1
fi

# Force a fresh tangle so REQ-D-04 (regenerable C) is genuinely exercised.
rm -f "$CSRC" "$BIN"
( cd "$HERE" && make tangle compile ) >"$BUILD_LOG" 2>&1
build_rc=$?

if [ $build_rc -eq 0 ] && [ -x "$BIN" ] && [ -f "$CSRC" ]; then
    pass REQ-B-01 "make tangle compile produced $BIN from countdown.w"
    pass REQ-D-04 "countdown.c regenerated from countdown.w by ctangle"
else
    fail REQ-B-01 "make tangle compile failed (see $BUILD_LOG)"
    fail REQ-D-04 "countdown.c not regenerable / executable absent"
fi

# -----------------------------------------------------------------
# TC-02 / REQ-D-05 : clean compile under -Wall
# -----------------------------------------------------------------
if grep -q "warning:" "$BUILD_LOG" 2>/dev/null; then
    fail REQ-D-05 "compile produced warnings under -Wall"
else
    pass REQ-D-05 "compile clean under -O2 -Wall"
fi

# -----------------------------------------------------------------
# TC-03 / REQ-B-02 : links against Xlib, no toolkit
# -----------------------------------------------------------------
if grep -Eq -- "-lX11" "$HERE/Makefile" && \
   ! grep -Eqi -- "-l(gtk|qt|Xt|Xm|motif|fltk)" "$HERE/Makefile"; then
    pass REQ-B-02 "links -lX11 only, no widget toolkit"
else
    fail REQ-B-02 "unexpected toolkit dependency in Makefile"
fi

# -----------------------------------------------------------------
# Static checks on the literate source
# -----------------------------------------------------------------
section "Literate-program constraints (TC-04, TC-05, TC-06)"

# TC-04 / REQ-D-01 : CWEB markers and literate-programming prose present
if grep -q '^@\*' "$SOURCE" && grep -q '@>=' "$SOURCE" && \
   grep -qi 'literate program' "$SOURCE"; then
    pass REQ-D-01 "countdown.w is a CWEB literate program"
else
    fail REQ-D-01 "CWEB markers or literate-programming prose missing"
fi

# TC-05 / REQ-D-02 : no code section exceeds 23 lines of code
MAXLINES=$(python3 - "$SOURCE" <<'PY'
import sys
lines = open(sys.argv[1]).read().split('\n')
incode = False; count = 0; mx = 0
for l in lines:
    s = l.rstrip()
    starts_code  = (l.startswith('@<') and s.endswith('@>=')) or s == '@c'
    starts_prose = l.startswith('@*') or l.startswith('@ ') or s == '@'
    if starts_code:
        if incode and count > mx: mx = count
        incode = True; count = 0
    elif starts_prose:
        if incode and count > mx: mx = count
        incode = False; count = 0
    elif incode and l.strip():
        count += 1
if incode and count > mx: mx = count
print(mx)
PY
)
if [ "${MAXLINES:-99}" -lt 24 ]; then
    pass REQ-D-02 "largest code section is $MAXLINES lines (< 24)"
else
    fail REQ-D-02 "a code section has $MAXLINES lines (>= 24)"
fi

# TC-06 / REQ-D-03 : POSIX section + indexed system calls
posix_ok=1
grep -q 'POSIX system services' "$SOURCE" || posix_ok=0
for sc in time mktime localtime select; do
    grep -q "system call: .*$sc" "$SOURCE" || posix_ok=0
done
if [ $posix_ok -eq 1 ]; then
    pass REQ-D-03 "POSIX section present; system calls indexed"
else
    fail REQ-D-03 "POSIX section or system-call index entries missing"
fi

# -----------------------------------------------------------------
# Functional static + dynamic checks
# -----------------------------------------------------------------
section "Functional requirements (TC-07..TC-13)"

# TC-07 / REQ-F-02 : default target macro
if grep -Eq 'DEFAULT_TARGET[[:space:]]+"2026-08-19 08:00:00"' "$SOURCE"; then
    pass REQ-F-02 "default target is 2026-08-19 08:00:00"
else
    fail REQ-F-02 "default target macro is not 2026-08-19 08:00:00"
fi

# TC-08 / REQ-F-03 : argv target accepted
if grep -q 'argc > 1' "$SOURCE" && grep -q 'argv\[1\]' "$SOURCE"; then
    pass REQ-F-03 "target accepted from argv[1]"
else
    fail REQ-F-03 "command-line target handling not found"
fi

# TC-09 / REQ-F-04 : malformed target -> diagnostic + exit 2, no window
if [ -x "$BIN" ]; then
    DIAG=$( DISPLAY= "$BIN" "not-a-date" 2>&1 1>/dev/null ); rc=$?
    if [ $rc -eq 2 ] && printf '%s' "$DIAG" | grep -qi 'YYYY-MM-DD'; then
        pass REQ-F-04 "malformed target -> exit 2 with diagnostic, no window"
    else
        fail REQ-F-04 "malformed target gave rc=$rc, diag='$DIAG'"
    fi
else
    skip REQ-F-04 "executable not built"
fi

# TC-10 / REQ-F-05 : d HH:MM:SS format with zero-padding
if grep -q '%ld d  %02ld:%02ld:%02ld' "$SOURCE"; then
    pass REQ-F-05 "remaining time formatted as d HH:MM:SS (zero-padded)"
else
    fail REQ-F-05 "duration format string not found"
fi

# TC-11 / REQ-F-06 : remaining time clamped at zero
if grep -q 'd > 0.0 ? (long) d : 0L' "$SOURCE"; then
    pass REQ-F-06 "remaining_secs clamps a past target to zero"
else
    fail REQ-F-06 "zero-clamp not found in remaining_secs"
fi

# TC-12 / REQ-T-02, REQ-T-03 : time() and mktime(isdst=-1)
if grep -q 'time(NULL)' "$SOURCE"; then
    pass REQ-T-02 "remaining time computed from time()"
else
    fail REQ-T-02 "time() not used for current time"
fi
if grep -q 'tm_isdst = -1' "$SOURCE" && grep -q 'mktime(&tm)' "$SOURCE"; then
    pass REQ-T-03 "target converted with mktime honouring DST (isdst=-1)"
else
    fail REQ-T-03 "mktime/DST handling not found"
fi

# TC-13 / REQ-T-04 : select-based loop, no busy-wait
if grep -q 'select(xfd + 1' "$SOURCE"; then
    pass REQ-T-04 "event loop blocks on select (no busy-wait)"
else
    fail REQ-T-04 "select-based wait not found"
fi

# -----------------------------------------------------------------
# GUI requirements: smoke-tested live if a display is available,
# otherwise recorded as manual (CD-STP-001 Section 8).
# -----------------------------------------------------------------
section "GUI requirements (manual / smoke)"

if [ -x "$BIN" ] && [ -n "${DISPLAY:-}" ]; then
    # Brief launch-and-kill smoke test: the program should stay up.
    "$BIN" "2026-08-19 08:00:00" &
    pid=$!
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
        pass REQ-G-01 "window opened and stayed up on \$DISPLAY"
    else
        fail REQ-G-01 "program exited prematurely on \$DISPLAY"
    fi
else
    skip REQ-G-01 "no \$DISPLAY; GUI cases are manual (see CD-STP-001 Sec 8)"
fi
skip REQ-G-02 "manual: target/remaining/status/hint shown (MC-01)"
skip REQ-G-03 "manual: space/click start-pause (MC-03)"
skip REQ-G-04 "manual: q/Escape quits (MC-04)"
skip REQ-G-05 "manual: repaint on expose/resize (MC-05)"
skip REQ-F-07 "manual: arrival message at zero (MC-06)"

# -----------------------------------------------------------------
# Summary
# -----------------------------------------------------------------
section "Summary"
printf 'PASS=%d  FAIL=%d  SKIP=%d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
