# Description: Environment variables for the scripts
myapp=${1:-myapp}
your_cert_email=""  # your email address for letsencrypt
s3_backup_bucket="" # AWS s3 bucket for backups

fqdn=$(make -s -f ./infra/Makefile outputs | jq ".[].fqdn.value" | xargs)
ip=$(make -s -f ./infra/Makefile outputs | jq ".[].vmPublicIPAddress.value"| xargs)

_user="dokku"
_command="dokku"

dokku="ssh \
    -o LogLevel=ERROR \
    -o StrictHostKeychecking=no \
    -o UserKnownHostsFile=/dev/null \
    $_user@$fqdn $_command"
