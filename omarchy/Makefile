CFLAGS ?= -O2 -Wall -Wextra
PKGS = sdl3 glesv2 freetype2

shadermix: src/shadermix.c
	$(CC) $(CFLAGS) $(shell pkg-config --cflags $(PKGS)) -o $@ $< $(shell pkg-config --libs $(PKGS)) -lm

clean:
	rm -f shadermix

.PHONY: clean
