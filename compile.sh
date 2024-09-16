#! /bin/bash

cd lib/bloom-v2
forge build
cd ../../
forge build --sizes
# wake init pytypes
# wake compile 