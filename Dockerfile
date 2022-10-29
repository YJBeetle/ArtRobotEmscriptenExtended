FROM emscripten/emsdk:latest

ENV OPENCV_VERSION=4.6.0
ENV JPEG_VERSION=2.1.4
ENV ZLIB_VERSION=1.2.13
ENV PNG_VERSION=1.6.38
ENV BZIP2_VERSION=1.0.8
ENV FREETYPE_VERSION=2.12.1
ENV PIXMAN_VERSION=0.42.0
ENV CAIRO_VERSION=1.16.0
ENV IFFI_VERSION=3.4.4
ENV GLIB_VERSION=2.74.1
ENV HARFBUZZ_VERSION=5.3.1
ENV FRIBIDI_VERSION=1.0.12
ENV EXPAT_VERSION=2.5.0
ENV FONTCONFIG_VERSION=2.14.1
ENV PANGO_VERSION=1.50.11

# APT
RUN apt update &&\
    apt install -y python3 cargo pkg-config libtool ninja-build gperf libglib2.0-dev-bin &&\
    python3 -m pip install meson

# meson
ADD emscripten.txt /i/emscripten.txt

# opencv
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz -O opencv-${OPENCV_VERSION}.tar.gz &&\
    tar xvf opencv-${OPENCV_VERSION}.tar.gz &&\
    cd opencv-${OPENCV_VERSION} &&\
    emmake python3 ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot" build &&\
    cmake --build build -j8 &&\
    cmake --install build

# libjpeg
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/${JPEG_VERSION}.tar.gz -O libjpeg-turbo-${JPEG_VERSION}.tar.gz &&\
    tar xvf libjpeg-turbo-${JPEG_VERSION}.tar.gz &&\
    cd libjpeg-turbo-${JPEG_VERSION} &&\
    emcmake cmake -B build -DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot &&\
    cmake --build build -j8 &&\
    cmake --install build

# zlib
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.xz &&\
    tar xvf zlib-${ZLIB_VERSION}.tar.xz &&\
    cd zlib-${ZLIB_VERSION} &&\
    sed -i "s|add_library(zlib SHARED |add_library(zlib STATIC |g" CMakeLists.txt &&\
    sed -i "s|share/pkgconfig|lib/pkgconfig|g" CMakeLists.txt &&\
    emcmake cmake -B build &&\
    cmake --build build &&\
    cmake --install build

# libpng
# 需要 zlib
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://download.sourceforge.net/libpng/libpng-${PNG_VERSION}.tar.xz &&\
    tar xvf libpng-${PNG_VERSION}.tar.xz &&\
    cd libpng-${PNG_VERSION} &&\
    emcmake cmake -B build -DPNG_SHARED=no -DPNG_STATIC=yes -DPNG_FRAMEWORK=no -DM_LIBRARY="" &&\
    cmake --build build -j8 &&\
    cmake --install build

# bzip2
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz &&\
    tar xvf bzip2-${BZIP2_VERSION}.tar.gz &&\
    cd bzip2-${BZIP2_VERSION} &&\
    sed -i "s|CC=gcc|CC=/emsdk/upstream/emscripten/emcc|g" Makefile &&\
    sed -i "s|AR=ar|AR=/emsdk/upstream/emscripten/emar|g" Makefile &&\
    sed -i "s|RANLIB=ranlib|RANLIB=/emsdk/upstream/emscripten/emranlib|g" Makefile &&\
    sed -i "s|CC=gcc|CC=/emsdk/upstream/emscripten/emcc|g" Makefile-libbz2_so &&\
    emmake make bzip2 -j8 &&\
    emmake make install PREFIX=/emsdk/upstream/emscripten/cache/sysroot

# freetype
# 需要 libpng zlib bzip2
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://download.sourceforge.net/freetype/freetype-${FREETYPE_VERSION}.tar.xz &&\
    tar xvf freetype-${FREETYPE_VERSION}.tar.xz &&\
    cd freetype-${FREETYPE_VERSION} &&\
    emcmake cmake -B build &&\
    cmake --build build -j8 &&\
    cmake --install build

# expat
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz &&\
    tar xvf expat-${EXPAT_VERSION}.tar.xz &&\
    cd expat-${EXPAT_VERSION} &&\
    emmake ./buildconf.sh --force &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# fontconfig
# 需要 freetype expat
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz &&\
    tar xvf fontconfig-${FONTCONFIG_VERSION}.tar.xz &&\
    cd fontconfig-${FONTCONFIG_VERSION} &&\
    sed -i "s|error('FIXME: implement cc.preprocess')|cpp += \['-E', '-P'\]|g" src/meson.build &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dtests=disabled -Ddoc=disabled -Dtools=disabled &&\
    meson compile -C build &&\
    meson install -C build

