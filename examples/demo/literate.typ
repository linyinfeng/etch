#import "../../package/lib.typ": chunk, file, show-rule, tangle-options

#show: show-rule

= A greeting, in two files

One preamble, two files, and one message that is written below the file that uses it.

#file("lib.sh", ```sh
#!/bin/sh
<<the preamble>>

greet() {
  printf '%s\n' "$1"
}
```)

#file("greet.sh", ```sh
#!/bin/sh
<<the preamble>>
. "$(dirname "$0")/lib.sh"

<<the message>>
```)

= The preamble, and the message

Both files need the same two lines, and this is where they are written — below the files that use them, which
is the whole point of the exercise: the order here is the order of an explanation, not the order `sh` needs.

#chunk("the preamble", ```sh
set -eu
: "${NAME:=world}"
```)

The message is a fragment like the preamble, and `greet.sh` uses it as a whole line, because a reference is a
whole line and nothing smaller:

#chunk("the message", ```sh
greet "hello, $NAME"
```)
