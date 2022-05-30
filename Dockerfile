FROM emscripten/emsdk:latest

# APT
RUN sed -i "s|^# deb-src|deb-src|g" /etc/apt/sources.list &&\
    sed -i "s|^deb-src http://archive.canonical.com/ubuntu|# deb-src http://archive.canonical.com/ubuntu|g" /etc/apt/sources.list &&\
    apt update &&\
    apt install -y python3 cargo automake-1.15 pkg-config ninja-build &&\
    python3 -m pip install meson

# opencv
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/opencv/opencv/archive/refs/tags/4.5.5.tar.gz -O opencv-4.5.5.tar.gz &&\
    tar xvf opencv-4.5.5.tar.gz &&\
    cd opencv-4.5.5 &&\
    emmake python3 ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot" build &&\
    cmake --build build -j8 &&\
    cmake --install build

# zlib
RUN mkdir -p /i &&\
    cd /i &&\
    apt source zlib &&\
    cd zlib-* &&\
    mkdir -p win32 && touch win32/zlib1.rc &&\
    sed -i "s|add_library(zlib SHARED |add_library(zlib STATIC |g" CMakeLists.txt &&\
    sed -i "s|share/pkgconfig|lib/pkgconfig|g" CMakeLists.txt &&\
    emcmake cmake -B build &&\
    cmake --build build &&\
    cmake --install build

# libpng
# 需要 zlib
RUN mkdir -p /i &&\
    cd /i &&\
    apt source libpng1.6 &&\
    cd libpng1.6-* &&\
    emcmake cmake -B build -DPNG_SHARED=no -DPNG_STATIC=yes -DPNG_FRAMEWORK=no -DM_LIBRARY="" &&\
    cmake --build build -j8 &&\
    cmake --install build

# freetype
# 需要 libpng zlib
RUN mkdir -p /i &&\
    cd /i &&\
    apt source freetype &&\
    cd freetype-* &&\
    emcmake cmake -B build &&\
    cmake --build build -j8 &&\
    cmake --install build

# pixman
RUN mkdir -p /i &&\
    cd /i &&\
    apt source pixman &&\
    cd pixman-* &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot --disable-shared &&\
    emmake make -j8 &&\
    emmake make install

# cairo
# 需要 libpng pixman freetype zlib
RUN mkdir -p /i &&\
    cd /i &&\
    apt source cairo &&\
    cd cairo-* &&\
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
    apt source libffi &&\
    cd libffi-* &&\
    emconfigure ./configure -prefix=/emsdk/upstream/emscripten/cache/sysroot &&\
    emmake make -j8 &&\
    emmake make install

# glib2.0
# 需要 libffi
RUN mkdir -p /i &&\
    cd /i &&\
    apt source glib2.0 &&\
    cd glib2.0-* &&\
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
c_link_args = ['-L/emsdk/upstream/emscripten/cache/sysroot/lib'] \n\
cpp_link_args = ['-L/emsdk/upstream/emscripten/cache/sysroot/lib'] \n\
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
    sed -i -e ':a' -e 'N' -e '$!ba' -e "s|if host_system != 'windows'\n  # res_query()|if host_system != 'windows' and host_system != 'emscripten'\n  # res_query()|g" gio/meson.build &&\
    sed -i "s|if cc.get_id() == 'gcc' and not cc.compiles(atomicdefine, name : 'atomic ops define')|if not cc.compiles(atomicdefine, name : 'atomic ops define')|g" meson.build &&\
    sed -i "s|if cc.has_function('posix_spawn', prefix : '#include <spawn.h>')|if host_system != 'emscripten' and cc.has_function('posix_spawn', prefix : '#include <spawn.h>')|g" meson.build &&\
    emmake meson --prefix=/emsdk/upstream/emscripten/cache/sysroot/ --cross-file=emscripten.txt \
        --default-library=static --buildtype=release --force-fallback-for=libpcre \
        -Diconv="libc" -Dselinux=disabled -Dxattr=false -Dlibmount=disabled -Dnls=disabled \
        build &&\
    ninja -C build
