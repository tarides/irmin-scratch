# +--------------------------------------------+
# | Name: Bench runner                         |
# +--------------------------------------------+
# | Author: Étienne Marais <etienne@maiste.fr> |
# | Version: 20220210                          |
# +--------------------------------------------+

# Option(s)

set -e

# Config(s)

git config --global user.email "tmp@example.com"
git config --global user.name "Tmp"

# Function(s)

check_and_set () {
  case $1 in
    "printbox.0.6") printf "Install printbox 0.6"; eval $(opam env) && opam install printbox.0.6 -y;;
    "printbox.0.5") printf "Install printbox 0.5"; eval $(opam env) && opam install printbox.0.5 -y;;
    *) printf "Nothing to install";;
  esac
}

patch_strategy () {
  case $1 in
     "patch-minimal") printf "Patch strategy\n" ; git cherry-pick 7e095f507cf680d1d9079a824e8a33978538f7ec;;
     *) printf "No strategy patch\n";; 
  esac
}

setup-and-run () {
    printf "\nSETUP_AND_RUN: -- START --\n"
    echo "Setting up for $SETUP_NAME/$TEST_SUFFIX that uses $IRMIN_REV / $INDEX_REV / $REPR_REV"
    (
    cd irmin;
    
    # Dry run
    opam exec -- dune exec -- ./bench/irmin-pack/tree.exe --mode trace --no-summary --empty-blobs --path-conversion=v0+v1 $TREE_FLAGS --artefacts "$ARTEFACTS_PREFIX/nope";
    
    # The real run
    opam exec --  dune exec -- ./bench/irmin-pack/tree.exe --mode trace --no-summary --keep-stat-trace $TREE_FLAGS --artefacts "$ARTEFACTS_PREFIX/$SETUP_NAME/$TEST_SUFFIX";
  )
  printf "\nSETUP_AND_RUN: -- END --\n\n"
}


# Exec

printf "+--------------------------------------------+\n"
printf "| Name: Bench runner                         |\n"
printf "+--------------------------------------------+\n"
printf "| Author: Étienne Marais <etienne@maiste.fr> |\n"
printf "| Version: 20220214                          |\n"
printf "+--------------------------------------------+\n\n"


printf "+---------- CLONING STAGE ----------+\n"
rm -rf irmin index repr
if test -f "irmin" ; then
  printf "Irmin already installed\n"
else
   git clone https://github.com/maiste/irmin.git
fi
if test -f "repr" ; then
  printf "Repr already install\n"
else
   git clone https://github.com/maiste/repr.git
fi
if test -f "index" ; then
  printf "Index already installed\n"
else
   git clone https://github.com/maiste/index.git
fi
printf "+------------------------------------+\n\n"


printf "+---------- CHECKOUT & INSTALL STAGE ----------+\n"
printf "SWITCH CREATE:\n"
opam switch remove bench-$1 -y || printf "No need to remove the switch\n"
opam switch create bench-$1 --empty -y
opam install ocaml.4.12.0 -y
check_and_set $2

eval $(opam env)
printf "\nREPR:\n"
cd repr
git checkout bench-$1
eval $(opam env)
opam pin add repr.dev . -y
opam pin add ppx_repr.dev . -y
cd ../

printf "\nINDEX:\n"
cd index
git checkout bench-$1
eval $(opam env)
opam pin add index.dev . -y --ignore-pin-depends
cd ../

printf "\nIRMIN:\n"
cd irmin
git remote add up https://github.com/mirage/irmin.git
git fetch up
git checkout origin/bench-$1
patch_strategy $3
eval $(opam env)
opam install . --deps-only -t --ignore-pin-depends -y
cd ../
printf "+------------------------------------+\n\n"


printf "+---------- EXPORT STAGE ----------+\n"
export ARTEFACTS_PREFIX="`pwd`/bench-$1"
printf "* ARTEFACTS_PREFIX: $ARTEFACTS_PREFIX\n"
export SETUP_NAME=benchmarks
printf "* SETUP_NAME: $SETUP_NAME\n"
export IRMIN_REV=bench-$1
printf "* IRMIN_REV: $IRMIN_REV\n"
export INDEX_REV=bench-$1
printf "* INDEX_REV: $INDEX_REV\n"
export REPR_REV=bench-$1
printf "* INDEX_REV: $INDEX_REV\n"
printf "+------------------------------------+\n\n"


printf "+---------- BENCH STAGE ----------+\n"
printf "200000 COMMITS: -- START --\n"
export TREE_FLAGS="/root/data5.repr --ncommits-trace 200000"
export TEST_SUFFIX='packet_a'
setup-and-run
export TEST_SUFFIX='packet_b'
setup-and-run
printf "200000 COMMITS: -- END --\n\n"

printf "FULL COMMITS: -- START --\n"
export TREE_FLAGS="/root/data5.repr --ncommits-trace 1343496"
export TEST_SUFFIX='packet_a_all'
setup-and-run
export TEST_SUFFIX='packet_b_all'
setup-and-run
printf "FULL COMMITS: -- END --\n"
printf "+------------------------------------+\n\n"
