#!/bin/bash

HERE=$(dirname $(readlink -f $0))
source $HERE/env.sh

echo ":: $(basename $0): Using dokku on $fqdn ($ip) ::"

curl -f -sL "$fqdn":8080/healthz || exit 1

echo

curl -f -sL "$fqdn":8080/version || exit 1
