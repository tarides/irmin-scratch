#!/bin/sh

# +--------------------------------------------+
# | Name: Generate lock file Irmin             |
# +--------------------------------------------+
# | Author: Étienne Marais <etienne@maiste.fr> |
# | Version: 20220223                          |
# +--------------------------------------------+

# Variable(s)

set -e

BRANCH="$1"
HASH_INDEX="$2"
HASH_REPR="$3"
HASH_TEZOS_CONTEXT_HASH="$4"

# Exec

git checkout $BRANCH

printf "[-] Rm duniverse and previous lock file\n"
rm -rf duniverse irmin.opam.locked

printf "[+] Opam monorepo lock\n"
opam monorepo lock

printf "[~] Repr: %s\n[~] Index: %s\n" "$HASH_REPR" "$HASH_INDEX"
sed -i \
    -e "s;/mirage/\(repr#\)\w\{40\};/maiste/\1${HASH_REPR};" \
    -e "s;/mirage/\(index#\)\w\{40\};/maiste/\1${HASH_INDEX};" \
    irmin.opam.locked

if [ ! -z "$HASH_TEZOS_CONTEXT_HASH" ] && [ "$HASH_TEZOS_CONTEXT_HASH" != "nope" ] ; then
    printf "[~] Tezos-context-hash add to deps: %s\n" "$HASH_TEZOS_CONTEXT_HASH"
    TEZOS_CONTEXT_HASH_DEV='"tezos-context-hash" {= "dev"}\n  "tezos-context-hash-irmin" {= "dev"}\n'
    sed -i \
        -e "s@\(\"zarith\" {= \".*\"}$\)@\1\n  ${TEZOS_CONTEXT_HASH_DEV}@" \
        irmin.opam.locked

    printf "[~] Alter pin deps\n"
    sed -i \
        -e "N;N;s@\(\]\nx-opam-monorepo-duniverse-dirs: \[\)@  [\n    \"tezos-context-hash.dev\"\n    \"git+https://github.com/tarides/tezos-context-hash#${HASH_TEZOS_CONTEXT_HASH}\"\n  ]\n  [\n    \"tezos-context-hash-irmin.dev\"\n    \"git+https://github.com/tarides/tezos-context-hash#${HASH_TEZOS_CONTEXT_HASH}\"\n  ]\n\1@" \
      irmin.opam.locked

printf "[~] Alter links\n"
sed -i \
    -e "N;s@\(\]\nx-opam-monorepo-root-packages: \[\)@  [\n    \"git+https://github.com/tarides/tezos-context-hash#${HASH_TEZOS_CONTEXT_HASH}\"\n    \"tezos-context-hash\"\n  ]\n  [\n    \"git+https://github.com/tarides/tezos-context-hash#${HASH_TEZOS_CONTEXT_HASH}\"\n    \"tezos-context-hash-irmin\"\n  ]\n\1@" \
    irmin.opam.locked

fi

opam monorepo pull
dune clean && dune build .
dune exec -- ./bench/irmin-pack/tree.exe --help

