#
# Makefile layer for simplification
#

ALL_ZIG := $(wildcard src/*.zig)

all: visual

visual:
	mkdir -p zig-out
	zig build visual 2>zig-out/visual.yml
	python3 tools/visual.py > zig-out/visual.dot
	dot -Tsvg zig-out/visual.dot -o zig-out/visual.svg

clean:
	$(RM) *.dot *.svg

.PHONY: clean visual
# EOF
