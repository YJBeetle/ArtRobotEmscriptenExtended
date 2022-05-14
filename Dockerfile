FROM emscripten/emsdk:latest

# APT
RUN apt update &&\
    apt install -y pkgconf python3

# deb-src
RUN sed -i "s/# deb-src/deb-src/g" /etc/apt/sources.list &&\
    apt update

# opencv
RUN mkdir -p /i &&\
    cd /i &&\
    wget https://github.com/opencv/opencv/archive/refs/tags/4.5.5.tar.gz -O opencv-4.5.5.tar.gz &&\
    tar xvf opencv-4.5.5.tar.gz &&\
    cd opencv-4.5.5 &&\
    emmake python3 ./platforms/js/build_js.py --build_wasm $(emcmake echo | awk -v RS=' ' -v ORS=' ' '{print "--cmake_option=\""$1"\""}') --cmake_option="-DCMAKE_INSTALL_PREFIX=/emsdk/upstream/emscripten/cache/sysroot" build &&\
    cmake --build build -j8 &&\
    cmake --install build
