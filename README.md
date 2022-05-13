# sticker-generator

## WASM depend

    sudo apt install emscripten cmake automake
    sudo apt -t experimental install llvm clang lld

zlib:
    apt source zlib
    cd zlib-*
    # vim CMakeLists.txt del zlib1.rc
    emcmake cmake -B build -DINSTALL_PKGCONFIG_DIR=${HOME}/.emscripten_cache/sysroot/lib/pkgconfig
    cmake --build build -j8
    cmake --install build

libm:
    apt source libopenlibm3
    cd openlibm-*
    emmake make -j8
    emmake make install prefix=${HOME}/.emscripten_cache/sysroot # SONAME_FLAG=

libpng:
    apt source libpng1.6
    cd libpng1.6-*
    emcmake cmake -B build -DM_LIBRARY=
    cmake --build build -j8
    cmake --install build

libjpeg-turbo:
    apt source libjpeg-turbo
    cd libjpeg-turbo-*
    emcmake cmake -B build -DCMAKE_INSTALL_PREFIX=${HOME}/.emscripten_cache/sysroot # -DWITH_SIMD=0
    cmake --build build -j8
    cmake --install build

libtiff:
    apt source tiff
    cd tiff-*
    # vim cmake/TypeSizeChecks.cmake
    # check_type_size("size_t" SIZEOF_SIZE_T)
    # to
    # set(SIZEOF_SIZE_T 4)
    emcmake cmake -B build_cmake
    cmake --build build_cmake -j8
    cmake --install build_cmake

libwebp:
    apt source libwebp
    cd libwebp-*
    emcmake cmake -B build
    cmake --build build -j8
    cmake --install build

opencv:
    wget https://github.com/opencv/opencv/archive/refs/tags/4.5.3.tar.gz -O opencv-4.5.3.tar.gz
    tar xvf opencv-4.5.3.tar.gz
    cd opencv-*
    emmake python ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=${HOME}/.emscripten_cache/sysroot" build
    cmake --build build -j8
    cmake --install build

pixman:
    apt source pixman
    cd pixman-*
    emconfigure ./configure
    emmake make -j8
    emmake make install prefix=${HOME}/.emscripten_cache/sysroot

freetype:
    apt source freetype
    cd freetype-*
    emcmake cmake -B build
    cmake --build build -j8
    cmake --install build

cairo:
    apt source cairo
    cd cairo-*
    sed 's?no (requires zlib http://www.gzip.org/zlib/)?yes?' ./configure > configure2
    emconfigure ./configure2 ax_cv_c_float_words_bigendian=no
    sed 's?aclocal-1.15?aclocal-1.16?' ./Makefile > Makefile2

# Dev

    npx wrangler dev
    while true; do clear; curl -v -m 2 "http://localhost:8787/" ; sleep 1; done
