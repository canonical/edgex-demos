#!/bin/bash -ev

ADDON_SERVICE=device-simple

if [ -z $ADDON_SERVICE ]; then
    echo "Input not set."
    exit 1
fi

sudo snap set edgexfoundry app-options=true

ADD_SECRETSTORE_TOKENS=`sudo snap get edgexfoundry apps.security-secretstore-setup.config.add-secretstore-tokens`
echo $ADD_SECRETSTORE_TOKENS

if echo $ADD_SECRETSTORE_TOKENS | grep $ADDON_SERVICE; then
    echo -e "\nAddon service $ADDON_SERVICE is already set."
    echo "Skip to start secret store setup and copy token only."
else
    ADD_KNOWN_SECRETS=`sudo snap get edgexfoundry apps.security-secretstore-setup.config.add-known-secrets`
    echo $ADD_KNOWN_SECRETS

    ADD_REGISTRY_ACL_ROLES=`sudo snap get edgexfoundry apps.security-bootstrapper.config.add-registry-acl-roles`
    echo $ADD_REGISTRY_ACL_ROLES


    sudo snap set edgexfoundry apps.security-secretstore-setup.config.add-secretstore-tokens="$ADD_SECRETSTORE_TOKENS,$ADDON_SERVICE"
    sudo snap set edgexfoundry apps.security-secretstore-setup.config.add-known-secrets="$ADD_KNOWN_SECRETS,redisdb[$ADDON_SERVICE]"
    sudo snap set edgexfoundry apps.security-bootstrapper.config.add-registry-acl-roles="$ADD_REGISTRY_ACL_ROLES,$ADDON_SERVICE"
fi

sudo snap start edgexfoundry.security-secretstore-setup
sudo cp /var/snap/edgexfoundry/current/secrets/$ADDON_SERVICE/secrets-token.json device-service/
sudo chown $USER:$USER device-service/secrets-token.json
