DB=db
INCLUDE=-package batteries,zarith -I $(DB)
MARCH?=x86_64

OCAMLC = ocamlfind c $(INCLUDE) -g -annot
OCAMLOPT = ocamlfind opt $(INCLUDE) -g -annot
OCAMLMKLIB = ocamlfind mklib $(INCLUDE)
OCAMLDEP = ocamlfind dep -slash

CCOPTS = $(addprefix -ccopt ,-Wall -std=c11 -D__USE_MINGW_ANSI_STDIO)
CCLIBS = 


ifeq ($(OS),Windows_NT)
    # On cygwin + cygwinports, DLLs are searched in the PATH, which is not
    # altered to include by default the mingw64 native DLLs. We also need to
    # find dllcorecrypto.dll; it is in the current directory, which Windows
    # always uses to search for DLLs.
    EXTRA_PATH = PATH="/usr/$(MARCH)-w64-mingw32/sys-root/mingw/bin/:$(PATH)"
    ARCH = win32
    EXTRA_OPTS =
    EXTRA_LIBS = -L.
    ifeq ($(MARCH),x86_64)
      OPENSSL_CONF = CC=x86_64-w64-mingw32-gcc ./Configure mingw64 enable-tls1_3
    else
      OPENSSL_CONF = CC=i686-w64-mingw32-gcc ./Configure mingw enable-tls1_3
    endif
else
    # On Unix-like systems, the library search path is LD_LIBRARY_PATH, which is
    # correctly setup to find libssleay.so and the like, but never includes the
    # current directory, which is where dllcorecrypto.so is located.
    EXTRA_PATH = LD_LIBRARY_PATH=.
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
        EXTRA_OPTS =
        EXTRA_LIBS = -L.
        ARCH = osx
        OPENSSL_CONF = ./config enable-tls1_3
    else
        EXTRA_OPTS = -thread -ccopt -fPIC
        EXTRA_LIBS = -L.
        ARCH = x86_64
	# The HACL* test engine directly links with the .o files
        OPENSSL_CONF = ./config enable-tls1_3 -fPIC
    endif
endif

.PHONY: test dep

# JP 20180913: CoreCrypto is gone, in favor of EverCrypt... for the purposes of
# the Everest build, the only reason why we want to keep this repository is to
# have a working build of OpenSSL
# all: # CoreCrypto.cmxa CoreCrypto.cma

ifdef NO_OPENSSL
all:
else
all: openssl/libcrypto.a
endif

%.cmi: %.mli
	$(OCAMLC) -c $<

%.cmo: %.ml
	$(OCAMLC) -c $<

%.cmx: %.ml
	$(OCAMLOPT) -c $<

$(DB)/DB.cmx: $(DB)/DB.ml
	$(MAKE) -C $(DB)


ifdef NO_OPENSSL

CCOPTS += $(addprefix -ccopt ,-DNO_OPENSSL)

openssl_stub.o: openssl_stub.c
	$(OCAMLOPT) $(CCOPTS) $(EXTRA_OPTS) $? -o $@

else

CCOPTS += $(addprefix -ccopt ,-Lopenssl -Iopenssl/include)
CCLIBS += $(addprefix -cclib ,-lcrypto)

openssl_stub.o: libcrypto.a openssl_stub.c
	$(OCAMLOPT) $(CCOPTS) $(EXTRA_OPTS) -c openssl_stub.c

openssl/Configure:
	echo "openssl folder is empty, running git submodule update... no recursion"
	git submodule update --init

openssl/libcrypto.a: openssl/Configure
	cd openssl && $(OPENSSL_CONF) && $(MAKE) build_libs

libcrypto.a: openssl/libcrypto.a
	cp openssl/libcrypto.a .

endif # NO_OPENSSL


DLL_OBJ = CryptoTypes.cmx CoreCrypto.cmx openssl_stub.o
CoreCrypto.cmxa: $(DLL_OBJ)
	$(OCAMLMKLIB) $(EXTRA_LIBS) $(CCLIBS) -o CoreCrypto $(DLL_OBJ)

DLL_BYTE = CryptoTypes.cmo CoreCrypto.cmo openssl_stub.o
CoreCrypto.cma: $(DLL_BYTE)
	$(OCAMLMKLIB) $(EXTRA_LIBS) $(CCLIBS) -o CoreCrypto $^

TEST_CMX = Tests.cmx
Tests.exe: CoreCrypto.cmxa $(TEST_CMX)
	$(OCAMLOPT) $(EXTRA_OPTS) -linkpkg -o $@ \
	CoreCrypto.cmxa $(TEST_CMX)

test: Tests.exe
	@$(EXTRA_PATH) ./Tests.exe

clean:
	$(MAKE) -C $(DB) clean
ifdef PLATFORM
	$(MAKE) -C $(PLATFORM) clean
endif
	rm -f Tests.exe *.[oa] *.so *.cm[ixoa] *.cmxa *.exe *.dll *.annot *~

.depend:
	$(OCAMLDEP) -I $(DB) *.ml *.mli > .depend

include .depend

valgrind: Tests$(EXE)
	valgrind --leak-check=yes --suppressions=suppressions ./Tests$(EXE)
