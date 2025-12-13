#!/usr/bin/env bash

# script must be run with VERSION set to a proper signal version

echo "###ci-build.sh###"
set -x

if [ "$1" == "amd64" ]; then
	ARCHSPECIFICVARIABLECOMMON="amd64"
	ARCHSPECIFICVARIABLESHORT="x64"
elif [ "$1" == "arm64" ]; then
	ARCHSPECIFICVARIABLECOMMON="arm64"
	ARCHSPECIFICVARIABLESHORT="arm64"
else
	echo "arch not set properly; exiting"
	exit 1
fi

NODE_VERSION=v22.21.1

if [[ $VERSION == "" || $NODE_VERSION == "" ]];then
    echo "Unset VERSION or NODE_VERSION, exiting."
    echo "VERSION: $VERSION NODE_VERSION: $NODE_VERSION"
    exit 1
fi

shopt -s localvar_inherit
podman create --name=signal-desktop-"$VERSION" --arch "$ARCHSPECIFICVARIABLECOMMON" -it ghcr.io/flatpaks/signalimage:latest bash
podman start signal-desktop-"$VERSION"

function podman_exec() {
    dir=$1
    shift 1
    podman exec -it -w $dir signal-desktop-"$VERSION" $@
    sleep 1
}

podman_exec / git clone -q https://github.com/signalapp/Signal-Desktop -b 7.82.x

podman_exec /opt/ wget -q https://nodejs.org/dist/"$NODE_VERSION"/node-"$NODE_VERSION"-linux-"$ARCHSPECIFICVARIABLESHORT".tar.gz
podman_exec /opt/ tar xf node-"$NODE_VERSION"-linux-"$ARCHSPECIFICVARIABLESHORT".tar.gz
podman_exec /opt/ mv node-"$NODE_VERSION"-linux-"$ARCHSPECIFICVARIABLESHORT" node

podman_exec /Signal-Desktop git-lfs install
podman_exec /Signal-Desktop git config --global user.name name
podman_exec /Signal-Desktop git config --global user.email name@example.com

#podman_exec /Signal-Desktop sed -r '/mock/d' -i package.json

podman_exec /Signal-Desktop npm install -g pnpm
podman_exec /Signal-Desktop npm install -g cross-env
podman_exec /Signal-Desktop npm install -g npm-run-all
podman_exec /Signal-Desktop pnpm install
podman_exec /Signal-Desktop rm -rf ts/test-mock
podman_exec /Signal-Desktop pnpm run generate

podman_exec /Signal-Desktop/sticker-creator pnpm install
podman_exec /Signal-Desktop/sticker-creator pnpm run build

podman_exec /Signal-Desktop pnpm run build:release --"$ARCHSPECIFICVARIABLESHORT" --linux

# copy .deb out of builder container
podman cp signal-desktop-"$VERSION":/Signal-Desktop/release/signal-desktop_"$VERSION"_"$ARCHSPECIFICVARIABLECOMMON".deb ~/signal-"$ARCHSPECIFICVARIABLECOMMON".deb
