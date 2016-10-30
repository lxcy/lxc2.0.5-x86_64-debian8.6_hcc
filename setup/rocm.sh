#! /bin/bash

## Prerequisites
##      cmake 3.7+
##
## some requirements
##   apt-get -t jessie-backports install libc++-dev libc++1 libelf1 libelf-dev git 
##   apt-get -t jessie-backports install libdw1 texinfo autoconf wget g++-multilib 
##   apt-get -t jessie-backports install make python2.7 fakeroot libc++abi-dev
#

THREADS=20
BUILD="$HOME/tmp/rocm"
INSTALL="/opt/rocm"
GITHUB="https://github.com/RadeonOpenCompute"
set -e

mkdir -p $BUILD && cd $BUILD
git clone --depth 1 $GITHUB/llvm llvm_amd-common
cd llvm_amd-common/tools/

git clone --depth 1 $GITHUB/lld lld
git clone --depth 1 $GITHUB/clang clang

mkdir -p ../build
cd ../build

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL/clang4 -DLLVM_TARGET_TO_BUILD="AMDGPU;X86" ..
make -j$THREADS
make install

export LLVM_BUILD=$INSTALL/clang4

cd $BUILD
git clone --depth 1 https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface thunk
cd thunk && make -j$THREADS
mkdir -p $INSTALL/libhsakmt/lib
cp -r include $INSTALL/libhsakmt
cp build/lnx64a/lib* $INSTALL/libhsakmt/lib
mkdir -p $INSTALL/lib && cd $INSTALL/lib
for f in $(find $INSTALL/libhsakmt/lib -name "libhsa*.so*"); do ln -s $f; done

cd $BUILD
git clone --depth 1 $GITHUB/ROCR-Runtime runtime
mkdir -p runtime/build && cd runtime/build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL/hsa \
	            -DHSATHK_BUILD_INC_PATH=$INSTALL/libhsakmt/include \
		                -DHSATHK_BUILD_LIB_PATH=$INSTALL/libhsakmt/lib ../src
make -j$THREADS
mkdir $INSTALL/hsa/include
cp ../src/inc/* $INSTALL/hsa/include
mkdir -p $INSTALL/include
ln -s $INSTALL/hsa/include $INSTALL/include/hsa 
mkdir -p $INSTALL/lib && cd $INSTALL/lib
for f in $(find $INSTALL/hsa/lib -name "libhsa*.so*"); do ln -s $f; done

cd $BUILD
git clone --depth 1 $GITHUB/ROCm-Device-Libs devlibs
mkdir -p devlibs/build && cd devlibs/build
CC=$LLVM_BUILD/bin/clang cmake -DCMAKE_BUILD_TYPE=Release \
	            -DCMAKE_INSTALL_PREFIX=$INSTALL/dlibs -DLLVM_DIR=$LLVM_BUILD ..
CC=$LLVM_BUILD/bin/clang make -j$THREADS
CC=$LLVM_BUILD/bin/clang make install

cd $BUILD
git clone --depth 1 --recursive -b clang_tot_upgrade https://github.com/RadeonOpenCompute/hcc
mkdir -p hcc/build && cd hcc/build

CC=$LLVM_BUILD/bin/clang cmake -DCMAKE_BUILD_TYPE=Release -DHSA_AMDGPU_GPU_TARGET=AMD:AMDGPU:7:0:1 \
	           -DROCM_DEVICE_LIB_DIR=$INSTALL/dlibs/lib -DCMAKE_INSTALL_PREFIX=$INSTALL/hcc \
		              -DHSA_HEADER_DIR=$INSTALL/include -DHSA_LIBRARY_DIR=$INSTALL/lib ..
CC=$LLVM_BUILD/bin/clang make -j$THREADS world
CC=$LLVM_BUILD/bin/clang make -j$THREADS
CC=$LLVM_BUILD/bin/clang make install

export PATH=/opt/rocm/hcc/bin:$PATH

mkdir -p $BUILD/test
cd $BUILD/test
wget https://gist.githubusercontent.com/scchan/540d410456e3e2682dbf018d3c179008/raw/f12152f8a79a577b1afb4454b849dae0f76a124d/saxpy.cpp
hcc `hcc-config --cxxflags --ldflags` saxpy.cpp -o saxpy
LD_LIBRARY_PATH=$INSTALL/lib ./saxpy
