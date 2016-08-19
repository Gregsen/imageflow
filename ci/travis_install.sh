#!/bin/bash

set -e #Exit on failure.
set -x

cd ${TRAVIS_BUILD_DIR}

if [[ "$(uname -s)" == 'Darwin' ]]; then
    brew update || brew update
    brew install cmake || true
    brew install conan
    brew install nasm
    ./ci/install_dssim.sh
else
    sudo docker pull ${DOCKER_IMAGE}
fi

