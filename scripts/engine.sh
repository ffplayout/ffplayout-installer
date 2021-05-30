#!/usr/bin/env bash

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

versionEngine="v3.2.0"

if [[ ! -d "/opt/ffplayout_engine" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install ffplayout engine"
    echo "------------------------------------------------------------------------------"

    cd /opt
    wget https://github.com/ffplayout/ffplayout_engine/archive/${versionEngine}.tar.gz
    tar xf "${versionEngine}.tar.gz"
    mv "ffplayout_engine-${versionEngine#'v'}" 'ffplayout_engine'
    rm "${versionEngine}.tar.gz"
    cd ffplayout_engine

    virtualenv -p python3 venv
    source ./venv/bin/activate

    pip install -r requirements-base.txt

    mkdir /etc/ffplayout
    mkdir -p $mediaPath

    if [[ $setMultiChannel == 'y' ]]; then
        cp ffplayout.yml /etc/ffplayout/ffplayout-001.yml
        cp -r supervisor /etc/ffplayout/
        mkdir -p $playlistPath/channel-001

        mkdir -p /var/log/ffplayout/channel-001

        cp docs/ffplayout_engine-multichannel.service /etc/systemd/system/

        sed -i "s/User=root/User=$serviceUser/g" /etc/systemd/system/ffplayout_engine-multichannel.service
        sed -i "s/Group=root/Group=$serviceUser/g" /etc/systemd/system/ffplayout_engine-multichannel.service

        sed -i "s|\"\/playlists\"|\"$playlistPath/channel-001\"|g" /etc/ffplayout/ffplayout-001.yml
        sed -i "s|\"\/mediaStorage|\"$mediaPath|g" /etc/ffplayout/ffplayout-001.yml

        systemctl enable ffplayout_engine-multichannel.service
        systemctl start ffplayout_engine-multichannel.service
    else
        cp ffplayout.yml /etc/ffplayout/
        mkdir /var/log/ffplayout
        mkdir -p $playlistPath

        cp docs/ffplayout_engine.service /etc/systemd/system/

        sed -i "s/User=root/User=$serviceUser/g" /etc/systemd/system/ffplayout_engine.service
        sed -i "s/Group=root/Group=$serviceUser/g" /etc/systemd/system/ffplayout_engine.service

        sed -i "s|\"\/playlists\"|\"$playlistPath\"|g" /etc/ffplayout/ffplayout.yml
        sed -i "s|\"\/mediaStorage|\"$mediaPath|g" /etc/ffplayout/ffplayout.yml

        systemctl enable ffplayout_engine.service
    fi

    chown -R $serviceUser. /etc/ffplayout
    chown -R $serviceUser. /var/log/ffplayout
    chown $serviceUser. $mediaPath
    chown -R $serviceUser. $playlistPath

    deactivate
fi
