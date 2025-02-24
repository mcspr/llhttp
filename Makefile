CC ?= xtensa-lx106-elf-gcc
CFLAGS ?=
OS ?=

CFLAGS += -Os -g -Wall -Wextra -Wno-unused-parameter
CFLAGS += -free -fipa-pta -mlongcalls -mtext-section-literals -falign-functions=4 -ffunction-sections -fdata-sections -nostdlib

INCLUDES += -Ibuild/

INSTALL ?= install
PREFIX ?= /usr/local
LIBDIR = $(PREFIX)/lib
INCLUDEDIR = $(PREFIX)/include

OBJS := build/c/llhttp.c.o build/native/api.c.o build/native/http.c.o

all: build/libllhttp.a build/libllhttp.so

clean:
	rm -rf release/
	rm -rf build/

build/libllhttp.so: $(OBJS)
	$(CC) -shared $^ -o $@

build/libllhttp.a: $(OBJS)
	$(AR) rcs $@ $^

build/c/%.c.o: build/c/%.c build/llhttp.h
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

build/native/%.c.o: src/native/%.c build/llhttp.h src/native/api.h \
		build/native
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

build/llhttp.h: generate
build/c/llhttp.c: generate

build/native:
	mkdir -p build/native

release: clean generate
	@echo "${RELEASE}" | grep -q -E ".+" || { echo "Please make sure the RELEASE argument is set."; exit 1; }
	rm -rf release
	mkdir -p release/src
	mkdir -p release/include
	cp -rf build/llhttp.h release/include/
	cp -rf build/c/llhttp.c release/src/
	cp -rf src/native/*.c release/src/
	cp -rf src/llhttp.gyp release/
	cp -rf src/common.gypi release/
	cp -rf CMakeLists.txt release/
	sed -i s/_RELEASE_/$(RELEASE)/ release/CMakeLists.txt
	cp -rf libllhttp.pc.in release/
	cp -rf README.md release/
	cp -rf LICENSE-MIT release/

github-release:
	@echo "${RELEASE_V}" | grep -q -E "^v" || { echo "Please make sure version starts with \"v\"."; exit 1; }
	gh release create -d --generate-notes ${RELEASE_V}
	@sleep 5
	gh release view ${RELEASE_V} -t "{{.body}}" --json body > RELEASE_NOTES
	gh release delete ${RELEASE_V} -y
	gh release create -F RELEASE_NOTES -d --title ${RELEASE_V} --target release release/${RELEASE_V}
	@sleep 5
	rm -rf RELEASE_NOTES
	open $$(gh release view release/${RELEASE_V} --json url -t "{{.url}}")

postversion: release	
	git fetch origin
	git push
	git checkout release --
	cp -rf release/* ./
	rm -rf release
	git add include src *.gyp *.gypi CMakeLists.txt README.md LICENSE-MIT libllhttp.pc.in
	git commit -a -m "release: $(RELEASE)"
	git tag "release/v$(RELEASE)"
	git push && git push --tags
	git checkout main

generate:
	bash apply-patch.sh
	npx ts-node bin/generate.ts

install: build/libllhttp.a build/libllhttp.so
	$(INSTALL) -d $(DESTDIR)$(INCLUDEDIR)
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL) -C build/llhttp.h $(DESTDIR)$(INCLUDEDIR)/llhttp.h
	$(INSTALL) -C build/libllhttp.a $(DESTDIR)$(LIBDIR)/libllhttp.a
	$(INSTALL) build/libllhttp.so $(DESTDIR)$(LIBDIR)/libllhttp.so

.PHONY: all generate clean release postversion github-release
