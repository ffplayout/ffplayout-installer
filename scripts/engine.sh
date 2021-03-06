#!/usr/bin/env bash

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

versionEngine="v3.4.0"

if [[ ! -d "/opt/ffplayout_engine" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install ffplayout engine"
    echo "------------------------------------------------------------------------------"

    cd /opt

    if [[ $srcFromMaster == 'y' ]]; then
        git clone https://github.com/ffplayout/ffplayout_engine.git
    else
        wget https://github.com/ffplayout/ffplayout_engine/archive/${versionEngine}.tar.gz
        tar xf "${versionEngine}.tar.gz"
        mv "ffplayout_engine-${versionEngine#'v'}" 'ffplayout_engine'
        rm "${versionEngine}.tar.gz"

        echo $versionEngine > ffplayout_engine/.version
    fi

    cd ffplayout_engine

    virtualenv -p python3 venv
    source ./venv/bin/activate

    pip install -r requirements-base.txt

    mkdir /etc/ffplayout
    mkdir -p $mediaPath

    if [[ $setMultiChannel == 'y' ]]; then
        cp ffplayout.yml /etc/ffplayout/ffplayout-001.yml
        cp -r docs/supervisor /etc/ffplayout/
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
elif [[ $update ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "update ffplayout engine"
    echo "------------------------------------------------------------------------------"

    cd /opt

    if [[ $srcFromMaster == 'y' ]]; then
        cd ffplayout_engine
        git fetch

        if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]; then
            echo "------------------------------------------------------------------------------"
            echo "ffplayout engine is up to date"
            echo "------------------------------------------------------------------------------"
            return
        fi

        git pull
    else
        if [[ $versionEngine == $(cat ffplayout_engine/.version) ]]; then
            echo "------------------------------------------------------------------------------"
            echo "ffplayout engine is up to date"
            echo "------------------------------------------------------------------------------"
            return
        else
            echo $versionEngine > ffplayout_engine/.version
        fi

        wget https://github.com/ffplayout/ffplayout_engine/archive/${versionEngine}.tar.gz
        tar xf "${versionEngine}.tar.gz"
        yes | cp -rf ffplayout_engine-${versionEngine#'v'}/* ffplayout_engine/
        rm "${versionEngine}.tar.gz"

        cd ffplayout_engine
    fi

    source ./venv/bin/activate
    pip install --upgrade -r requirements-base.txt

    deactivate

    echo ""
    echo "------------------------------------------------------------------------------"
    echo "When your engine was running, you have to restart it now!"
    echo "------------------------------------------------------------------------------"
fi
