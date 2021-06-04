#!/usr/bin/env bash

versionFrontend="v3.0.2"

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

if [[ ! -d "/var/www/ffplayout-frontend" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install ffplayout-frontend"
    echo "------------------------------------------------------------------------------"

    export NUXT_TELEMETRY_DISABLED=1

    cd /var/www

    if [[ $srcFromMaster == 'y' ]]; then
        git clone https://github.com/ffplayout/ffplayout-frontend.git
    else
        wget https://github.com/ffplayout/ffplayout-frontend/archive/${versionFrontend}.tar.gz
        tar xf "${versionFrontend}.tar.gz"
        mv "ffplayout-frontend-${versionFrontend#'v'}" 'ffplayout-frontend'
        rm "${versionFrontend}.tar.gz"
    fi

    ln -s "$mediaPath" /var/www/ffplayout-frontend/static/

    if [[ $useHTTPS == 'y' ]]; then
        proto='https'
    else
        proto='http'
    fi
cat <<EOF > "ffplayout-frontend/.env"
BASE_URL='${proto}://${domainName}'
API_URL='/'
EOF

    chown $serviceUser. -R /var/www

    cd ffplayout-frontend

    sudo -H -u $serviceUser bash -c 'npm install'
    sudo -H -u $serviceUser bash -c 'npm run build'

    if [[ ! -f "$nginxConfig/ffplayout.conf" ]]; then
        cp docs/ffplayout.conf "$nginxConfig/"

        origin=$(echo "$domainName" | sed 's/\./\\\\./g')

        sed -i "s/ffplayout.local/$domainName/g" $nginxConfig/ffplayout.conf
        sed -i "s/ffplayout\\\.local/$origin/g" $nginxConfig/ffplayout.conf

        if [[ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]]; then
            ln -s $nginxConfig/ffplayout.conf /etc/nginx/sites-enabled/
        fi
    fi

    systemctl reload nginx
fi