# pixman
# 需要 zlib
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://www.cairographics.org/releases/pixman-${PIXMAN_VERSION}.tar.gz &&\
    tar xvf pixman-${PIXMAN_VERSION}.tar.gz &&\
    cd pixman-${PIXMAN_VERSION} &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared LDFLAGS="$(emmake pkg-config --libs zlib)" &&\
    emmake make -j8 &&\
    emmake make install

# cairo
# 需要 libpng pixman freetype zlib
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://www.cairographics.org/releases/cairo-${CAIRO_VERSION}.tar.xz &&\
    tar xvf cairo-${CAIRO_VERSION}.tar.xz &&\
    cd cairo-${CAIRO_VERSION} &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared -without-x \
        --disable-xlib --disable-xlib-xrender --disable-directfb --disable-win32 --disable-script \
        --enable-pdf --enable-ps --enable-svg --enable-png \
        --disable-interpreter --disable-xlib-xcb --disable-xcb --disable-xcb-shm \
        --enable-ft --enable-fc \
        ax_cv_c_float_words_bigendian=no ac_cv_lib_z_compress=yes \
        FREETYPE_CFLAGS="$(emmake pkg-config --cflags freetype2)" FREETYPE_LIBS="$(emmake pkg-config --libs freetype2)" \
        FONTCONFIG_CFLAGS="$(emmake pkg-config --cflags fontconfig)" FONTCONFIG_LIBS="$(emmake pkg-config --libs fontconfig)" \
        png_CFLAGS="$(emmake pkg-config --cflags libpng)" png_LIBS="$(emmake pkg-config --libs libpng)" \
        pixman_CFLAGS="$(emmake pkg-config --cflags pixman-1)" pixman_LIBS="$(emmake pkg-config --libs pixman-1)" \
        CFLAGS="$(emmake pkg-config --cflags zlib) -DCAIRO_NO_MUTEX=1" LDFLAGS="$(emmake pkg-config --libs zlib)" &&\
    emmake make -j8 &&\
    emmake make install

# libffi
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/libffi/libffi/releases/download/v${IFFI_VERSION}/libffi-${IFFI_VERSION}.tar.gz &&\
    tar xvf libffi-${IFFI_VERSION}.tar.gz &&\
    cd libffi-${IFFI_VERSION} &&\
    # see https://github.com/kleisauke/wasm-vips/blob/master/build.sh#L203
    curl -Ls https://github.com/libffi/libffi/compare/v${IFFI_VERSION}...kleisauke:wasm-vips.patch | patch -p1 &&\
    autoreconf -fiv &&\
    sed -i 's/ -fexceptions//g' configure &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking --disable-builddir --disable-multi-os-directory --disable-raw-api --disable-structs --disable-docs &&\
    emmake make -j8 &&\
    emmake make install

# glib
# 需要 libffi
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://download.gnome.org/sources/glib/${GLIB_VERSION%.*}/glib-${GLIB_VERSION}.tar.xz &&\
    tar xvf glib-${GLIB_VERSION}.tar.xz &&\
    cd glib-${GLIB_VERSION} &&\
    # see https://github.com/kleisauke/wasm-vips/blob/master/build.sh#L220
    curl -Ls https://github.com/GNOME/glib/compare/${GLIB_VERSION}...kleisauke:wasm-vips.patch | patch -p1 &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        --force-fallback-for=gvdb -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dnls=disabled \
        -Dtests=false -Dglib_assert=false -Dglib_checks=false &&\
    meson install -C build

# harfbuzz
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz &&\
    tar xvf harfbuzz-${HARFBUZZ_VERSION}.tar.xz &&\
    cd harfbuzz-${HARFBUZZ_VERSION} &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dglib=disabled -Dgobject=disabled -Dcairo=enabled -Dfreetype=enabled -Ddocs=disabled -Dtests=disabled &&\
    meson compile -C build &&\
    meson install -C build

# fribidi
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/fribidi/fribidi/releases/download/v1.0.12/fribidi-${FRIBIDI_VERSION}.tar.xz &&\
    tar xvf fribidi-${FRIBIDI_VERSION}.tar.xz &&\
    cd fribidi-${FRIBIDI_VERSION} &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dtests=false -Ddocs=false &&\
    meson compile -C build &&\
    meson install -C build

# Pango
# 需要 harfbuzz fribidi fontconfig freetype glib cairo libglib2.0-dev-bin
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://download.gnome.org/sources/pango/1.50/pango-${PANGO_VERSION}.tar.xz &&\
    tar xvf pango-${PANGO_VERSION}.tar.xz &&\
    cd pango-${PANGO_VERSION} &&\
    sed -i "s|subdir('examples')||g" meson.build &&\
    sed -i "s|subdir('tests')||g" meson.build &&\
    sed -i "s|subdir('utils')||g" meson.build &&\
    sed -i "s|subdir('tools')||g" meson.build &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dintrospection=disabled -Dinstall-tests=false &&\
    meson compile -C build &&\
    meson install -C build
