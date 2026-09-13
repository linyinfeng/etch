#!/bin/sh
set -eu

etch=${ETCH:-etch}
"$etch" tangle literate.typ --out build
NAME=${NAME:-world} sh build/greet.sh > build/out.txt
diff build/out.txt expected.txt
echo "the demo agrees with itself"
