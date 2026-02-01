#!/bin/bash -ex

if [[ "$TARGET" == "appimage"* ]]; then
    # Compile the AppImage we distribute with Clang (x86) or GCC (ARM64).
    if [ "$(uname -m)" = "aarch64" ]; then
        export EXTRA_CMAKE_FLAGS=(-DCMAKE_CXX_COMPILER=g++
                                  -DCMAKE_C_COMPILER=gcc
                                  -DENABLE_ROOM_STANDALONE=OFF)
    else
        LINKER_PATH="/etc/bin/ld.lld"
        if [ ! -f "$LINKER_PATH" ]; then
            LINKER_PATH="lld"
        fi
        export EXTRA_CMAKE_FLAGS=(-DCMAKE_CXX_COMPILER=clang++
                                  -DCMAKE_C_COMPILER=clang
                                  -DCMAKE_LINKER=$LINKER_PATH
                                  -DENABLE_ROOM_STANDALONE=OFF)
    fi
    if [ "$TARGET" = "appimage-wayland" ]; then
        # Bundle required QT wayland libraries
        export EXTRA_QT_PLUGINS="waylandcompositor"
        export EXTRA_PLATFORM_PLUGINS="libqwayland-egl.so;libqwayland-generic.so"
    fi
else
    # For the linux-fresh verification target, verify compilation without PCH as well.
    export EXTRA_CMAKE_FLAGS=(-DCITRA_USE_PRECOMPILED_HEADERS=OFF)
fi

if [ "$GITHUB_REF_TYPE" == "tag" ]; then
    export EXTRA_CMAKE_FLAGS=("${EXTRA_CMAKE_FLAGS[@]}" -DENABLE_QT_UPDATE_CHECKER=ON)
fi

mkdir build && cd build
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DENABLE_QT_TRANSLATION=ON \
    -DENABLE_ROOM_STANDALONE=OFF \
    -DUSE_DISCORD_PRESENCE=ON \
    "${EXTRA_CMAKE_FLAGS[@]}"
ninja
strip -s bin/Release/*

if [[ "$TARGET" == "appimage"* ]]; then
    ninja bundle
    # TODO: Our AppImage environment currently uses an older ccache version without the verbose flag.
    ccache -s
else
    ccache -s -v
fi

ctest -VV -C Release
