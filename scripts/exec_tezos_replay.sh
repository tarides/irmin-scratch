#!/bin/sh

# +--------------------------------------------+
# | Name: Run Tezos Bench                      |
# +--------------------------------------------+
# | Author: Étienne Marais <etienne@maiste.fr> |
# | Version: 20220404                          |
# +--------------------------------------------+

# Option(s)

set -e

# Config(s)

git config --global user.email "tmp@example.com"
git config --global user.name "Tmp"

# Variable(s)

DEST="$HOME/$1"
SRC="$2"
BLOCK_COUNT="$3"

INDEX_BRANCH="$4"
REPR_BRANCH="$5"
IRMIN_BRANCH="$6"
TEZOS_BRANCH="$7"

SSH_COPY="$8"
RAM_RESERVED="$9"

TEZOS_INDEXING_STRATEGY="$10"
PROGRESS_VERSION="$11"

# Exec

printf "+--------------------------------------------+\n"
printf "| Name: Run Tezos Bench                      |\n"
printf "+--------------------------------------------+\n"
printf "| Author: Étienne Marais <etienne@maiste.fr> |\n"
printf "| Version: 20220404                          |\n"
printf "+--------------------------------------------+\n\n\n"


printf "+---------- CHECK STAGE ----------+\n"
if [ -e "$DEST" ] ; then
    printf "[X] Abort as %s already exists. It must be remove or another name should be chosen.\n" "$DEST"
    printf "+------------------------------------+\n\n"
    exit 1
else
    printf "[~] You can create the directory %s without issue\n" "$DEST"
fi
printf "+------------------------------------+\n\n"


printf "+---------- INSTALL TEZOS STAGE ----------+\n"

printf "[+] Source Cargo\n"
. "$HOME/.cargo/env"

printf "[~] Move in tezos/\n"
cd "$HOME/tezos"

printf "[~] Add sources\n"
git remote add samoht https://github.com/samoht/tezos.git
git remote add icristescu https://github.com/icristescu/tezos.git
git fetch --all

printf "[~] Switch tezos on branch %s\n" "$TEZOS_BRANCH"
git switch -f master
git switch -d "$TEZOS_BRANCH"

printf "[-] Remove _opam\n"
rm -rf _opam

printf "[+] Install tezos dependencies\n"
make build-deps

printf "[~] Move into home\n"
cd "$HOME"
printf "+------------------------------------+\n\n"


printf "+---------- INSTALL STAGE ----------+\n"

if [ ! -e "$HOME/repr" ]; then
    printf "[+] Cloning Repr in %s\n" "$PWD"
    git clone https://github.com/mirage/repr.git
fi

printf "[~] Move in repr/ and checkout on %s\n" "$REPR_BRANCH"
(
  cd repr;
  git switch -f main
  git switch -d "$REPR_BRANCH"
)

if [ ! -e "$HOME/index" ]; then
    printf "[+] Cloning Index in %s\n" "$PWD"
    git clone https://github.com/mirage/index.git
fi
printf "[~] Move in index/ and checkout on %s\n" "$INDEX_BRANCH"
(
  cd index;
  git switch -f main
  git switch -d "$INDEX_BRANCH"
)

if [ ! -e "$HOME/irmin" ] ; then
    printf "[+] Cloning Irmin in %s\n" "$PWD"
    git clone https://github.com/mirage/irmin.git
fi
printf "[~] Move in irmin/ and checkout on %s\n" "$IRMIN_BRANCH"
(
  cd irmin;
  git switch -f main
  git checkout -d "$IRMIN_BRANCH"
)

printf "[~] Move back to tezos/\n"
cd "$HOME/tezos"

printf "[~] Eval opam environment\n"
eval "$(opam env)"

printf "[+] Add opam default remote\n"
opam repo add default https://opam.ocaml.org

printf "[+] Install replay dependencies\n"
opam install printbox printbox-text rusage bentov ppx_deriving_yojson lru -y

printf "[-] Remove index, irmin, repr dependencies\n"
opam uninstall irmin index repr -y

if [ ! -e "$HOME/tezos/vendors/repr" ] ; then
    printf "[+] Link repr\n"
    ln -s "$HOME/repr" "$HOME/tezos/vendors/repr"
fi
if [ ! -e "$HOME/tezos/vendors/index" ] ; then
    printf "[+] Link index\n"
    ln -s "$HOME/index" "$HOME/tezos/vendors/index"
fi
if [ ! -e "$HOME/tezos/vendors/irmin" ]; then
    printf "[+] Link irmin\n"
    ln -s "$HOME/irmin" "$HOME/tezos/vendors/irmin"
fi



printf "[~] Eval opam environment\n"
eval "$(opam env)"

printf "[+] Build Lib_context\n"
dune build src/lib_context src/bin_context

printf "+------------------------------------+\n\n"


