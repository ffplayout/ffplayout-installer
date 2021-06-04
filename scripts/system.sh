#!/usr/bin/env bash

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

# get sure that we have our correct PATH
export PATH=$PATH:/usr/local/bin

if [[ ! $installNginx ]] && ! nginx -t &> /dev/null; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install and setup nginx:"
    echo "------------------------------------------------------------------------------"
    echo ""
    while true; do
        read -p "Do you wish to install nginx? (Y/n) :$ " yn
        case $yn in
            [Yy]* ) installNginx="y"; break;;
            [Nn]* ) installNginx="n"; break;;
            * ) (
                echo "------------------------------------"
                echo "Please answer yes or no!"
                echo ""
                );;
        esac
    done
fi

# check if system packages are installed and when not install them

echo ""
echo "------------------------------------------------------------------------------"
echo "install system packages"
echo "------------------------------------------------------------------------------"

if [[ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]]; then
    packages=(sudo curl wget net-tools git python3-dev build-essential virtualenv
              python3-virtualenv mediainfo autoconf automake libtool pkg-config
              yasm cmake mercurial gperf libssl-dev)
    installedPackages=$(dpkg --get-selections | awk '{print $1}' | tr '\n' ' ')
    apt update

    if [[ "$installedPackages" != *"curl"* ]]; then
        apt install -y curl
    fi

    if [[ "$installedPackages" != *"nodejs"* ]]; then
        curl -sL https://deb.nodesource.com/setup_14.x | bash -
        apt install -y nodejs
    fi

    for pkg in ${packages[@]}; do
        if [[ "$installedPackages" != *"$pkg"* ]]; then
            apt install -y $pkg
        fi
    done

    if [[ $installNginx == 'y' ]] && [[ "$installedPackages" != *"nginx"* ]]; then
        apt install -y nginx
        rm /etc/nginx/sites-enabled/default
    fi

    nginxConfig="/etc/nginx/sites-available"

elif [[ "$(grep -Ei 'centos|fedora' /etc/*release)" ]]; then
    packages=(libstdc++-static yasm mercurial libtool libmediainfo mediainfo
              cmake net-tools git python3 python36-devel wget python3-virtualenv
              gperf nano nodejs python3-policycoreutils policycoreutils-devel
              openssl-devel)
    installedPackages=$(dnf list --installed | awk '{print $1}' | tr '\n' ' ')
    activeRepos=$(dnf repolist enabled | awk '{print $1}' | tr '\n' ' ')

    if [[ "$activeRepos" != *"epel"* ]]; then
        dnf -y install epel-release
    fi

    if [[ "$activeRepos" != *"PowerTools"* ]]; then
        dnf -y config-manager --enable PowerTools
    fi

    if [[ "$activeRepos" != *"nodesource"* ]]; then
        curl -sL https://rpm.nodesource.com/setup_14.x | sudo -E bash -
    fi

    for pkg in ${packages[@]}; do
        if [[ "$installedPackages" != *"$pkg"* ]]; then
            dnf -y install $pkg
        fi
    done

    if [[ ! $(dnf group list  "Development Tools" | grep -i "install") ]]; then
        dnf -y group install "Development Tools"
    fi

    if [[ $installNginx == 'y' ]] && [[ "$installedPackages" != *"nginx"* ]]; then
        dnf -y install nginx
        systemctl enable nginx
        systemctl start nginx
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --zone=public --add-service=https
        firewall-cmd --reload
        mkdir /var/www
        chcon -vR system_u:object_r:httpd_sys_content_t:s0 /var/www
    fi

    if [[ $(alternatives --list | grep "no-python") ]]; then
        alternatives --set python /usr/bin/python3
    fi

    nginxConfig="/etc/nginx/conf.d"
else
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "your system is not know by this install script"
    echo "installation failed"
    echo "------------------------------------------------------------------------------"

    exit 1
fi
