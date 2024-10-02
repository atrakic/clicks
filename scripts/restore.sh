#!/bin/bash

HERE=$(dirname $(readlink -f $0))
source $HERE/env.sh

echo ":: $(basename "$0"): Using dokku on $fqdn ($ip) ::"

if [ -n "$s3_backup_bucket" ]; then
    echo ":: Using s3 bucket $s3_backup_bucket ::"
    $dokku litestream:restore /var/lib/dokku/data/storage/"$myapp" \
        production.sqlite3 s3://"$s3_backup_bucket"/"$myapp"/production.sqlite3
fi
