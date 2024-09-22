#! /bin/bash
cd lib/bloom-v2
forge build
cd ../LayerZero-v2
yarn
yarn build
cd ../..
forge build