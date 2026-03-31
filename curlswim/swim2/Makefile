CWEB     = ../cweb.sh
PROGRAM  = stella-times
SOURCE   = stella-times.w
C_SRC    = stella-times.c
TEX_SRC  = stella-times.tex

CC       = cc
CFLAGS   = -O2 -Wall
LDFLAGS  = $(shell curl-config --libs 2>/dev/null || echo "-lcurl")

.PHONY: all tangle weave compile clean run

all: tangle compile

# Extract C source from the CWEB literate source
tangle: $(C_SRC)

$(C_SRC): $(SOURCE)
	$(CWEB) ctangle $(SOURCE)

# Generate TeX documentation from the CWEB literate source
weave: $(TEX_SRC)

$(TEX_SRC): $(SOURCE)
	$(CWEB) cweave $(SOURCE)

# Compile the tangled C source into an executable
compile: $(PROGRAM)

$(PROGRAM): $(C_SRC)
	$(CC) $(CFLAGS) -o $(PROGRAM) $(C_SRC) $(LDFLAGS)

# Run the compiled program
run: $(PROGRAM)
	./$(PROGRAM)

clean:
	rm -f $(C_SRC) $(TEX_SRC) $(PROGRAM) *.idx *.scn *.log *.toc
