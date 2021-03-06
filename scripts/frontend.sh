#!/usr/bin/env bash

versionFrontend="v3.1.0"

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

if [[ ! -d "/var/www/ffplayout-frontend" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install ffplayout-frontend"
    echo "------------------------------------------------------------------------------"

    cd /var/www

    if [[ $srcFromMaster == 'y' ]]; then
        git clone https://github.com/ffplayout/ffplayout-frontend.git
    else
        wget https://github.com/ffplayout/ffplayout-frontend/archive/${versionFrontend}.tar.gz
        tar xf "${versionFrontend}.tar.gz"
        mv "ffplayout-frontend-${versionFrontend#'v'}" 'ffplayout-frontend'
        rm "${versionFrontend}.tar.gz"

        echo $versionFrontend > ffplayout-frontend/.version
    fi

    ln -s "$mediaPath" /var/www/ffplayout-frontend/static/

    if [[ $useHTTPS == 'y' ]]; then
        proto='https'
    else
        proto='http'
    fi
cat <<EOF > "ffplayout-frontend/.env"
NUXT_TELEMETRY_DISABLED=1
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
elif [[ $update ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "update ffplayout-frontend"
    echo "------------------------------------------------------------------------------"

    cd /var/www

    if [[ $srcFromMaster == 'y' ]]; then
        cd ffplayout-frontend
        git fetch

        if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]; then
            echo "------------------------------------------------------------------------------"
            echo "ffplayout-frontend is up to date"
            echo "------------------------------------------------------------------------------"
            return
        fi

        git pull
    else
        if [[ $versionFrontend == $(cat ffplayout-frontend/.version) ]]; then
            echo "------------------------------------------------------------------------------"
            echo "ffplayout-frontend is up to date"
            echo "------------------------------------------------------------------------------"
            return
        else
            echo $versionFrontend > ffplayout-frontend/.version
        fi
        mv ffplayout-frontend/.env .

        wget https://github.com/ffplayout/ffplayout-frontend/archive/${versionFrontend}.tar.gz
        tar xf "${versionFrontend}.tar.gz"
        yes | cp -rf ffplayout-frontend-${versionFrontend#'v'}/* ffplayout-frontend/
        rm "${versionFrontend}.tar.gz"

        mv .env ffplayout-frontend/
        cd ffplayout-frontend
    fi

    chown $serviceUser. -R /var/www/ffplayout-frontend
    sudo -H -u $serviceUser bash -c 'npm install'
    sudo -H -u $serviceUser bash -c 'npm run build'
fi
