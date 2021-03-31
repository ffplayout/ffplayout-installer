#!/usr/bin/env bash

# app versions (master is to unstable)
versionApi="v3.0.0-rc2"

timeZone=$(cat /etc/timezone)

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

if [[ ! -d "/var/www/ffplayout-api" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install ffplayout-api"
    echo "------------------------------------------------------------------------------"

    cd /var/www
    wget https://github.com/ffplayout/ffplayout-api/archive/${versionApi}.tar.gz
    tar xf "${versionApi}.tar.gz"
    mv "ffplayout-api-${versionApi#'v'}" 'ffplayout-api'
    rm "${versionApi}.tar.gz"
    cd ffplayout-api

    virtualenv -p python3 venv
    source ./venv/bin/activate

    pip install -r requirements-base.txt

    cd ffplayout

    secret=$(python -c 'import re;from random import choice; import sys; from django.core.management import utils; sys.stdout.write(re.escape(utils.get_random_secret_key()))')

    sed -i "s/---a-very-important-secret-key-_-generate-it-new---/$secret/g" ffplayout/settings/production.py
    sed -i "s/'localhost'/'localhost', \'$domainName\'/g" ffplayout/settings/production.py
    sed -i "s/ffplayout\\.local/$domainName\'\n    \'https\\:\/\/$domainName/g" ffplayout/settings/production.py
    sed -i "s|TIME_ZONE = 'UTC'|TIME_ZONE = '$timeZone'|g" ffplayout/settings/common.py
    sed -i "s/localhost/$domainName/g" ../docs/db_data.json

    if [[ $setMultiChannel == 'y' ]]; then
        sed -i "s|USE_SOCKET = False|USE_SOCKET = True|g" ffplayout/settings/common.py
    else

        sed -i "s/ffplayout-001.yml/ffplayout.yml/g" ../docs/db_data.json
        sed -i "s|/etc/ffplayout/supervisor/conf.d/engine-001.conf||g" ../docs/db_data.json

        sed -i "s|USE_SOCKET = True|USE_SOCKET = False|g" ffplayout/settings/common.py
    fi

    python manage.py makemigrations && python manage.py migrate
    python manage.py collectstatic
    python manage.py loaddata ../docs/db_data.json
    python manage.py createsuperuser

    deactivate

    chown $serviceUser. -R /var/www/ffplayout-api

    cd /var/www/ffplayout-api

    cp docs/ffplayout-api.service /etc/systemd/system/

    sed -i "s/User=root/User=$serviceUser/g" /etc/systemd/system/ffplayout-api.service
    sed -i "s/Group=root/Group=$serviceUser/g" /etc/systemd/system/ffplayout-api.service

    systemctl enable ffplayout-api.service
    systemctl start ffplayout-api.service
fi
