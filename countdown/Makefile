# Makefile for the countdown literate program.
#
# countdown.w is the literate source of record.  The C source, the typeset
# program listing, and the IEEE document set are all build artefacts that
# are (re)generated from the literate source and the hand-written .tex
# specifications.
#
#   make all        -> tangle + compile   (default)
#   make tangle     -> countdown.c         (ctangle, in container)
#   make weave      -> countdown.tex       (cweave, in container)
#   make compile    -> countdown           (cc + Xlib)
#   make run        -> build and launch the terminal countdown (default)
#   make run-gui    -> build and launch the GUI countdown (-gui)
#   make pdf        -> countdown.pdf        (woven program, in container)
#   make docs       -> countdown.pdf + the four IEEE PDFs (in container)
#   make install    -> install countdown into /usr/local/bin
#   make uninstall  -> remove countdown from /usr/local/bin
#   make clean      -> remove all intermediate build files
#   make distclean  -> clean + remove the generated PDFs
#
# Every step that touches the container first runs docker-check.sh, which
# verifies the Docker daemon is up and starts Docker Desktop if it is not.

# --- CWEB / container tooling -------------------------------------------
# CWEB is driven through the project cweb.sh helper, which runs ctangle and
# cweave inside the evansjr/cweb container.  CTANGLE/CWEAVE can be
# overridden on the command line to use a local CWEB install, e.g.
#     make all CTANGLE=ctangle CWEAVE=cweave DOCKER_CHECK=true
# A plain "=" (not "?=") is required: GNU make predefines CTANGLE and
# CWEAVE as built-in defaults, so "?=" would leave them as bare ctangle /
# cweave and silently bypass the container.
CWEB        ?= cweb.sh
CTANGLE      = $(CWEB) ctangle
CWEAVE       = $(CWEB) cweave

# docker-check.sh (in ~/bin, on PATH) ensures the Docker daemon is running,
# starting Docker Desktop if necessary.  Override with DOCKER_CHECK=true to
# disable it (e.g. when using a local, non-containerised toolchain).
DOCKER_CHECK ?= docker-check.sh

# The TeX toolchain runs inside the same container image that cweb.sh uses,
# so the documentation is typeset without a local TeX installation.
CWEB_IMAGE  ?= evansjr/cweb:latest
DOCKER_RUN   = docker run --rm -v "$(CURDIR):/work" -w /work $(CWEB_IMAGE)

PROGRAM   = countdown
SOURCE    = countdown.w
C_SRC     = countdown.c
TEX_SRC   = countdown.tex
PROG_PDF  = countdown.pdf

# Hand-written IEEE / ISO document set and the PDFs woven from them.
IEEE_TEX  = countdown-conops.tex countdown-srs.tex countdown-sdd.tex countdown-stp.tex
IEEE_PDF  = $(IEEE_TEX:.tex=.pdf)

CC        = cc

# X11 (Xlib).  On macOS, XQuartz installs headers and libraries under
# /opt/X11; on Linux they are normally on the default search paths.
# Override X11_PREFIX on the command line for non-standard locations.
X11_PREFIX ?= $(shell test -d /opt/X11 && echo /opt/X11 || echo /usr)
X11_CFLAGS  = -I$(X11_PREFIX)/include
X11_LDFLAGS = -L$(X11_PREFIX)/lib -lX11

CFLAGS    = -O2 -Wall -std=c99 $(X11_CFLAGS)
LDFLAGS   = $(X11_LDFLAGS)

# Installation location for the final executable (requirement 6).
PREFIX    ?= /usr/local
BINDIR     = $(PREFIX)/bin

.PHONY: all tangle weave compile pdf docs run run-gui install uninstall \
        clean distclean docker-check

all: tangle compile

# Verify the Docker daemon is up (and start it if not) before any
# container-driven step.
docker-check:
	$(DOCKER_CHECK)

# Extract C source from the CWEB literate source.
tangle: $(C_SRC)
$(C_SRC): $(SOURCE)
	$(DOCKER_CHECK)
	$(CTANGLE) $(SOURCE)

# Generate TeX documentation from the CWEB literate source.
weave: $(TEX_SRC)
$(TEX_SRC): $(SOURCE)
	$(DOCKER_CHECK)
	$(CWEAVE) $(SOURCE)

# Compile the tangled C source into an executable.
compile: $(PROGRAM)
$(PROGRAM): $(C_SRC)
	$(CC) $(CFLAGS) -o $(PROGRAM) $(C_SRC) $(LDFLAGS)

# Typeset the literate program listing as a PDF, inside the container.
pdf: $(PROG_PDF)
$(PROG_PDF): $(TEX_SRC)
	$(DOCKER_CHECK)
	$(DOCKER_RUN) -c "pdftex $(TEX_SRC)"

# Typeset the IEEE / ISO document set inside the container.  pdflatex is run
# twice so the table of contents and cross-references resolve.
$(IEEE_PDF): %.pdf: %.tex
	$(DOCKER_CHECK)
	$(DOCKER_RUN) -c "pdflatex -interaction=nonstopmode $< && pdflatex -interaction=nonstopmode $<"

# Build every document: the woven program listing and the IEEE set.
docs: $(PROG_PDF) $(IEEE_PDF)

# Build and run the terminal countdown (the default mode).
run: $(PROGRAM)
	./$(PROGRAM)

# Build and run the GUI countdown (the -gui option).
run-gui: $(PROGRAM)
	./$(PROGRAM) -gui

# Install the final executable into $(BINDIR) (default /usr/local/bin).
# Use "sudo make install" if that directory is not writable.
install: $(PROGRAM)
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 755 $(PROGRAM) "$(DESTDIR)$(BINDIR)/$(PROGRAM)"
	@echo "Installed $(PROGRAM) -> $(DESTDIR)$(BINDIR)/$(PROGRAM)"

uninstall:
	rm -f "$(DESTDIR)$(BINDIR)/$(PROGRAM)"

# Remove all intermediate build files: the tangled C source, the woven
# program .tex, the executable, and the TeX/CWEB auxiliary files.  The
# hand-written IEEE .tex sources and the generated PDFs are kept.
clean:
	rm -f $(C_SRC) $(TEX_SRC) $(PROGRAM) \
	      *.idx *.scn *.toc *.log *.aux *.out texput.log

# Also remove the generated PDFs (the IEEE .tex sources are preserved).
distclean: clean
	rm -f $(PROG_PDF) $(IEEE_PDF)
