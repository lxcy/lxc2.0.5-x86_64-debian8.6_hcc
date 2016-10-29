#! /bin/bash

mkdir -p $HOME/tmp/cmake && cd $HOME/tmp/cmake
wget https://cmake.org/files/v3.7/cmake-3.7.0-rc2.tar.gz
tar xf cmake-3.7.0-rc2.tar.gz
cd cmake-3.7.0-rc2
./bootstrap
make -j$THREADS
make install
rm -rf $HOME/tmp/cmake
