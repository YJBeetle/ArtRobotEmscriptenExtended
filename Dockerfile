FROM emscripten/emsdk:latest

SHELL ["/bin/bash", "-c"]

# APT
RUN apt update &&\
    apt install -y python3 cargo pkg-config libtool ninja-build gperf libglib2.0-dev-bin gettext libxml2-utils &&\
    rm -rf /var/lib/apt/lists/* &&\
    python3 -m pip install meson

ENV BUILD_DIR=/i

# meson
ADD emscripten.txt ${BUILD_DIR}/emscripten.txt

# opencv
ENV OPENCV_VERSION=4.6.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz -O opencv-${OPENCV_VERSION}.tar.gz &&\
    tar xvf opencv-${OPENCV_VERSION}.tar.gz &&\
    cd opencv-${OPENCV_VERSION} &&\
    emmake python3 ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot" build &&\
    cmake --build build -j2 &&\
    cmake --install build &&\
    cd .. && rm -rf opencv-${OPENCV_VERSION}.tar.gz opencv-${OPENCV_VERSION}

# libjpeg
ENV JPEG_VERSION=2.1.4
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://download.sourceforge.net/libjpeg-turbo/libjpeg-turbo-${JPEG_VERSION}.tar.gz &&\
    tar xvf libjpeg-turbo-${JPEG_VERSION}.tar.gz &&\
    cd libjpeg-turbo-${JPEG_VERSION} &&\
    emcmake cmake -B build -DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot &&\
    cmake --build build -j2 &&\
    cmake --install build &&\
    cd .. && rm -rf libjpeg-turbo-${JPEG_VERSION}.tar.gz libjpeg-turbo-${JPEG_VERSION}

# zlib
ENV ZLIB_VERSION=1.2.13
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.xz &&\
    tar xvf zlib-${ZLIB_VERSION}.tar.xz &&\
    cd zlib-${ZLIB_VERSION} &&\
    sed -i "s|add_library(zlib SHARED |add_library(zlib STATIC |g" CMakeLists.txt &&\
    sed -i "s|share/pkgconfig|lib/pkgconfig|g" CMakeLists.txt &&\
    emcmake cmake -B build &&\
    cmake --build build &&\
    cmake --install build &&\
    cd .. && rm -rf zlib-${ZLIB_VERSION}.tar.xz zlib-${ZLIB_VERSION}

# libpng
# 需要 zlib
ENV PNG_VERSION=1.6.38
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://download.sourceforge.net/libpng/libpng-${PNG_VERSION}.tar.xz &&\
    tar xvf libpng-${PNG_VERSION}.tar.xz &&\
    cd libpng-${PNG_VERSION} &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking \
        CFLAGS="-I/emsdk/upstream/emscripten/cache/sysroot/include/ -pthread" \
        LDFLAGS="-L/emsdk/upstream/emscripten/cache/sysroot/lib -pthread" &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf libpng-${PNG_VERSION}.tar.xz libpng-${PNG_VERSION}

# WebP
ENV WEBP_VERSION=1.2.4
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz &&\
    tar xvf libwebp-${WEBP_VERSION}.tar.gz &&\
    cd libwebp-${WEBP_VERSION} &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking \
        --disable-png --disable-libwebpdecoder --disable-libwebpdemux --disable-libwebpmux --disable-sdl &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf libwebp-${WEBP_VERSION}.tar.gz libwebp-${WEBP_VERSION}

# freetype
# 需要 libpng zlib
ENV FREETYPE_VERSION=2.13.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://download.sourceforge.net/freetype/freetype-${FREETYPE_VERSION}.tar.xz &&\
    tar xvf freetype-${FREETYPE_VERSION}.tar.xz &&\
    cd freetype-${FREETYPE_VERSION} &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking &&\
    gcc ./src/tools/apinames.c -o ./objs/apinames &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf freetype-${FREETYPE_VERSION}.tar.xz freetype-${FREETYPE_VERSION}

# expat
ENV EXPAT_VERSION=2.5.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz &&\
    tar xvf expat-${EXPAT_VERSION}.tar.xz &&\
    cd expat-${EXPAT_VERSION} &&\
    emmake ./buildconf.sh --force &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf expat-${EXPAT_VERSION}.tar.xz expat-${EXPAT_VERSION}

# fontconfig
# 需要 freetype expat
ENV FONTCONFIG_VERSION=2.14.1
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.xz &&\
    tar xvf fontconfig-${FONTCONFIG_VERSION}.tar.xz &&\
    cd fontconfig-${FONTCONFIG_VERSION} &&\
    sed -i "s|error('FIXME: implement cc.preprocess')|cpp += \['-E', '-P'\]|g" src/meson.build &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dtests=disabled -Ddoc=disabled -Dtools=disabled &&\
    meson compile -C build &&\
    meson install -C build &&\
    cd .. && rm -rf fontconfig-${FONTCONFIG_VERSION}.tar.xz fontconfig-${FONTCONFIG_VERSION}

# pixman
# 需要 zlib
ENV PIXMAN_VERSION=0.42.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://www.cairographics.org/releases/pixman-${PIXMAN_VERSION}.tar.gz &&\
    tar xvf pixman-${PIXMAN_VERSION}.tar.gz &&\
    cd pixman-${PIXMAN_VERSION} &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dtests=disabled &&\
    meson compile -C build &&\
    meson install -C build &&\
    cd .. && rm -rf pixman-${PIXMAN_VERSION}.tar.gz pixman-${PIXMAN_VERSION}

# libffi
ENV IFFI_VERSION=3.4.4
# see https://github.com/kleisauke/wasm-vips/blob/master/build.sh#L258
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/libffi/libffi/releases/download/v${IFFI_VERSION}/libffi-${IFFI_VERSION}.tar.gz &&\
    tar xvf libffi-${IFFI_VERSION}.tar.gz &&\
    cd libffi-${IFFI_VERSION} &&\
    curl -Ls https://github.com/libffi/libffi/compare/v${IFFI_VERSION}...kleisauke:wasm-vips.patch | patch -p1 &&\
    autoreconf -fiv &&\
    sed -i 's/ -fexceptions//g' configure &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking \
        --disable-builddir --disable-multi-os-directory --disable-raw-api --disable-structs --disable-docs &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf libffi-${IFFI_VERSION}.tar.gz libffi-${IFFI_VERSION}

# glib
# 需要 libffi
ENV GLIB_VERSION=2.76.2
# see https://github.com/kleisauke/wasm-vips/blob/master/build.sh#L273
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://download.gnome.org/sources/glib/${GLIB_VERSION%.*}/glib-${GLIB_VERSION}.tar.xz &&\
    tar xvf glib-${GLIB_VERSION}.tar.xz &&\
    cd glib-${GLIB_VERSION} &&\
    curl -Ls https://github.com/GNOME/glib/compare/${GLIB_VERSION}...kleisauke:wasm-vips-${GLIB_VERSION}.patch | patch -p1 &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        --force-fallback-for=gvdb -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dnls=disabled \
        -Dtests=false -Dglib_assert=false -Dglib_checks=false &&\
    meson install -C build &&\
    ln -s /emsdk/upstream/emscripten/cache/sysroot/lib/pkgconfig/gio-2.0.pc /emsdk/upstream/emscripten/cache/sysroot/lib/pkgconfig/gio-unix-2.0.pc &&\
    cd .. && rm -rf glib-${GLIB_VERSION}.tar.xz glib-${GLIB_VERSION}

# cairo
# 需要 libpng pixman freetype zlib glib
ENV CAIRO_VERSION=1.16.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://www.cairographics.org/releases/cairo-${CAIRO_VERSION}.tar.xz &&\
    tar xvf cairo-${CAIRO_VERSION}.tar.xz &&\
    cd cairo-${CAIRO_VERSION} &&\
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking \
        -without-x \
        --disable-xlib --disable-xlib-xrender --disable-directfb --disable-win32 --enable-script \
        --enable-pdf --enable-ps --enable-svg --enable-png \
        --enable-interpreter --disable-xlib-xcb --disable-xcb --disable-xcb-shm \
        --enable-ft --enable-fc \
        --enable-pthread \
        ax_cv_c_float_words_bigendian=no ac_cv_lib_z_compress=yes \
        CFLAGS="-pthread" &&\
    emmake make -j2 &&\
    emmake make install &&\
    cd .. && rm -rf cairo-${CAIRO_VERSION}.tar.xz cairo-${CAIRO_VERSION}

# harfbuzz
ENV HARFBUZZ_VERSION=7.3.0
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz &&\
    tar xvf harfbuzz-${HARFBUZZ_VERSION}.tar.xz &&\
    cd harfbuzz-${HARFBUZZ_VERSION} &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dglib=disabled -Dgobject=disabled -Dcairo=enabled -Dfreetype=enabled -Ddocs=disabled -Dtests=disabled &&\
    meson compile -C build &&\
    meson install -C build &&\
    cd .. && rm -rf harfbuzz-${HARFBUZZ_VERSION}.tar.xz harfbuzz-${HARFBUZZ_VERSION}

# fribidi
ENV FRIBIDI_VERSION=1.0.12
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://github.com/fribidi/fribidi/releases/download/v1.0.12/fribidi-${FRIBIDI_VERSION}.tar.xz &&\
    tar xvf fribidi-${FRIBIDI_VERSION}.tar.xz &&\
    cd fribidi-${FRIBIDI_VERSION} &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dtests=false -Ddocs=false &&\
    meson compile -C build &&\
    meson install -C build &&\
    cd .. && rm -rf fribidi-${FRIBIDI_VERSION}.tar.xz fribidi-${FRIBIDI_VERSION}

# Pango
# 需要 harfbuzz fribidi fontconfig freetype glib cairo libglib2.0-dev-bin
ENV PANGO_VERSION=1.50.14
RUN mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} &&\
    wget https://download.gnome.org/sources/pango/${PANGO_VERSION%.*}/pango-${PANGO_VERSION}.tar.xz &&\
    tar xvf pango-${PANGO_VERSION}.tar.xz &&\
    cd pango-${PANGO_VERSION} &&\
    sed -i "s|subdir('examples')||g" meson.build &&\
    sed -i "s|subdir('tests')||g" meson.build &&\
    sed -i "s|subdir('utils')||g" meson.build &&\
    sed -i "s|subdir('tools')||g" meson.build &&\
    meson setup build --prefix=/emsdk/upstream/emscripten/cache/sysroot --cross-file=../emscripten.txt --default-library=static --buildtype=release \
        -Dintrospection=disabled -Dinstall-tests=false &&\
    meson compile -C build &&\
    meson install -C build &&\
    cd .. && rm -rf pango-${PANGO_VERSION}.tar.xz pango-${PANGO_VERSION}

# clean meson
RUN rm ${BUILD_DIR}/emscripten.txt
