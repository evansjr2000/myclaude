#!/usr/bin/env bash
# run-stp.sh
# Runs the tests outlined in the Software Test Plan, CD-STP-001
# (countdown-stp.tex), for the countdown program.
#
# It selects an available CWEB toolchain, invokes the automated test
# harness (test-countdown.sh), and then prints the manual test checklist
# from the STP for an operator to confirm at a live X display.
#
# Usage:  ./run-stp.sh
#
# Exit status mirrors the automated harness: 0 if no automated case
# FAILed, 1 otherwise.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==================================================================="
echo " Software Test Plan runner  --  CD-STP-001  --  countdown"
echo "==================================================================="

# -----------------------------------------------------------------
# Choose a CWEB toolchain for the build the harness performs.
# Policy is to use the containerised cweb.sh; if Docker is unavailable
# but a local ctangle/cweave is installed, fall back to it so the plan
# can still be executed (e.g. in CI).
# -----------------------------------------------------------------
MAKE_ARGS=()
if docker info >/dev/null 2>&1; then
    echo "[env] Docker available: using cweb.sh container toolchain."
elif command -v ctangle >/dev/null 2>&1 && command -v cweave >/dev/null 2>&1; then
    echo "[env] Docker unavailable: falling back to local ctangle/cweave."
    MAKE_ARGS=(CTANGLE=ctangle CWEAVE=cweave)
    export CTANGLE=ctangle CWEAVE=cweave
else
    echo "[env] WARNING: no Docker and no local CWEB; build cases may fail."
fi

# Export so the harness's own 'make' inherits the same choice.
if [ "${#MAKE_ARGS[@]}" -gt 0 ]; then
    export MAKEFLAGS="${MAKE_ARGS[*]}"
fi

# -----------------------------------------------------------------
# Run the automated harness.
# -----------------------------------------------------------------
echo
echo "------------------- Automated test cases --------------------------"
"$HERE/test-countdown.sh"
rc=$?

# -----------------------------------------------------------------
# Print the manual checklist (CD-STP-001 Section 8).
# -----------------------------------------------------------------
cat <<'EOF'

------------------- Manual test checklist -------------------------
Perform these at a live X display (Linux/X11 or macOS/XQuartz).
Mark each [ ] -> [P]ass or [F]ail.

  [ ] MC-01 (REQ-G-01/02): `./countdown -gui` opens a window showing the
            target, remaining time, status line, and control hint.
  [ ] MC-02 (REQ-F-01/T-01): `./countdown -gui` with no target counts
            toward 2026-08-19 08:00:00, the seconds advancing once per second.
  [ ] MC-03 (REQ-G-03): Space or a mouse click toggles running/paused;
            the figure freezes while paused.
  [ ] MC-04 (REQ-G-04): `q` or Escape closes the window (exit 0).
  [ ] MC-05 (REQ-G-05): resizing / re-exposing repaints correctly.
  [ ] MC-06 (REQ-F-07): with `-gui` and a target a few seconds ahead,
            arrival shows "THE MOMENT HAS ARRIVED" and reads 0 d 00:00:00.
  [ ] MC-07 (REQ-F-08): `./countdown` with no `-gui` counts down in the
            terminal (no window), updating the line in place once a second.

EOF

echo "-------------------------------------------------------------------"
if [ $rc -eq 0 ]; then
    echo "Automated result: PASS (no failures).  Complete the manual"
    echo "checklist above to finish the CD-STP-001 campaign."
else
    echo "Automated result: FAIL.  See the case lines above."
fi
echo "-------------------------------------------------------------------"
exit $rc
