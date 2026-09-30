# Immich — Syncloud app

Packages the [Immich](https://immich.app/) server and machine learning
(`immich-app/immich-server`, `immich-app/immich-machine-learning`) as a
Syncloud app.

## Build

    ./package.sh immich <build-number>

## Install on a device

    snap install --devmode ./immich_<version>_<arch>.snap
