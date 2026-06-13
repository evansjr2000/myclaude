# Makefile for the countdown literate program.
#
# The literate source of record is countdown.w.  C source and typeset
# documentation are build artefacts extracted from it by the CWEB tools,
# which are driven through the cweb.sh helper script (per project policy).
#
#   make tangle    -> countdown.c        (ctangle)
#   make weave     -> countdown.tex      (cweave)
#   make compile   -> countdown          (cc + Xlib)
#   make pdf       -> countdown.pdf       (pdftex on the woven .tex)
#   make all       -> tangle + compile
#   make run       -> build and launch the GUI
#   make clean     -> remove build artefacts

# CWEB is driven through the project cweb.sh helper (which runs ctangle /
# cweave in a container) per project policy.  CTANGLE and CWEAVE name the
# full tangle/weave commands; they can be overridden on the make command
# line to use a local CWEB installation, e.g.
#     make tangle CTANGLE=ctangle
CWEB     ?= ../../curlswim/cweb.sh
CTANGLE  ?= $(CWEB) ctangle
CWEAVE   ?= $(CWEB) cweave

PROGRAM   = countdown
SOURCE    = countdown.w
C_SRC     = countdown.c
TEX_SRC   = countdown.tex

CC        = cc

# X11 (Xlib).  On macOS, XQuartz installs headers and libraries under
# /opt/X11; on Linux they are normally on the default search paths.
# Override X11_PREFIX on the command line for non-standard locations.
X11_PREFIX ?= $(shell test -d /opt/X11 && echo /opt/X11 || echo /usr)
X11_CFLAGS  = -I$(X11_PREFIX)/include
X11_LDFLAGS = -L$(X11_PREFIX)/lib -lX11

CFLAGS    = -O2 -Wall -std=c99 $(X11_CFLAGS)
LDFLAGS   = $(X11_LDFLAGS)

.PHONY: all tangle weave compile pdf run clean

all: tangle compile

# Extract C source from the CWEB literate source.
tangle: $(C_SRC)
$(C_SRC): $(SOURCE)
	$(CTANGLE) $(SOURCE)

# Generate TeX documentation from the CWEB literate source.
weave: $(TEX_SRC)
$(TEX_SRC): $(SOURCE)
	$(CWEAVE) $(SOURCE)

# Compile the tangled C source into an executable.
compile: $(PROGRAM)
$(PROGRAM): $(C_SRC)
	$(CC) $(CFLAGS) -o $(PROGRAM) $(C_SRC) $(LDFLAGS)

# Typeset the program documentation as a PDF.
pdf: $(TEX_SRC)
	pdftex $(TEX_SRC)

# Build and run the GUI.
run: $(PROGRAM)
	./$(PROGRAM)

clean:
	rm -f $(C_SRC) $(TEX_SRC) $(PROGRAM) *.idx *.scn *.toc *.log *.aux
