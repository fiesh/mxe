# This file is part of MXE. See LICENSE.md for licensing information.

PKG             := boost
$(PKG)_WEBSITE  := https://www.boost.org/
$(PKG)_DESCR    := Boost C++ Library
$(PKG)_IGNORE   :=
$(PKG)_VERSION  := 1.72.0
$(PKG)_CHECKSUM := 59c9b274bc451cf91a9ba1dd2c7fdcaf5d60b1b3aa83f2c9fa143417cc660722
$(PKG)_SUBDIR   := boost_$(subst .,_,$($(PKG)_VERSION))
$(PKG)_FILE     := boost_$(subst .,_,$($(PKG)_VERSION)).tar.bz2
$(PKG)_URL      := https://$(SOURCEFORGE_MIRROR)/project/boost/boost/$($(PKG)_VERSION)/$($(PKG)_FILE)
$(PKG)_TARGETS  := $(BUILD) $(MXE_TARGETS)
$(PKG)_DEPS     := cc bzip2 expat zlib

$(PKG)_DEPS_$(BUILD) := zlib

# Generate the stupid x32 / x64 Windows style architecture suffix
$(PKG)_TARGET_SUFFIX := $(if $(findstring x86_64,$(TARGET)),-x64,-x32)

define $(PKG)_UPDATE
    $(WGET) -q -O- 'https://www.boost.org/users/download/' | \
    $(SED) -n 's,.*/release/\([0-9][^"/]*\)/.*,\1,p' | \
    grep -v beta | \
    head -1
endef

define $(PKG)_BUILD
    # old version appears to interfere
    rm -rf '$(PREFIX)/$(TARGET)/include/boost/'
    rm -f "$(PREFIX)/$(TARGET)/lib/libboost"*

    # create user-config
    echo 'using gcc : mxe : $(TARGET)-g++ : <rc>$(TARGET)-windres <archiver>$(TARGET)-ar <ranlib>$(TARGET)-ranlib ;' > '$(1)/user-config.jam'

    # compile boost build (b2)
    cd '$(1)/tools/build/' && ./bootstrap.sh

    # cross-build, see b2 options at:
    # https://www.boost.org/build/doc/html/bbv2/overview/invocation.html
    cd '$(1)' && ./tools/build/b2 \
        -a \
        -q \
        -j '$(JOBS)' \
        --ignore-site-config \
        --user-config=user-config.jam \
        abi=ms \
        address-model=$(BITS) \
        architecture=x86 \
        binary-format=pe \
        link=$(if $(BUILD_STATIC),static,shared) \
        target-os=windows \
        threadapi=win32 \
        threading=multi \
        variant=release \
        toolset=gcc-mxe \
        --layout=tagged \
        --disable-icu \
        --without-mpi \
        --without-python \
        --prefix='$(PREFIX)/$(TARGET)' \
        --exec-prefix='$(PREFIX)/$(TARGET)/bin' \
        --libdir='$(PREFIX)/$(TARGET)/lib' \
        --includedir='$(PREFIX)/$(TARGET)/include' \
        -sEXPAT_INCLUDE='$(PREFIX)/$(TARGET)/include' \
        -sEXPAT_LIBPATH='$(PREFIX)/$(TARGET)/lib' \
        install

    $(if $(BUILD_SHARED), \
        mv -fv '$(PREFIX)/$(TARGET)/lib/'libboost_*.dll '$(PREFIX)/$(TARGET)/bin/')

    # setup cmake toolchain
    echo 'set(Boost_THREADAPI "win32")' > '$(CMAKE_TOOLCHAIN_DIR)/$(PKG).cmake'

    '$(TARGET)-g++' \
        -W -Wall -Werror -ansi -U__STRICT_ANSI__ -pedantic \
        '$(PWD)/src/$(PKG)-test.cpp' -o '$(PREFIX)/$(TARGET)/bin/test-boost.exe' \
        -DBOOST_THREAD_USE_LIB \
        -lboost_serialization-mt$($(PKG)_TARGET_SUFFIX) \
        -lboost_system-mt$($(PKG)_TARGET_SUFFIX) \
        -lboost_chrono-mt$($(PKG)_TARGET_SUFFIX) \
        -lboost_context-mt$($(PKG)_TARGET_SUFFIX)

    # test cmake
    mkdir '$(1).test-cmake'
    cd '$(1).test-cmake' && '$(TARGET)-cmake' \
        -DPKG=$(PKG) \
        -DPKG_VERSION=$($(PKG)_VERSION) \
        '$(PWD)/src/cmake/test'
    $(MAKE) -C '$(1).test-cmake' -j 1 install
endef

define $(PKG)_BUILD_$(BUILD)
    # old version appears to interfere
    rm -rf '$(PREFIX)/$(TARGET)/include/boost/'
    rm -f "$(PREFIX)/$(TARGET)/lib/libboost"*

    # compile boost build (b2)
    cd '$(SOURCE_DIR)/tools/build/' && ./bootstrap.sh

    # minimal native build - for more features, replace:
    # --with-system \
    # --with-filesystem \
    #
    # with:
    # --without-mpi \
    # --without-python \

    cd '$(SOURCE_DIR)' && \
        $(if $(call seq,darwin,$(OS_SHORT_NAME)),PATH=/usr/bin:$$PATH) \
        ./tools/build/b2 \
            -a \
            -q \
            -j '$(JOBS)' \
            --ignore-site-config \
            variant=release \
            link=static \
            threading=multi \
            runtime-link=static \
            --disable-icu \
            --with-system \
            --with-filesystem \
            --build-dir='$(BUILD_DIR)' \
            --prefix='$(PREFIX)/$(TARGET)' \
            --exec-prefix='$(PREFIX)/$(TARGET)/bin' \
            --libdir='$(PREFIX)/$(TARGET)/lib' \
            --includedir='$(PREFIX)/$(TARGET)/include' \
            install
endef
