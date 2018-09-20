#!/bin/bash

set -eu

# Need to be verified before changing to Zen...
if [[ "$OSTYPE" == "darwin"* ]]; then
    PARAMS_DIR="$HOME/Library/Application Support/ZeroParams"
else
    PARAMS_DIR="$HOME/.zero-params"
fi

SPROUT_PKEY_NAME='sprout-proving.key'
SPROUT_VKEY_NAME='sprout-verifying.key'
SPROUT_PKEY_URL="https://z.cash/downloads/$SPROUT_PKEY_NAME"
SPROUT_VKEY_URL="https://z.cash/downloads/$SPROUT_VKEY_NAME"

SHA256CMD="$(command -v sha256sum || echo shasum)"
SHA256ARGS="$(command -v sha256sum >/dev/null || echo '-a 256')"

function fetch_params {
    local url="$1"
    local output="$2"
    local dlname="${output}.dl"
    local expectedhash="$3"

    if ! [ -f "$output" ]; then
        echo "Retrieving: $url"
        if [[ $(sw_vers -productName) == "Mac OS X" ]]; then
            curl \
                --output "$dlname" \
                -# -L -C - \
                "$url"
        else
            wget \
                --progress=dot:giga \
                --output-document="$dlname" \
                --continue \
                --retry-connrefused --waitretry=3 --timeout=30 \
                "$url"
        fi

        "$SHA256CMD" $SHA256ARGS -c <<EOF
$expectedhash  $dlname
EOF

        # Check the exit code of the shasum command:
        CHECKSUM_RESULT=$?
        if [ $CHECKSUM_RESULT -eq 0 ]; then
            mv -v "$dlname" "$output"
        else
           echo "Failed to verify parameter checksums!"
           exit 1
        fi
    fi
}

# Use flock to prevent parallel execution.
function lock() {
    local lockfile=/tmp/fetch_params.lock
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if shlock -f ${lockfile} -p $$; then
            return 0
        else
            return 1
        fi
    else
        # create lock file
        eval "exec 200>/$lockfile"
        # acquire the lock
        flock -n 200 \
            && return 0 \
            || return 1
    fi
}

function exit_locked_error {
    echo "Only one instance of fetch-params.sh can be run at a time." >&2
    exit 1
}

function main() {

    lock fetch-params.sh \
    || exit_locked_error

    cat <<EOF
# Not changed to Zen because we're still using the Zero zcSNARK params
Zero - fetch-params.sh

This script will fetch the Zero zkSNARK parameters and verify their
integrity with sha256sum.

If they already exist locally, it will exit now and do nothing else.
EOF

    # Now create PARAMS_DIR and insert a README if necessary:
    if ! [ -d "$PARAMS_DIR" ]
    then
        mkdir -p "$PARAMS_DIR"
        README_PATH="$PARAMS_DIR/README"
        cat >> "$README_PATH" <<EOF
This directory stores common Zero zkSNARK parameters. Note that it is
distinct from the daemon's -datadir argument because the parameters are
large and may be shared across multiple distinct -datadir's such as when
setting up test networks.
EOF

        # This may be the first time the user's run this script, so give
        # them some info, especially about bandwidth usage:
        cat <<EOF
The parameters are currently just under 911MB in size, so plan accordingly
for your bandwidth constraints. If the files are already present and
have the correct sha256sum, no networking is used.

Creating params directory. For details about this directory, see:
$README_PATH

EOF
    fi

    cd "$PARAMS_DIR"

    fetch_params "$SPROUT_PKEY_URL" "$PARAMS_DIR/$SPROUT_PKEY_NAME" "8bc20a7f013b2b58970cddd2e7ea028975c88ae7ceb9259a5344a16bc2c0eef7"
    fetch_params "$SPROUT_VKEY_URL" "$PARAMS_DIR/$SPROUT_VKEY_NAME" "4bd498dae0aacfd8e98dc306338d017d9c08dd0918ead18172bd0aec2fc5df82"
}

main
rm -f /tmp/fetch_params.lock

if [ ! -f "$HOME/Library/Application Support/zero/zero.conf" ]; then
    echo "Creating zero.conf"
    mkdir -p ~/Library/Application\ Support/zero/
    USER=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "rpcuser=$USER" > ~/Library/Application\ Support/zero/zero.conf
    PASSWORD=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    echo "rpcpassword=$PASSWORD" >> ~/Library/Application\ Support/zero/zero.conf
    echo "rpcport=23800" >> ~/Library/Application\ Support/zero/zero.conf
    echo "port=23801" >> ~/Library/Application\ Support/zero/zero.conf
    echo "txindex=1" >> ~/Library/Application\ Support/zero/zero.conf
    echo "addnode=163.172.49.214" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=95.179.141.123" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=173.249.40.205" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=149.56.97.170" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=173.212.214.174" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=172.93.98.162" >> ~/Library/Application\ Support/zero/zero.conf
	echo "addnode=51.68.153.137" >> ~/Library/Application\ Support/zero/zero.conf
    echo "server=1" >> ~/Library/Application\ Support/zero/zero.conf
    echo "Complete!"
fi

exit 0
