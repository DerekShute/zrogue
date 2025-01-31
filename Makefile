#
# Makefile layer for simplification
#

ALL_ZIG := $(wildcard src/*.zig)

all: visualize.svg

#
# Looks for the following comment style
#
# // DOT level_Place -> Thing [label="refers"]
#
visualize.dot: $(ALL_ZIG)
	echo "digraph {" > $@
	cat $^ | grep "DOT" | cut --complement -c 1,2,3,4,5,6 | sort -u >> $@
	echo "}" >> $@

visualize.svg : visualize.dot
	dot -Tsvg $< -o $@

clean:
	$(RM) *.dot *.svg


.PHONY: clean
# EOF
