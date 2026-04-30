#!/usr/bin/env bash
# AWEB toolchain test harness.
# Implements the cases enumerated in SOFTWARE_TEST_PLAN.tex (AWEB-STP-2.1).
#
# Usage:
#   tests/test_aweb.sh              # run from the repository root
#   awebpg.sh test                  # run inside the awebpg container
#
# Exit status: 0 if every non-skipped case passes; 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"
LOG="$TESTS_DIR/test_aweb.log"
WORK="$TESTS_DIR/work"

mkdir -p "$WORK"
: > "$LOG"

pass=0
fail=0
skip=0

note()  { printf '%s\n'   "$*" | tee -a "$LOG"; }
ok()    { pass=$((pass+1)); printf 'PASS  %-6s  %s\n' "$1" "$2" | tee -a "$LOG"; }
ko()    { fail=$((fail+1)); printf 'FAIL  %-6s  %s\n' "$1" "$2" | tee -a "$LOG"; }
sk()    { skip=$((skip+1)); printf 'SKIP  %-6s  %s\n' "$1" "$2" | tee -a "$LOG"; }

# ---------------------------------------------------------------------------
# Environment detection.  Two modes:
#   * "container"  -- running inside the awebpg image; pre-installed
#                     binaries live under /usr/local/bin and the
#                     docker-of-docker cases (TC-010..TC-014) are
#                     meaningless and are skipped.
#   * "host"       -- the default; build atangle/aweave with gnatmake
#                     when available, and exercise the container cases
#                     against the local Docker daemon.
# ---------------------------------------------------------------------------
IN_CONTAINER=0
if [[ -f /.dockerenv ]] \
   || [[ -x /usr/local/bin/atangle && -x /usr/local/bin/aweave ]]; then
    IN_CONTAINER=1
fi

note "Test environment: $([[ $IN_CONTAINER -eq 1 ]] && echo container || echo host)"

# ---------------------------------------------------------------------------
# TC-001 / TC-002 -- build atangle and aweave
# ---------------------------------------------------------------------------
build_one() {
    local id="$1" subdir="$2" main="$3"
    if ! command -v gnatmake >/dev/null 2>&1; then
        sk "$id" "gnatmake not on PATH; cannot build $subdir"
        return 2
    fi
    ( cd "$REPO_ROOT/$subdir" && gnatmake -q "$main" -o "${main%.adb}" ) \
        >>"$LOG" 2>&1
    if [[ -x "$REPO_ROOT/$subdir/${main%.adb}" ]]; then
        ok "$id" "built $subdir/${main%.adb}"
        return 0
    fi
    ko "$id" "build of $subdir/${main%.adb} failed (see log)"
    return 1
}

build_one TC-001 atangle atangle.adb
build_one TC-002 aweave  aweave.adb

# Pick the runtime binaries:
#   1. freshly built ones in the source tree, if present;
#   2. otherwise the container-installed ones at /usr/local/bin.
ATANGLE="$REPO_ROOT/atangle/atangle"
AWEAVE="$REPO_ROOT/aweave/aweave"

runnable() {
    [[ -x "$1" ]] && "$1" </dev/null >/dev/null 2>&1
    local rc=$?
    [[ $rc -ne 126 && $rc -ne 127 ]]
}
if ! runnable "$ATANGLE" && [[ -x /usr/local/bin/atangle ]]; then
    ATANGLE="/usr/local/bin/atangle"
fi
if ! runnable "$AWEAVE" && [[ -x /usr/local/bin/aweave ]]; then
    AWEAVE="/usr/local/bin/aweave"
fi
runnable "$ATANGLE" || ATANGLE="$REPO_ROOT/atangle/atangle.notbuilt"
runnable "$AWEAVE"  || AWEAVE="$REPO_ROOT/aweave/aweave.notbuilt"

# ---------------------------------------------------------------------------
# TC-003 / TC-004 -- banner / version reporting
# ---------------------------------------------------------------------------
banner_check() {
    local id="$1" prog="$2" needle="$3" fixture="$4"
    if [[ ! -x "$prog" ]]; then
        sk "$id" "executable $(basename "$prog") not built (gnatmake required)"
        return
    fi
    # The banner is emitted on its own line, but the program also prints
    # "Trying to open input file." and similar diagnostics on adjacent
    # lines.  Scan the first dozen lines of output for the needle.
    local out hit
    out=$( cd "$WORK" && "$prog" "$fixture" 2>&1 | head -n 12 )
    if printf '%s\n' "$out" | grep -qF -- "$needle"; then
        hit=$( printf '%s\n' "$out" | grep -F -- "$needle" | head -n 1 )
        ok "$id" "banner: $hit"
    else
        ko "$id" "expected banner containing '$needle'; got first lines: '$out'"
    fi
}

cp "$TESTS_DIR/fixtures/ada83.aweb" "$WORK/"
cp "$TESTS_DIR/fixtures/ada95.aweb" "$WORK/"

