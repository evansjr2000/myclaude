# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ATANGLE is an Ada WEB (AWEB) processor that extracts Ada source code from literate programming files. It is an Ada adaptation of Knuth's TANGLE from the WEB system, converted by U. Schweigert in 1988 based on TANGLE Version 2.8.

The program reads `.aweb` files (literate programming documents combining documentation and code) and produces Ada source files.

## Build Commands

```bash
# Compile from the generated Ada source files
gnatmake atangle.adb

# Or compile individual units first
gnatmake -c data_structures.ads
gnatmake -c input_output.ads
gnatmake -c hashing.ads
gnatmake -c input_phase.ads
gnatmake -c output_phase.ads
gnatmake atangle.adb
```

## Processing AWEB Files

The canonical source is `atangle.aweb`. Running atangle on it produces `.a` files which need to be split into GNAT-compatible naming:

```bash
# Run atangle to produce web_output.a and other .a files
./atangle atangle.aweb [changefile]

# Split into GNAT naming convention (produces files in src/)
gnatchop -v *.a src/
```

## Architecture

### Package Structure

- **atangle.adb** - Main program entry point; handles command-line arguments, file opening, and orchestrates Phase I (input) and Phase II (output)
- **data_structures** - Global constants, types, variables, and core data structures (byte memory, token memory, name tables, hash tables)
- **input_output** - File I/O operations and error handling (`OPEN_A_FILE`, `CREATE_ADA_FILE`, `INPUT_LN`, `ERROR`)
- **hashing** - Identifier and module name lookup (`ID_LOOKUP`, `MOD_LOOKUP`, `PREFIX_LOOKUP`)
- **input_phase** - Phase I processing; reads AWEB input, handles change files, tokenizes code (`PHASE_I`)
- **output_phase** - Phase II processing; expands macros and module references, produces Ada output (`PHASE_II`)
- **int_number_io** - Integer I/O instantiation for TEXT_IO.INTEGER_IO

### Two-Phase Processing

1. **Phase I (Input Phase)**: Reads the AWEB file and optional change file, stores code fragments in compressed form in token memory, builds symbol tables for identifiers and module names
2. **Phase II (Output Phase)**: Expands all macros and module references recursively, outputs the final Ada source code

### Key Data Structures

- `BYTE_MEM` - Stores identifier names and strings (partitioned into WW=2 segments)
- `TOK_MEM` - Stores compressed Ada code tokens (partitioned into ZZ=3 segments)
- `BYTE_START`, `TOK_START` - Index arrays pointing into memory
- `HASH`, `CHOP_HASH` - Hash tables for identifier lookup
- `LINK`, `ILK`, `EQUIV` - Name table fields (linking, type classification, equivalence)
- `TEXT_LINK` - Links continuation texts for modules

### Change File Support

ATANGLE supports change files (`.ach`) using `@x`/`@y`/`@z` directives to patch the source without modifying the original AWEB file.

## Usage

```bash
./atangle input.aweb              # Process AWEB file
./atangle input.aweb changes.ach  # Process with change file
```

Output is written to `web_output.a` and any files specified by `@~filename@>` directives in the AWEB source.
