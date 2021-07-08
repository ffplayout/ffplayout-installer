#!/usr/bin/env bash

if [[ $(whoami) != 'root' ]]; then
    echo "This script must run under root!"
    exit 1
fi

if [[ ! -d "/opt/srs" ]]; then
    echo ""
    echo "------------------------------------------------------------------------------"
    echo "compile and install srs"
    echo "------------------------------------------------------------------------------"

    cd /opt/
    git clone https://github.com/ossrs/srs.git
    cd srs/trunk/
    git checkout 3.0release

    ./configure --use-sys-ssl
    make
    make install

    mkdir -p "/var/www/srs/live"
    mkdir "/etc/srs"

cat <<EOF > "/etc/srs/srs.conf"
listen              1935;
max_connections     20;
daemon              on;
pid                 /usr/local/srs/objs/srs.pid;
srs_log_tank        console; # file;
srs_log_file        /var/log/srs.log;
ff_log_dir          /tmp;

# can be: verbose, info, trace, warn, error
srs_log_level       error;

http_api {
    enabled         on;
    listen          1985;
}

stats {
    network         0;
    disk            sda vda xvda xvdb;
}

vhost __defaultVhost__ {
    # timestamp correction
    mix_correct     on;

    http_hooks {
        enabled         off;
        on_publish      http://127.0.0.1:8085/api/v1/streams;
        on_unpublish    http://127.0.0.1:8085/api/v1/streams;
    }

    hls {
        enabled         on;
        hls_path        /var/www/srs;
        hls_fragment    6;
        hls_window      3600;
        hls_cleanup     on;
        hls_dispose     0;
        hls_m3u8_file   live/stream.m3u8;
        hls_ts_file     live/stream-[seq].ts;
        }
}
EOF

cat <<EOF > "/etc/systemd/system/srs.service"
[Unit]
Description=SRS
Documentation=https://github.com/ossrs/srs/wiki
After=network.target

[Service]
Type=forking
ExecStartPre=/usr/local/srs/objs/srs -t -c /etc/srs/srs.conf
ExecStart=/usr/local/srs/objs/srs -c /etc/srs/srs.conf
ExecStop=/bin/kill -TERM \$MAINPID
ExecReload=/bin/kill -1 \$MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable srs.service
    systemctl start srs.service

elif [[ $update ]]; then
    cd /opt/srs
    git fetch

    if [[ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]; then
        echo "------------------------------------------------------------------------------"
        echo "srs is up to date"
        echo "------------------------------------------------------------------------------"
        return
    fi

    git pull

    cd srs/trunk/
    make uninstall

    ./configure --use-sys-ssl
    make
    make install
fi
