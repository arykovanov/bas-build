#!/bin/bash
# Compile Mako Server as follows:
#  wget -O - https://raw.githubusercontent.com/RealTimeLogic/BAS/main/LinuxBuild.sh | bash
# Details: https://github.com/RealTimeLogic/BAS


function abort() {
    printf "$1\n\n";
    exit 1;
}

function install() {
    abort "Run the following prior to running this script:\nsudo apt-get install git zip unzip gcc make"
}

executables="git zip unzip gcc make"

for i in $executables; do
    if ! command -v $i &> /dev/null; then
        install
        exit 1
    fi
done


unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     XLIB=-ldl;XCFLAGS=-DLUA_USE_LINUX;machine=Linux;export EPOLL=TRUE;;
    Darwin*)    machine=Mac;;
    CYGWIN*)    XLIB=-ldl;XCFLAGS="-DLUA_USE_LINUX -DUSE_FORKPTY=0";machine=Cygwin;;
#    MINGW*)     machine=MinGw;;
    *)          abort "Unknown machine ${unameOut}"
esac

if [  -z ${CC+x} ]; then
    command -v gcc >/dev/null 2>&1 || install
    CC=gcc
    echo "Setting default compiler"
fi
echo "Using compiler $CC"

if [ -f src/BAS.c ]; then
    abort "Incorrect use! This script should not be run in the BAS directory.\nDetails: https://github.com/RealTimeLogic/BAS"
fi

if [ -n "$SQLITEURL" ]; then
    # if SQLITEURL url set
    # There is no 'latest' with SQLite :-(
	SQLITEURL="https://www.sqlite.org/2025/sqlite-amalgamation-3490100.zip"
    SQLITE=${SQLITEURL##*/}
    pushd /tmp || abort $LINENO
    echo "Downloading: $SQLITEURL"
    command -v wget >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        wget --no-check-certificate $SQLITEURL || abort $LINENO
    else
        curl $SQLITEURL -o $SQLITE
    fi
    unzip -o $SQLITE || abort $LINENO
    popd
    mv /tmp/${SQLITE%.zip}/* src/ || abort $LINENO
else
    SQLITE=${PWD}/$(ls sqlite-*.zip 2>/dev/null | head -n 1)
    cp sqlite/* ${PWD}/BAS/src/ || abort $LINENO
fi

cd BAS || abort $LINENO
if [ -n "${NOCOMPILE+set}" ]; then
    exit 0
fi

MinifyMakoZip=no make -f mako.mk || abort $LINENO

echo "Done"
echo "You may now run BAS/mako"
MAKO=BAS/mako

cd ..
