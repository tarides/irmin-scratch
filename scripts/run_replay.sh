#!/bin/sh

# +--------------------------------------------+
# | Name: Run Tezos Replays                    |
# +--------------------------------------------+
# | Author: Étienne Marais <etienne@maiste.fr> |
# | Version: 20220317                          |
# +--------------------------------------------+

# Variable(s)

set -e

SSH_ADDR="$1"
SSH_PATH="$2"
SSH_COPY="$1:$2"

# Function(s)

check_ssh () {
    printf "[~] Check connection to %s\n" "$1"
    ssh -q -o BatchMode=yes  -o StrictHostKeyChecking=no -o ConnectTimeout=5 $1 'exit 0'
    if [ $? = 0 ]; then
        printf "[~] Ssh connection up and ready\n"
    else
        printf "[ERROR] Ssh connection failed...\n"
        exit 1;
    fi
}

exec_one_replay () {
    cd $HOME
    $HOME/exec_tezos_replay.sh $1 $2 $3 $4 $5 $6 $7 $8 $9 "$10"
}

# Move to HOME
cd $HOME

# Ensure we have the trace and the store
printf "+---------- DOWNLOAD HANGZOU REPLAY TRACE STAGE ----------+\n"
if [ ! -e hangzou-level2 ] ; then
    printf "[+] Download and extract context with replay\n"
    wget -c http://data.tarides.com/lib_context/hangzou-level2.tgz -O - | tar -xz
else
    printf "[~] Trace already exists, no need to download\n"
fi
printf "+------------------------------------+\n\n"

printf "+---------- DOWNLOAD HANGZOU REPLAY TRACE STAGE FOR 2.10 ----------+\n"
if [ ! -e hangzou-level2-210 ] ; then
    printf "[+] Download and extract context with replay\n"
    wget -c http://data.tarides.com/lib_context/hangzou-level2-210.tgz -O - | tar -xz
else
    printf "[~] Trace already exists, no need to download\n"
fi
printf "+------------------------------------+\n\n"

# Ensure SSH is on if required
if [ ! -z $SSH_ADDR ] ; then
    check_ssh "$SSH_ADDR"
else
    printf "[~] No Backup to an Ssh address\n"
fi

# Add the replay to run with
# exec_one_replay [export-name] [source] [block-count] \
#                 [index-branch] [repr-branch] [irmin-branch] [tezos-branch] \
#                 <user@host:/path/to/store> <sizeG>
BLOCK="145000"
SRC="$HOME/hangzou-level2"
exec_one_replay irmin-3-minimal $SRC $BLOCK \
    "c05846f784a3f4db11f1d113fc5a2c1fa8b743c6" "00858ff36107b41880269b240262e5e9d4724687" \
    "dbe98b1f2681d506b53cd0f6cdf62dfe6ae19275" "2b71f109467d0fc8982e61563643ccae9ebfa76c" \
    $SSH_COPY "8G" "minimal" 
exec_one_replay irmin-3-contents $SRC $BLOCK \
    "c05846f784a3f4db11f1d113fc5a2c1fa8b743c6" "00858ff36107b41880269b240262e5e9d4724687" \
    "dbe98b1f2681d506b53cd0f6cdf62dfe6ae19275" "2b71f109467d0fc8982e61563643ccae9ebfa76c" \
    $SSH_COPY "8G" "contents" 
exec_one_replay irmin-3-always $SRC $BLOCK \
    "c05846f784a3f4db11f1d113fc5a2c1fa8b743c6" "00858ff36107b41880269b240262e5e9d4724687" \
    "dbe98b1f2681d506b53cd0f6cdf62dfe6ae19275" "2b71f109467d0fc8982e61563643ccae9ebfa76c" \
    $SSH_COPY "8G" "always"

SRC="$HOME/hangzou-level2-210"
exec_one_replay irmin-2 $SRC $BLOCK \
    "98c9315c1116215aa7792544c0fe7bdc764f084d" "eb53a14928eeaa70e80402380481add5bd7911be" \
    "0afd5de5e8cdd039d2898b136fbb04d3e76e4d1c" "98a5ff41622cbeb5883a107950b4e9dfaa6606ae" \
    $SSH_COPY "8G"
