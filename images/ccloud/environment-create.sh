#!/bin/sh

ccloud login > /dev/null 2>&1
ccloud environment create "$@"

