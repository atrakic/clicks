#!/bin/bash

HERE=$(dirname $(readlink -f $0))
source $HERE/env.sh

echo ":: $(basename $0): Using dokku on $fqdn ($ip) ::"

git remote -v | grep -w dokku &>/dev/null || git remote add dokku dokku@"$fqdn":"$myapp"
git push dokku main