banner_check TC-003 "$ATANGLE" \
    "This is ATANGLE, Version 2.1 (Ada 95)"               "ada83.aweb"
banner_check TC-004 "$AWEAVE"  \
    "This is AWEAVE, Version 2.1 (Ada 95 keyword support)" "ada83.aweb"

# ---------------------------------------------------------------------------
# TC-005 / TC-006 -- tangle Ada 83 and Ada 95 fixtures
# ---------------------------------------------------------------------------
tangle_one() {
    local id="$1" fixture="$2" outname="$3"
    if [[ ! -x "$ATANGLE" ]]; then
        sk "$id" "atangle not built (gnatmake required for native cases)"
        return
    fi
    rm -f "$WORK"/*.a "$WORK/web_output.a"
    ( cd "$WORK" && "$ATANGLE" "$fixture" ) >>"$LOG" 2>&1
    local produced
    produced=$( ls "$WORK"/*.a 2>/dev/null | head -n 1 )
    if [[ -z "$produced" ]]; then
        ko "$id" "atangle produced no .a file from $fixture"
        return
    fi
    cp "$produced" "$WORK/$outname"
    ok "$id" "tangled $fixture -> $outname"
}

tangle_one TC-005 "ada83.aweb" "ada83.a"
tangle_one TC-006 "ada95.aweb" "ada95.a"

# ---------------------------------------------------------------------------
# TC-007 / TC-008 -- weave and inspect TeX output
# ---------------------------------------------------------------------------
run_weave_into() {
    # $1 = path-out variable name, $2 = fixture
    local __outvar="$1" fixture="$2"
    rm -f "$WORK"/*.tex
    ( cd "$WORK" && "$AWEAVE" "$fixture" ) >>"$LOG" 2>&1
    local produced
    produced=$( ls "$WORK"/*.tex 2>/dev/null | head -n 1 )
    printf -v "$__outvar" '%s' "$produced"
}

if [[ ! -x "$AWEAVE" ]]; then
    sk TC-007 "aweave not built (gnatmake required)"
    sk TC-008 "aweave not built (gnatmake required)"
else
    TEX83=""
    run_weave_into TEX83 "ada83.aweb"
    if [[ -n "$TEX83" && -f "$TEX83" ]]; then
        if grep -q '\\&{begin}' "$TEX83" && grep -q '\\&{end}' "$TEX83"; then
            ok TC-007 "Ada 83 weave: \\&{begin} and \\&{end} present"
        else
            ko TC-007 "Ada 83 weave: \\&{begin} or \\&{end} missing in $TEX83"
        fi
    else
        ko TC-007 "aweave produced no .tex file from ada83.aweb"
    fi

    TEX95=""
    run_weave_into TEX95 "ada95.aweb"
    if [[ -n "$TEX95" && -f "$TEX95" ]]; then
        missing=()
        for kw in abstract aliased protected requeue tagged until; do
            if ! grep -q "\\\\&{$kw}" "$TEX95"; then
                missing+=("$kw")
            fi
        done
        if [[ ${#missing[@]} -eq 0 ]]; then
            ok TC-008 "Ada 95 weave: all six new keywords classified as reserved"
        else
            ko TC-008 "Ada 95 weave: keyword(s) not classified: ${missing[*]}"
        fi
    else
        ko TC-008 "aweave produced no .tex file from ada95.aweb"
    fi
fi

# ---------------------------------------------------------------------------
# TC-009 -- round-trip / idempotence of tangling
# ---------------------------------------------------------------------------
if [[ -x "$ATANGLE" ]]; then
    rt_dir="$WORK/roundtrip"
    rm -rf "$rt_dir"; mkdir -p "$rt_dir/run1" "$rt_dir/run2"
    cp "$TESTS_DIR/fixtures/ada95.aweb" "$rt_dir/run1/ada95.aweb"
    cp "$TESTS_DIR/fixtures/ada95.aweb" "$rt_dir/run2/ada95.aweb"
    ( cd "$rt_dir/run1" && "$ATANGLE" ada95.aweb ) >>"$LOG" 2>&1
    ( cd "$rt_dir/run2" && "$ATANGLE" ada95.aweb ) >>"$LOG" 2>&1
    first=$(  ls "$rt_dir/run1"/*.a 2>/dev/null | head -n 1 )
    second=$( ls "$rt_dir/run2"/*.a 2>/dev/null | head -n 1 )
    if [[ -n "$first" && -n "$second" ]] \
       && diff -q "$first" "$second" >/dev/null; then
        ok TC-009 "atangle is idempotent on ada95 fixture"
    else
        ko TC-009 "atangle not idempotent ($first vs $second differ)"
    fi
else
    sk TC-009 "atangle not built"
fi

# ---------------------------------------------------------------------------
# TC-015 / TC-016 -- version-flag (-v / --version) command-line option.
# The flag must print the banner and exit cleanly without trying to open
# any input file, and without producing any .a or .tex output.
# ---------------------------------------------------------------------------
version_flag_check() {
    local id="$1" prog="$2" flag="$3" needle="$4" workdir="$5"
    if [[ ! -x "$prog" ]]; then
        sk "$id" "$(basename "$prog") not built (gnatmake required)"
        return
    fi
    rm -rf "$workdir"; mkdir -p "$workdir"
    local out rc
    out=$( cd "$workdir" && "$prog" "$flag" 2>&1 )
    rc=$?
    if [[ $rc -ne 0 ]]; then
        ko "$id" "$flag exited non-zero ($rc); output: $out"
        return
    fi
    if ! printf '%s\n' "$out" | grep -qF -- "$needle"; then
        ko "$id" "$flag did not print banner '$needle'; got: $out"
        return
    fi
    # The flag must be side-effect-free: no .a or .tex artefacts.
    local stray
    stray=$( ls "$workdir"/*.a "$workdir"/*.tex 2>/dev/null )
    if [[ -n "$stray" ]]; then
        ko "$id" "$flag left behind artefacts: $stray"
        return
    fi
    ok "$id" "$flag prints banner and exits cleanly"
}

version_flag_check TC-015 "$ATANGLE" "-v" \
    "This is ATANGLE, Version 2.1 (Ada 95)" "$WORK/v_atangle"
version_flag_check TC-016 "$AWEAVE"  "--version" \
    "This is AWEAVE, Version 2.1 (Ada 95 keyword support)" "$WORK/v_aweave"

# ---------------------------------------------------------------------------
# TC-010 / TC-011 / TC-013 / TC-014 -- container cases.
# (TC-012 was the PostgreSQL persistence case; withdrawn in release 2.1
# when PostgreSQL was removed from the image per requirement 10.)
# Skipped wholesale when running inside the container (we don't run
# docker-in-docker) or when the local Docker daemon is unreachable.
# ---------------------------------------------------------------------------
docker_ok=1
if [[ $IN_CONTAINER -eq 1 ]]; then
    docker_ok=0
elif ! command -v docker >/dev/null 2>&1; then
    docker_ok=0
elif ! docker info >/dev/null 2>&1; then
    docker_ok=0
fi

if [[ $docker_ok -eq 0 ]]; then
    reason="docker daemon unavailable"
    [[ $IN_CONTAINER -eq 1 ]] && reason="running inside container; nested docker not used"
    sk TC-010 "$reason"
    sk TC-011 "$reason"
    sk TC-013 "$reason"
    sk TC-014 "$reason"
else
    if docker build -t evansjr/awebpg:2.1 "$REPO_ROOT" >>"$LOG" 2>&1; then
        ok TC-010 "container image built (evansjr/awebpg:2.1)"

        if docker run --rm --entrypoint /bin/bash evansjr/awebpg:2.1 \
              -c 'command -v make && command -v file && command -v emacs' \
              >>"$LOG" 2>&1; then
            ok TC-011 "container provides make, file, emacs"
        else
            ko TC-011 "container is missing make/file/emacs"
        fi

        # TC-012 (PostgreSQL persistence) was withdrawn when PostgreSQL
        # was removed from the image in release 2.1 per requirement 10.

        if docker run --rm -v "$WORK:/work" \
                evansjr/awebpg:2.1 \
                /bin/bash -c "atangle ada95.aweb" >>"$LOG" 2>&1; then
            ok TC-013 "awebpg.sh-style atangle dispatch inside container"
        else
            ko TC-013 "in-container atangle dispatch failed"
        fi

        # End-to-end keyword verification using the in-container aweave.
        rm -f "$WORK"/*.tex
        if docker run --rm -v "$WORK:/work" \
                evansjr/awebpg:2.1 \
                /bin/bash -c "aweave ada95.aweb" >>"$LOG" 2>&1; then
            tex=$( ls "$WORK"/*.tex 2>/dev/null | head -n 1 )
            if [[ -n "$tex" ]]; then
                missing=()
                for kw in abstract aliased protected requeue tagged until; do
                    if ! grep -q "\\\\&{$kw}" "$tex"; then
                        missing+=("$kw")
                    fi
                done
                if [[ ${#missing[@]} -eq 0 ]]; then
                    ok TC-014 "in-container aweave classifies all six Ada 95 keywords as reserved"
                else
                    ko TC-014 "in-container aweave: missing classification for ${missing[*]}"
                fi
            else
                ko TC-014 "in-container aweave produced no .tex"
            fi
        else
            ko TC-014 "in-container aweave failed to run"
        fi
    else
        ko TC-010 "docker build failed"
        sk TC-011 "container not built"
        sk TC-013 "container not built"
        sk TC-014 "container not built"
    fi
fi

# ---------------------------------------------------------------------------
note ""
note "Summary: $pass passed, $fail failed, $skip skipped."
[[ $fail -eq 0 ]]
