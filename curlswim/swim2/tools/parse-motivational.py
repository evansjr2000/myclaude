#!/usr/bin/env python3
"""Generate motivational-standards.sql from the USA Swimming motivational
time-standards PDF.

Usage:
    python3 tools/parse-motivational.py path/to/motivational-time-standards.pdf \
        > motivational-standards.sql

Requires `pdftotext` (poppler) on PATH.  Emits one row per
(gender, age_group, event, standard) with the cut time in seconds, ready
to load into the `motivational_standard` table defined in schema.sql.

The PDF lays each age group out as:
    B  BB  A  AA  AAA  AAAA   <EVENT>   AAAA  AAA  AA  A  BB  B
with Girls cuts on the left (slow->fast) and Boys on the right
(fast->slow).  Relay events (marked -R) are skipped; the swim-times
program queries individual events only.
"""
import re, sys, subprocess

AGE_MAP = {'10 & under': '10&U', '11-12': '11-12', '13-14': '13-14',
           '15-16': '15-16', '17-18': '17-18'}
GIRL_LEVELS = ['B', 'BB', 'A', 'AA', 'AAA', 'AAAA']
BOY_LEVELS  = ['AAAA', 'AAA', 'AA', 'A', 'BB', 'B']
TIME_RE  = re.compile(r'\d+(?::\d+)*\.\d+\s*\*?')
LABEL_RE = re.compile(r'\b(\d+)\s+([A-Z]{2,3}(?:-R)?)\s+(SCY|SCM|LCM)\b')
AGE_RE   = re.compile(r'(10 & under|11-12|13-14|15-16|17-18)\s+Girls')


def to_seconds(t):
    sec = 0.0
    for part in t.replace('*', '').strip().split(':'):
        sec = sec * 60 + float(part)
    return round(sec, 2)


def parse(text):
    cur_age, rows = None, []
    for line in text.splitlines():
        m = AGE_RE.search(line)
        if m:
            cur_age = AGE_MAP[m.group(1)]
            continue
        lm = LABEL_RE.search(line)
        if not lm or '-R' in lm.group(2) or cur_age is None:
            continue
        times = TIME_RE.findall(line)
        if len(times) != 12:
            continue
        event = f"{lm.group(1)} {lm.group(2)} {lm.group(3)}"
        girls = {lvl: to_seconds(v) for lvl, v in zip(GIRL_LEVELS, times[0:6])}
        boys  = {lvl: to_seconds(v) for lvl, v in zip(BOY_LEVELS,  times[6:12])}
        rows.append(('F', cur_age, event, girls))
        rows.append(('M', cur_age, event, boys))
    return rows


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    text = subprocess.check_output(['pdftotext', '-layout', sys.argv[1], '-'],
                                   text=True)
    rows = parse(text)
    print("-- motivational-standards.sql --- GENERATED, do not hand-edit.")
    print("-- Source: USA Swimming 2024-2028 Motivational Standards PDF.")
    print("-- Regenerate: python3 tools/parse-motivational.py <pdf> > this file")
    print("TRUNCATE motivational_standard;")
    n = 0
    for gender, age, event, cuts in rows:
        for lvl in GIRL_LEVELS:
            if lvl in cuts:
                print("INSERT INTO motivational_standard "
                      "(gender,age_group,event,standard,cut_seconds) VALUES "
                      f"('{gender}','{age}','{event}','{lvl}',{cuts[lvl]});")
                n += 1
    sys.stderr.write(f"{n} rows for {len(rows)} (gender,age,event) groups\n")


if __name__ == '__main__':
    main()
