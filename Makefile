CC ?= cc
CFLAGS ?= -O2 -g -Wall -Wextra -Werror
LDLIBS ?= -lutil
.PHONY: all check clean

all: exploit.static

exploit.static: exploit.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=gnu11 -pthread $(LDFLAGS) \
		-static -o $@ $< $(LDLIBS)

check:
	$(CC) $(CPPFLAGS) $(CFLAGS) -std=gnu11 -pthread -fsyntax-only exploit.c

clean:
	rm -f exploit.static
