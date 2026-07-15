# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This project maintains a swim times report for two College Area Swim Team (CAST) swimmers. It generates a landscape PDF with each swimmer's best short course yard (SCY) times alongside motivational performance standards and age-group championship qualifying times.

## Swimmers

- **Kalea Benavente** — 13–14 Girls age group
- **Stella Julianna Evans** — 10 & Under Girls age group

## Workflow

1. Look up swimmer times at https://data.usaswimming.org/datahub/usas/individualsearch — always fetch live, never guess. Do **not** use Swimcloud (https://www.swimcloud.com/) — it has errors.
2. Update `swim/swim-times.md` with new times, dates, and meet names.
3. Generate output from the `swim/` directory:

```bash
# Generate PDF (landscape via pdflscape LaTeX package in the YAML header)
pandoc swim-times.md -o swim-times.pdf --pdf-engine=xelatex

# Generate HTML
pandoc swim-times.md -o swim-times.html
```

## Data Sources

- **Swimmer times**: USA Swimming data hub (URL above) — live lookup required
- **Motivational standards (B, BB, A)**: `swim/motivational-time-standards.pdf` — do not look up online
- **SDI Age Group Championships qualifying times**: `swim/sdi-agc-time-standards.pdf` — do not look up online

## Document Structure

`swim/swim-times.md` uses a pandoc Markdown YAML front matter block (landscape PDF, LaTeX packages) followed by two swimmer sections. Each section has a table with columns:

`Event | Best Time | Date | Meet | Mot. B | Mot. BB | Mot. A | SDI AGC Qual.`

`swim/swim-times.tex` is an equivalent direct LaTeX implementation using landscape geometry and CAST blue (RGB: 0,48,135).

## Automation (`swim2/`)

`swim2/` holds `swim-times`, a CWEB literate program (`swim-times.w`) that uses `libcurl` to fetch each swimmer's best times directly from the USA Swimming public REST times service at `https://times-api.usaswimming.org/swims/TimesSearch`. It resolves a swimmer's `memberId` via `GetMembersForFilters`, then fetches best times per event via `GetBestTimesForMember`. Authentication is anonymous — no bearer token — using three headers (`Usas-Sub-Id: Anonymous`, `AppName: DataHub`, and a run-time-generated `Device-Id`).

> **Note:** the anonymous feed returns a best time per event but **no swim date or meet**; those require an authenticated USA Swimming session and are left empty by the program (see `swim2/swim-times-data-gap.pdf`). The **motivational standard** is *not* in the feed either, so the program computes it locally: the official standards are loaded into a `motivational_standard` Postgres table (`schema.sql` + `motivational-standards.sql`, generated from the PDF by `tools/parse-motivational.py`), and each best time is classified by gender (from the roster) and age group (from the live member search). If Postgres is unreachable, the standard column is simply left blank.

To (re)load the standards table:

```bash
cd swim2
../../pg/pg.sh psql -d swim-times < schema.sql                 # creates tables
../../pg/pg.sh psql -d swim-times < motivational-standards.sql  # seeds standards
# regenerate the seed from a new PDF edition:
python3 tools/parse-motivational.py /path/to/motivational-time-standards.pdf > motivational-standards.sql
```

Build and test:

```bash
cd swim2
make            # ctangle + compile -> ./swim-times
make weave      # cweave -> swim-times.tex (then pdftex for the PDF)
./test-swim-times.sh   # automated SRS conformance tests
```

IEEE-style documentation lives alongside the source: `swim-times-conops.tex` (ConOps), `swim-times-srs.tex` (SRS), `swim-times-sdd.tex` (SDD), and `swim-times-stp.tex` (test plan), each with a matching `.pdf`. An optional local Postgres database (`store`/`offline` keywords, `schema.sql`, `pg.sh`) persists and replays results.
