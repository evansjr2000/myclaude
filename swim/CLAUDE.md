# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This project maintains a swim times report for two College Area Swim Team (CAST) swimmers. It generates a PDF (landscape) with each swimmer's best short course yard (SCY) times alongside motivational and qualifying standards.

## Workflow

1. Look up swimmer times at https://data.usaswimming.org/datahub/usas/individualsearch
2. Update `swim-times.md` with new times, dates, and meet names
3. Generate output:

```bash
# Generate PDF (landscape via pdflscape LaTeX package in the YAML header)
pandoc swim-times.md -o swim-times.pdf --pdf-engine=xelatex

# Generate HTML
pandoc swim-times.md -o swim-times.html
```

# Generate TeX

## Data Sources

- **Swimmer times**: USA Swimming data hub or Swimcloud — always fetch live, do not guess
- **Motivational standards (B, BB, A)**: `motivational-time-standards.pdf` in this directory — do not look up online
- **SDI Age Group Championships qualifying times**: `sdi-agc-time-standards.pdf` in this directory — do not look up online

## swim-times.md Structure

The file uses a pandoc Markdown YAML front matter block (landscape PDF, LaTeX packages) followed by two swimmer sections. Each section has a table with columns: Event | Best Time | Date | Meet | Mot. B | Mot. BB | Mot. A | SDI AGC Qual.

- **Kalea Benavente** — 13–14 Girls age group
- **Stella Julianna Evans** — 10 & Under Girls age group

