#! /bin/bash

source .env

forge test -vvv

wake test ./tests/wake_testing --no-s