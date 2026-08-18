# Metanorma standoc document models — unified build.
#
# One Makefile for the whole monorepo. Per-flavour phony targets exist for
# CI parallelism: `make bipm`, or `make all` for everything.

# Single source of truth for the flavour list — also read by deploy.yml
# and the metanorma/ci path-filter job.
FLAVORS := $(shell cat flavors.txt)

.PHONY: all clean verify $(FLAVORS)

all: $(FLAVORS)

# generate every flavour's diagrams
define FLAVOR_RULES
$(1): $(1)-images
.PHONY: $(1)-images
$(1)-images: $$(patsubst $(1)/models/%.lml,$(1)/images/%.png,$$(wildcard $(1)/models/*.lml))
$(1)/images/%.png: $(1)/models/%.lml
	@mkdir -p $(1)/images
	lutaml-lml generate $$< -o $$@ -t png
endef
$(foreach f,$(FLAVORS),$(eval $(call FLAVOR_RULES,$(f))))

# Defensive content-type check: lutaml writes Graphviz dot source into .png
# paths when misflagged; assert PNG magic bytes (metanorma/ci#302/#303).
# Skipped on Windows: git-bash file(1) misreports Windows-Graphviz output
# ("data"), so the gate would be false-red there.
ifeq ($(OS),Windows_NT)
verify:
	@echo "verify: skipped on Windows"
else
verify:
	@count=0; bad=0; \
	for f in $(FLAVORS); do \
	  for p in $$f/images/*.png; do \
	    [ -e "$$p" ] || continue; \
	    count=$$((count+1)); \
	    if ! file -b "$$p" | grep -q "^PNG image data"; then \
	      echo "ERROR: $$p is not a valid PNG ($$(file -b $$p))" >&2; \
	      bad=$$((bad+1)); \
	    fi; \
	  done; \
	done; \
	if [ $$bad -gt 0 ]; then echo "verify: $$bad of $$count PNG(s) invalid" >&2; exit 1; fi; \
	echo "verify: $$count PNG file(s) OK"
endif

clean:
	rm -f $(FLAVORS:%=%/images/*.png)
