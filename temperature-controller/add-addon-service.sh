#!/bin/bash -ev

ADDON_SERVICE=$1

if [ -z $ADDON_SERVICE ]; then
    echo "Input not set."
    exit 1
fi


ADD_SECRETSTORE_TOKENS=`sudo snap get edgexfoundry apps.security-secretstore-setup.config.add-secretstore-tokens`
echo $ADD_SECRETSTORE_TOKENS

ADD_KNOWN_SECRETS=`sudo snap get edgexfoundry apps.security-secretstore-setup.config.add-known-secrets`
echo $ADD_KNOWN_SECRETS

ADD_REGISTRY_ACL_ROLES=`sudo snap get edgexfoundry apps.security-bootstrapper.config.add-registry-acl-roles`
echo $ADD_REGISTRY_ACL_ROLES


sudo snap set edgexfoundry apps.security-secretstore-setup.config.add-secretstore-tokens="$ADD_SECRETSTORE_TOKENS,$ADDON_SERVICE"
sudo snap set edgexfoundry apps.security-secretstore-setup.config.add-known-secrets="$ADD_KNOWN_SECRETS,redisdb[$ADDON_SERVICE]"
sudo snap set edgexfoundry apps.security-bootstrapper.config.add-registry-acl-roles="$ADD_REGISTRY_ACL_ROLES,$ADDON_SERVICE"

sudo snap start edgexfoundry.security-secretstore-setup
sudo cp /var/snap/edgexfoundry/current/secrets/$ADDON_SERVICE/secrets-token.json .
sudo chown $USER:$USER secrets-token.json