printf "+---------- SETUP REPLAY STAGE ----------+\n"

cd "$HOME"
printf "[~] Move to home\n"

if [ ! -e $DEST ] ; then
    mkdir -p "$DEST"
    printf "[+] Create the directory %s\n" "$DEST"
fi

INDEX_REV=$(cd "$HOME/index" ; git describe --always --dirty --broken)
printf "[+] Export index commit hash: %s\n" "$INDEX_REV"

REPR_REV=$(cd "$HOME/repr" ; git describe --always --dirty --broken)
printf "[+] Export repr commit hash: %s\n" "$REPR_REV"

IRMIN_REV=$(cd "$HOME/irmin" ; git describe --always --dirty --broken)
printf "[+] Export irmin commit hash: %s\n" "$IRMIN_REV"

TEZOS_REV=$(cd "$HOME/tezos" ; git describe --always --dirty --broken)
printf "[+] Export tezos commit hash: %s\n" "$TEZOS_REV"

STATS_TRACE_MESSAGE="\
\"name\":\"$1\", \
\"index\":\"$INDEX_REV\", \
\"repr\":\"$REPR_REV\", \
\"irmin\":\"$IRMIN_REV\", \
\"tezos\":\"$TEZOS_REV\""


if [ ! -z "$RAM_RESERVED" ] ; then
    if [ ! "$RAM_RESERVED" = "nope" ] ; then
        printf "[+] Introduce ram into the message\n"
        STATS_TRACE_MESSAGE="$STATS_TRACE_MESSAGE, \"ram_reserved\":\"$RAM_RESERVED\""
    fi
fi

STATS_TRACE_MESSAGE="{ $STATS_TRACE_MESSAGE }"
printf "[+] Raw message for stats trace: %s\n" "$STATS_TRACE_MESSAGE"
printf "[+] Export message for stats trace:"
printf "%s" "$STATS_TRACE_MESSAGE" | jq

export TEZOS_CONTEXT="v"
printf "[+] Export context as verbose\n"

if [ ! -z "$TEZOS_INDEXING_STRATEGY" ]; then
    if [ ! "$TEZOS_INDEXING_STRATEGY" = "nope" ]; then
        printf "[+] Indexing strategy set to %s\n" "$TEZOS_INDEXING_STRATEGY"
        TEZOS_INDEXING_STRATEGY="--indexing-strategy=$TEZOS_INDEXING_STRATEGY"
    fi
fi

if [ ! -z "$PROGRESS_VERSION" ]; then
    if [ ! "$PROGRESS_VERSION" = "nope" ]; then
        printf "[+] Progress pins to %s\n" "$PROGRESS_VERSION"
        opam pin add progress $PROGRESS_VERSION
    fi
fi
printf "+------------------------------------+\n\n"


printf "+---------- RUN REPLAY STAGE ----------+\n"

cd tezos
printf "[~] Move back to tezos\n"

printf "[~] Clear caches\n"
sync ; echo 3 > /proc/sys/vm/drop_caches

printf "[~] Eval opam environment\n"
eval "$(opam env)"

printf "[+] Execute src/bin_context/replay %s\n" "$SRC"
if [ -z "$RAM_RESERVED" ] ; then
    printf "[+] Run without systemd\n"
    dune exec -- ./src/bin_context/replay.exe \
            --no-summary \
            --keep-stats-trace \
            --keep-store \
            --startup-store-copy="$SRC/context" \
            $TEZOS_INDEXING_STRATEGY \
            --block-count="$BLOCK_COUNT" "$SRC/replay_trace.repr" "$DEST" 2>&1 | tee "$DEST/logs.txt"
else
    printf "[+] Run with systemd\n"
    systemd-run --user --scope -p MemoryMax=$RAM_RESERVED dune exec -- ./src/bin_context/replay.exe \
                --no-summary \
                --keep-stats-trace \
                --keep-store \
                --startup-store-copy="$SRC/context" \
                $TEZOS_INDEXING_STRATEGY \
                --block-count="$BLOCK_COUNT" "$SRC/replay_trace.repr" "$DEST" 2>&1 | tee "$DEST/logs.txt"
fi
printf "+------------------------------------+\n\n"


printf "+---------- SSH EXPORT STAGE ----------+\n"
if [ "$SSH_COPY" != ":" ] ; then
        tar cvzf "$DEST.tgz" "$DEST"
        printf "[+] Produce a tar file %s\n" "$DEST.tgz"
        scp "$DEST.tgz" $SSH_COPY
        printf "[+] File sent to %s\n" "$SSH_COPY"
        rm -rf "$DEST.tgz" "$DEST"
        printf "[-] Remove %s and %s\n" "$DEST.tgz" "$DEST"
else
    printf "[~] No result are going to be exported\n"
fi

printf "+------------------------------------+\n\n"
