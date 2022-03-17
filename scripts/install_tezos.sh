# +--------------------------------------------+
# | Name: Install Tezos Deps                   |
# +--------------------------------------------+
# | Author: Étienne Marais <etienne@maiste.fr> |
# | Version: 20220215                          |
# +--------------------------------------------+

# Option(s)

set -e

# Config(s)

git config --global user.email "tmp@example.com"
git config --global user.name "Tmp"

# Exec

printf "+--------------------------------------------+\n"
printf "| Name: Install Tezos Deps                   |\n"
printf "+--------------------------------------------+\n"
printf "| Author: Étienne Marais <etienne@maiste.fr> |\n"
printf "| Version: 20220215                          |\n"
printf "+--------------------------------------------+\n\n"


printf "+---------- SETUP STAGE ----------+\n"
printf "INSTALL APT PACKAGES\n"
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y rsync git m4 build-essential bubblewrap \
                    patch unzip wget pkg-config libgmp-dev \
                    libev-dev libhidapi-dev libffi-dev jq \
                    zlib1g-dev bc autoconf cargo

printf "INSTALL OPAM\n"
if test -e "$HOME/.opam" ; then
    printf "opam is already installed\n"
else
    opam init -y --bare
fi

printf "INSTALL RUST\n"
if test -e "$HOME/.cargo"; then
    printf "Cargo is already installed\n"
else
    wget https://sh.rustup.rs/rustup-init.sh
    chmod +x rustup-init.sh
    ./rustup-init.sh --profile minimal --default-toolchain 1.52.1 -y
    . $HOME/.cargo/env
    echo "source $HOME/.cargo/env" >> .bashrc
fi

if test -e "$HOME/.zcash-params" ; then
    printf "zcash already installed\n"
else
    curl https://raw.githubusercontent.com/zcash/zcash/master/zcutil/fetch-params.sh | bash
fi

printf "CLONE TEZOS\n"
if test -e $HOME/tezos ; then
    printf "Tezos is already installed\n"
else
    printf "need to clone tezos\n"
    git clone https://github.com/maiste/tezos.git
fi
printf "+------------------------------------+\n\n"



