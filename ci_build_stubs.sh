#!/bin/bash

CLI_ARGS=("$@")

GENERATOR_REPO="https://github.com/QuantConnect/quantconnect-stubs-generator"
GENERATOR_BRANCH="master"

RUNTIME_REPO="https://github.com/dotnet/runtime"
RUNTIME_BRANCH="master"

LEAN_DIR="$(pwd)"
LEAN_BIN_DIR="$LEAN_DIR/Launcher/bin/Release"
GENERATOR_DIR="$LEAN_BIN_DIR/quantconnect-stubs-generator"
RUNTIME_DIR="$LEAN_BIN_DIR/dotnet-runtime"
STUBS_DIR="$LEAN_BIN_DIR/generated-stubs"

# Change to "testpypi" to upload to https://test.pypi.org/
PYPI_REPO="testpypi"

function ensure_repo_up_to_date {
    if [ ! -d $3 ]; then
        git clone $1 $3
    fi

    cd $3
    git checkout $2
    git pull origin $2
}

function install_dotnet {
    wget https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb

    sudo apt update
    sudo apt install -y apt-transport-https
    sudo apt update
    sudo apt install -y dotnet-sdk-3.1
}

function install_twine {
    pip install -U twine
}

function generate_stubs {
    ensure_repo_up_to_date $GENERATOR_REPO $GENERATOR_BRANCH $GENERATOR_DIR
    ensure_repo_up_to_date $RUNTIME_REPO $RUNTIME_BRANCH $RUNTIME_DIR

    if [ -d $STUBS_DIR ]; then
        rm -rf $STUBS_DIR
    fi

    cd "$GENERATOR_DIR/QuantConnectStubsGenerator"

    # TODO: Change to STUBS_VERSION="$TRAVIS_TAG" when done debugging
    NO_DEBUG="true" \
    STUBS_VERSION="$TRAVIS_BUILD_NUMBER" \
    dotnet run $LEAN_DIR $RUNTIME_DIR $STUBS_DIR

    if [ $? -ne 0 ]; then
        echo "Generation of stubs failed"
        exit 1
    fi
}

function publish_stubs {
    # Requires the PYPI_API_TOKEN environment variable to be set
    # This API token should be valid for the current $PYPI_REPO and should include the "pypi-" prefix

    cd $STUBS_DIR
    python setup.py sdist bdist_wheel

    TWINE_USERNAME="__token__" \
    TWINE_PASSWORD="$PYPI_API_TOKEN" \
    TWINE_REPOSITORY="$PYPI_REPO" \
    twine upload "$STUBS_DIR/dist/*"

    if [ $? -ne 0 ]; then
        echo "PyPi publishing failed"
        exit 1
    fi
}

if [[ " ${CLI_ARGS[@]} " =~ " -h " ]]; then
    echo "STUBS GENERATOR (Debian distros only)"
    echo "  -d: Install .NET Core"
    echo "  -t: Install Twine"
    echo "  -g: Generate new stubs"
    echo "  -p: Push new stubs to PyPi"
    exit 0
fi

# TODO: Enable this when done debugging
# if [[ "$TRAVIS_TAG" != "" ]]; then
#     exit 0
# fi

if [[ " ${CLI_ARGS[@]} " =~ " -d " ]]; then
    install_dotnet
fi

if [[ " ${CLI_ARGS[@]} " =~ " -t " ]]; then
    install_twine
fi

if [[ " ${CLI_ARGS[@]} " =~ " -g " ]]; then
    generate_stubs
fi

if [[ " ${CLI_ARGS[@]} " =~ " -p " ]]; then
    publish_stubs
fi
