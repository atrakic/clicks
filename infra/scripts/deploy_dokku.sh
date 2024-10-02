DOKKU_VERSION=$1
wget https://raw.githubusercontent.com/dokku/dokku/v${DOKKU_VERSION}/bootstrap.sh
sudo DOKKU_TAG=v${DOKKU_VERSION} bash bootstrap.sh
sudo dokku plugin:install https://github.com/axelthegerman/dokku-litestream litestream
sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
