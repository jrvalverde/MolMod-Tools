#!/bin/bash

DIR=`dirname $0`
LIB="lib"
echo "Call path =" $DIR
echo "Library path =" $DIR/$LIB/
. $DIR/$LIB/gmx_library.bash
echo $COMMON

