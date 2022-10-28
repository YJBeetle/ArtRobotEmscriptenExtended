FROM emscripten/emsdk:latest

ENV OPENCV_VERSION=4.6.0
ENV ZLIB_VERSION=1.2.13
ENV PNG_VERSION=1.6.38
ENV BZIP2_VERSION=1.0.8
ENV FREETYPE_VERSION=2.12.1
ENV PIXMAN_VERSION=0.42.0
ENV CAIRO_VERSION=1.16.0
ENV IFFI_VERSION=3.4.4

# APT
RUN sed -i "s|^# deb-src|deb-src|g" /etc/apt/sources.list &&\
    sed -i "s|^deb-src http://archive.canonical.com/ubuntu|# deb-src http://archive.canonical.com/ubuntu|g" /etc/apt/sources.list &&\
    apt update &&\
    apt install -y python3 cargo pkg-config automake-1.15 libtool ninja-build gperf &&\
    python3 -m pip install meson

# opencv
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz -O opencv-${OPENCV_VERSION}.tar.gz &&\
    tar xvf opencv-${OPENCV_VERSION}.tar.gz &&\
    cd opencv-${OPENCV_VERSION} &&\
    emmake python3 ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot" build &&\
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
        --enable-ft --disable-fc \
        ax_cv_c_float_words_bigendian=no ac_cv_lib_z_compress=yes \
        FREETYPE_CFLAGS="$(emmake pkg-config --cflags freetype2)" FREETYPE_LIBS="$(emmake pkg-config --libs freetype2)" \
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
    autoreconf -fiv
    sed -i 's/ -fexceptions//g' configure
    emconfigure ./configure --host=wasm32-unknown-linux --prefix=/emsdk/upstream/emscripten/cache/sysroot --enable-static --disable-shared --disable-dependency-tracking --disable-builddir --disable-multi-os-directory --disable-raw-api --disable-structs --disable-docs &&\
    emmake make -j8 &&\
    emmake make install

# glib2.0
# 需要 libffi
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://download.gnome.org/sources/glib/2.73/glib-2.73.0.tar.xz &&\
    tar xvf glib-2.73.0.tar.xz &&\
    cd glib-2.73.0 &&\
    curl -Ls https://github.com/kleisauke/wasm-vips/raw/master/build/patches/glib-emscripten.patch | patch -p1 &&\
    curl -Ls https://github.com/kleisauke/wasm-vips/raw/master/build/patches/glib-function-pointers.patch | patch -p1 &&\
    echo -e "\
[binaries] \n\
c = '/emsdk/upstream/emscripten/emcc' \n\
cpp = '/emsdk/upstream/emscripten/em++' \n\
ar = '/emsdk/upstream/emscripten/emar' \n\
ld = '/emsdk/upstream/bin/wasm-ld' \n\
ranlib = '/emsdk/upstream/emscripten/emranlib' \n\
pkgconfig = ['emmake', 'pkg-config'] \n\
[built-in options] \n\
c_thread_count = 0 \n\
cpp_thread_count = 0 \n\
[properties] \n\
root = '/emsdk/upstream/emscripten/cache/sysroot/' \n\
shared_lib_suffix = 'js' \n\
static_lib_suffix = 'js' \n\
shared_module_suffix = 'js' \n\
exe_suffix = 'js' \n\
[host_machine] \n\
system = 'emscripten' \n\
cpu_family = 'wasm32' \n\
cpu = 'wasm32' \n\
endian = 'little' \n\
" > emscripten.txt &&\
    emmake meson --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=emscripten.txt \
        --default-library=static --buildtype=release --force-fallback-for=libpcre \
        -Diconv="libc" -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dnls=disabled \
        build &&\
    ninja -C build &&\
    ninja -C build install

# fribidi
RUN mkdir -p /i &&\
    cd /i &&\
    apt source fribidi &&\
    cd fribidi-* &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# libdatrie
RUN mkdir -p /i &&\
    cd /i &&\
    apt source libdatrie &&\
    cd libdatrie-* &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# libthai
# 需要 libdatrie
RUN mkdir -p /i &&\
    cd /i &&\
    apt source libthai &&\
    cd libthai-* &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared --disable-dict &&\
    emmake make -j8 &&\
    emmake make install

# harfbuzz
RUN mkdir -p /i &&\
    cd /i &&\
    apt source harfbuzz &&\
    cd harfbuzz-* &&\
    sed -i "s|unsigned int  size0, size1, supp_size;|unsigned int  size0, size1;|g" src/hb-subset-cff1.cc &&\
    sed -i "s|supp_size = 0;||g" src/hb-subset-cff1.cc &&\
    sed -i "s|supp_size += SuppEncoding::static_size \* supp_codes.length;||g" src/hb-subset-cff1.cc &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# expat
RUN mkdir -p /i &&\
    cd /i &&\
    apt source expat &&\
    cd expat-*/expat &&\
    emmake ./buildconf.sh &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# fontconfig
# 需要 freetype2 expat
RUN mkdir -p /i &&\
    cd /i &&\
    apt source fontconfig &&\
    cd fontconfig-* &&\
    sed -i "s|freetype2 >= 21.0.15|freetype2|g" configure &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8
