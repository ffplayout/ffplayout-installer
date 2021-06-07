#!/usr/bin/env bash

while [[ $# -gt 0 ]] && [[ "$1" == "--"* ]]; do
    opt="$1";
    shift;
    case "$opt" in
        --domain=* )
           domainName="${opt#*=}";;
        --nginx=* )
           installNginx="${opt#*=}";;
        --https* )
           useHTTPS="${opt#*=}";;
        --ffmpeg=* )
           compileFFmpeg="${opt#*=}";;
        --srs=* )
           compileSRS="${opt#*=}";;
        --media=* )
           mediaPath="${opt#*=}";;
        --playlist=* )
           playlistPath="${opt#*=}";;
        --channels=* )
           setMultiChannel="${opt#*=}";;
        --master=* )
           srcFromMaster="${opt#*=}";;
        --user=* )
           username="${opt#*=}";;
        --password=* )
           password="${opt#*=}";;
        --help )
           showHelp=true;;
        *);;
   esac
done

if [[ $showHelp ]]; then
    echo "-------------------------------------------------------------"
    echo "ffplayout installer, run with parameters:"
    echo
    echo '--domain=[domain name] # add domain or IP'
    echo '--https=[y/n]          # use https'
    echo '--ffmpeg=[y/n]         # compile ffmpeg'
    echo '--srs=[y/n]            # compile srs rtmp server'
    echo '--media=[path]         # path to media store'
    echo '--playlist=[path]      # path to playlist store'
    echo '--channels=[y/n]       # use single or multiple channels'
    echo '--master=[y/n]         # get sources from master branch'
    echo '--user=[username]      # set user for authentication'
    echo '--password=[password]  # set password for authentication'

    exit 0
fi

if [[ -d .git ]] && [[ ! $srcFromMaster ]]; then
    echo "-------------------------------------------------------------"
    echo "WARNING: you are running the installer from git master branch!"
    echo "This version pulls all ffplayout tools also from there master branches,"
    echo "which can be instable and is not recomment in production!"
    echo ""
    echo "Are you sure that you want to continue?"

    while true; do
        read -p "Contiune? (Y/n) :$ " yn
        case $yn in
            [Yy]* ) srcFromMaster="y"; break;;
            [Nn]* ) exit;;
            * ) (
                echo "------------------------------------"
                echo "Please answer yes or no!"
                echo ""
                );;
        esac
    done
fi

exit

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

if [[ "$(grep -Ei 'centos|fedora' /etc/*release)" ]]; then
    serviceUser="nginx"
else
    serviceUser="www-data"
fi

# get sure that we have our correct PATH
export PATH=$PATH:/usr/local/bin

CURRENTPATH=$PWD

if [[ ! $domainName ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "ffplayout domain name (like: example.org), or IP"
    echo "------------------------------------------------------------------------------"
    echo ""

    while true; do
        read -p "domain name :$ " domainName

        if [[ -z "$domainName" ]]; then
            echo "------------------------------------"
            echo "Please type a domain name or IP!"
            echo ""
        else
            break
        fi
    done
fi

if [[ ! $useHTTPS ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "are you implement your https certficate after installation?"
    echo "------------------------------------------------------------------------------"
    echo ""

    while true; do
        read -p "Do you use https? (Y/n) :$ " yn
        case $yn in
            [Yy]* ) useHTTPS="y"; break;;
            [Nn]* ) useHTTPS="n"; break;;
            * ) (
                echo "------------------------------------"
                echo "Please answer yes or no!"
                echo ""
                );;
        esac
    done
fi

if [[ ! $compileFFmpeg ]] && ! ffmpeg -version &> /dev/null; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "compile and install (nonfree) ffmpeg:"
    echo "------------------------------------------------------------------------------"
    echo ""
    while true; do
        read -p "Do you wish to compile ffmpeg? (Y/n) :$ " yn
        case $yn in
            [Yy]* ) compileFFmpeg="y"; break;;
            [Nn]* ) compileFFmpeg="n"; break;;
            * ) (
                echo "------------------------------------"
                echo "Please answer yes or no!"
                echo ""
                );;
        esac
    done
fi

if [[ ! $compileSRS ]] && [[ ! -d /usr/local/srs ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "install and srs rtmp/hls server:"
    echo "------------------------------------------------------------------------------"
    echo ""
    while true; do
        read -p "Do you wish to install srs? (Y/n) :$ " yn
        case $yn in
            [Yy]* ) compileSRS="y"; break;;
            [Nn]* ) compileSRS="n"; break;;
            * ) (
                echo "------------------------------------"
                echo "Please answer y or n!"
                echo ""
                );;
        esac
    done
fi

if [[ ! $mediaPath ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "path to media storage, default: /opt/tv-media"
    echo "------------------------------------------------------------------------------"
    echo ""

    read -p "media path :$ " mediaPath

    if [[ -z "$mediaPath" ]]; then
        mediaPath="/opt/tv-media"
    fi
fi

if [[ ! $playlistPath ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "playlist path, default: /opt/playlists"
    echo "------------------------------------------------------------------------------"
    echo ""

    read -p "playlist path :$ " playlistPath

    if [[ -z "$playlistPath" ]]; then
        playlistPath="/opt/playlists"
    fi
fi

if [[ ! $setMultiChannel ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "do you want to run a single channel, or multi channel setup?"
    echo "------------------------------------------------------------------------------"
    echo ""

    while true; do
        read -p "multi channel setup (Y/n) :$ " yn
        case $yn in
            [Yy]* ) setMultiChannel="y"; break;;
            [Nn]* ) setMultiChannel="n"; break;;
            * ) (
                echo "------------------------------------"
                echo "Please answer y or n!"
                echo ""
                );;
        esac
    done
fi

################################################################################
## Install functions
################################################################################

# install system packages
source $CURRENTPATH/scripts/system.sh

# install app collection

if [[ $compileFFmpeg == 'y' ]]; then
    source $CURRENTPATH/scripts/ffmpeg.sh
fi

if [[ $compileSRS == 'y' ]]; then
    source $CURRENTPATH/scripts/srs.sh
fi

source $CURRENTPATH/scripts/engine.sh
source $CURRENTPATH/scripts/api.sh
source $CURRENTPATH/scripts/frontend.sh

if ! grep -q "ffplayout_engine.service" "/etc/sudoers"; then
  echo "$serviceUser  ALL = NOPASSWD: /bin/systemctl start ffplayout_engine.service, /bin/systemctl stop ffplayout_engine.service, /bin/systemctl reload ffplayout_engine.service, /bin/systemctl restart ffplayout_engine.service, /bin/systemctl status ffplayout_engine.service, /bin/systemctl is-active ffplayout_engine.service, /bin/journalctl -n 1000 -u ffplayout_engine.service" >> /etc/sudoers
fi

if [[ "$(grep -Ei 'centos|fedora' /etc/*release)" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "you run a rhel like system, which is not widely tested"
    echo "this OS needs some SeLinux rules"
    echo "check scripts/selinux.sh if you can live with it, and run that script manually"
    echo "------------------------------------------------------------------------------"
    echo ""
fi

echo ""
echo "------------------------------------------------------------------------------"
echo "installation done..."
echo "------------------------------------------------------------------------------"
echo ""
