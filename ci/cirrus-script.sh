#!/usr/bin/env bash
set -ev

. ci/ci-functions.sh

# Must match the value in .cirrus.yml
export CCACHE_DIR="$PWD/ccache-cache"

if [ "$CIRRUS_OS" = "linux" ]
then
    ci_timer
    apt-get update
    ci_timer
    ci_retry apt-get install -y wget software-properties-common apt-transport-https cmake ninja-build ccache g++-5 gcc-5
    export CXX=g++-5
    export CC=gcc-5
    ci_timer
else
    ci_timer
    pkg install -y cmake ninja ccache
    ci_timer
    export CXX=clang++
    export CC=clang
fi

date

if [ "$CAIDE_USE_SYSTEM_CLANG" = "ON" ]
then
    export Clang_ROOT=/usr/lib/llvm-$CAIDE_CLANG_VERSION

    case "$CAIDE_CLANG_VERSION" in
        3.8|3.9|4.0)
            # CMake packaging is broken in these
            export Clang_ROOT="$PWD/ci/cmake/$CAIDE_CLANG_VERSION"
            export LLVM_ROOT="$Clang_ROOT"
            ;;
    esac

    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    add-apt-repository "deb http://apt.llvm.org/xenial/   llvm-toolchain-xenial-$CAIDE_CLANG_VERSION  main"
    apt-get update
    ci_timer
    ci_retry apt-get install -y -t llvm-toolchain-xenial-"$CAIDE_CLANG_VERSION" clang-"$CAIDE_CLANG_VERSION" libclang-"$CAIDE_CLANG_VERSION"-dev llvm-"$CAIDE_CLANG_VERSION"-dev

    export CMAKE_PREFIX_PATH=$Clang_ROOT

    # Debug
    llvm-config-"$CAIDE_CLANG_VERSION" --cxxflags --cflags --ldflags --has-rtti
else
    if [ "$CIRRUS_OS" = "linux" ]
    then
        ci_retry apt-get install -y git
    else
        pkg install -y git
    fi
    ci_timer
    git submodule sync
    git submodule update --init
fi

env | sort
cmake --version
"$CXX" --version
"$CC" --version
ci_timer

mkdir build
cd build
cmake -GNinja -DCAIDE_USE_SYSTEM_CLANG=$CAIDE_USE_SYSTEM_CLANG \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_BUILD_TYPE=MinSizeRel ../src

ninja || ninja -j1

ci_timer

if [ "$CAIDE_USE_SYSTEM_CLANG" = "ON" ]
then
    # Work around some packaging issues...
    case "$CAIDE_CLANG_VERSION" in
        3.8)
            mkdir -p lib/clang
            ln -s /usr/include/clang/3.8 lib/clang/3.8.1
            ;;
        3.9)
            mkdir -p lib/clang
            ln -s /usr/include/clang/3.9 lib/clang/3.9.1
            ;;
        9)
            ls -lah /usr/include/clang/*
            ln -s /usr/lib/llvm-9/lib/clang/9.0.1 /usr/include/clang/9.0.1 || true
            ;;
    esac
else
    ninja install-clang-resource-headers
    # The previous target installs builtin clang headers under llvm-project/, but clang libraries expect to find them under lib/
    # (a bug in clang when it's built as a CMake subproject?)
    ln -s $(pwd)/llvm-project/llvm/lib/clang lib/clang
fi

ctest --verbose

ci_timer

