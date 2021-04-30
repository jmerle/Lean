#!/bin/bash

CLI_ARGS=("$@")

GENERATOR_REPO="https://github.com/QuantConnect/quantconnect-stubs-generator"
GENERATOR_BRANCH="master"

RUNTIME_REPO="https://github.com/dotnet/runtime"
RUNTIME_BRANCH="master"

LEAN_DIR="$(pwd)"
# LEAN_BIN_DIR="$LEAN_DIR/Launcher/bin/Release"
LEAN_BIN_DIR="$LEAN_DIR/Launcher/bin/Debug"
GENERATOR_DIR="$LEAN_BIN_DIR/quantconnect-stubs-generator"
RUNTIME_DIR="$LEAN_BIN_DIR/dotnet-runtime"
STUBS_DIR="$LEAN_BIN_DIR/generated-stubs"

mkdir -p "$LEAN_BIN_DIR"

# Change to "testpypi" to upload to https://test.pypi.org/
# If you do this, know that PyPI and TestPyPI require different API tokens
# PYPI_REPO="pypi"
PYPI_REPO="testpypi"

function ensure_repo_up_to_date {
    if [ ! -d $3 ]; then
        git clone $1 $3
    fi

    cd $3
    git checkout $2
    git pull origin $2
}

function install_twine {
    # pip install -U twine -q
    pip install -U twine
}

function generate_stubs {
    ensure_repo_up_to_date $GENERATOR_REPO $GENERATOR_BRANCH $GENERATOR_DIR
    ensure_repo_up_to_date $RUNTIME_REPO $RUNTIME_BRANCH $RUNTIME_DIR

    if [ -d $STUBS_DIR ]; then
        rm -rf $STUBS_DIR
    fi

    cd "$GENERATOR_DIR/QuantConnectStubsGenerator"

    STUBS_VERSION="${GITHUB_REF#refs/tags/}" \
    dotnet run $LEAN_DIR $RUNTIME_DIR $STUBS_DIR
    # dotnet run -v q $LEAN_DIR $RUNTIME_DIR $STUBS_DIR

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
    # python setup.py --quiet sdist bdist_wheel

    TWINE_USERNAME="__token__" \
    TWINE_PASSWORD="$PYPI_API_TOKEN" \
    TWINE_REPOSITORY="$PYPI_REPO" \
    twine upload "$STUBS_DIR/dist/*"
    # twine upload "$STUBS_DIR/dist/*" > /dev/null

    if [ $? -ne 0 ]; then
        echo "PyPI publishing failed"
        exit 1
    fi
}

if [[ " ${CLI_ARGS[@]} " =~ " -h " ]]; then
    echo "STUBS GENERATOR (Debian distros only)"
    echo "  -t: Install Twine"
    echo "  -g: Generate new stubs"
    echo "  -p: Publish new stubs to PyPI"
    exit 0
fi

echo "GITHUB_REF: $GITHUB_REF"

if [[ ! "$GITHUB_REF" =~ "refs/tags/*" ]]; then
    echo "Exiting, no tag set"
    exit 0
fi

if [[ " ${CLI_ARGS[@]} " =~ " -t " ]]; then
    echo "Installing Twine"
    install_twine
fi

if [[ " ${CLI_ARGS[@]} " =~ " -g " ]]; then
    echo "Generating new stubs"
    generate_stubs
fi

if [[ " ${CLI_ARGS[@]} " =~ " -p " ]]; then
    echo "Publishing new stubs"
    publish_stubs
fi

echo "Done"
