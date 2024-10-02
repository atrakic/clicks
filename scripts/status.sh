#!/bin/bash

HERE=$(dirname $(readlink -f $0))
source $HERE/env.sh

echo ":: $(basename $0): Using dokku on $fqdn ($ip) ::"

$dokku apps:report $myapp
$dokku report $myapp output
