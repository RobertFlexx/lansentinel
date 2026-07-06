PONYC ?= ponyc

.PHONY: build clean

build:
	$(PONYC) src -o . --bin-name lansentinel

clean:
	rm -f lansentinel
