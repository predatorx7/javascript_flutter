#!/usr/bin/env bash

# change current directory to script's directory
cd "$(dirname "$0")"

rm -rf quickjs;
git clone https://github.com/bellard/quickjs;
cd quickjs;
git rev-parse HEAD > ../revision;
rm -rf .git;
