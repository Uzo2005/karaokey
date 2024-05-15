#!/bin/bash

# Reset current server state. Useful in devmode.
set -xe

cd fileBucket/
rm -rf *
rm -rf .*
cd ..
rm -f updates.db
nim r --hints:off db_utils.nim 
