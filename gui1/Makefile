CTANGLE  = ctangle
CWEAVE   = cweave
PDFTEX   = pdftex
PROGRAM  = hello-x11
SOURCE   = hello-x11.w
C_SRC    = hello-x11.c
TEX_SRC  = hello-x11.tex
PDF_DOC  = hello-x11.pdf

CC       = cc

# X11 headers and libraries.  On Linux they are typically on the default
# include/library path; on macOS XQuartz installs them under /opt/X11.
X11_PREFIX ?= $(shell test -d /opt/X11 && echo /opt/X11 || echo /usr)
X11_CFLAGS  = -I$(X11_PREFIX)/include
X11_LDFLAGS = -L$(X11_PREFIX)/lib -lX11

CFLAGS   = -O2 -Wall $(X11_CFLAGS)
LDFLAGS  = $(X11_LDFLAGS)

.PHONY: all tangle weave compile pdf clean run

all: tangle compile pdf

# Extract C source from the CWEB literate source
tangle: $(C_SRC)

$(C_SRC): $(SOURCE)
	$(CTANGLE) $(SOURCE)

# Generate TeX documentation from the CWEB literate source
weave: $(TEX_SRC)

$(TEX_SRC): $(SOURCE)
	$(CWEAVE) $(SOURCE)

# Compile the tangled C source into an executable
compile: $(PROGRAM)

$(PROGRAM): $(C_SRC)
	$(CC) $(CFLAGS) -o $(PROGRAM) $(C_SRC) $(LDFLAGS)

# Typeset the woven TeX into a PDF
pdf: $(PDF_DOC)

$(PDF_DOC): $(TEX_SRC)
	$(PDFTEX) $(TEX_SRC)

# Run the compiled program
run: $(PROGRAM)
	./$(PROGRAM)

clean:
	rm -f $(C_SRC) $(TEX_SRC) $(PDF_DOC) $(PROGRAM) *.idx *.scn *.log *.toc
