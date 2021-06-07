# ffplayout-installer
Standalone installer for the ffplayout app collection

Run `install.sh` as *root* for full installation.

A debian based system is recommend.

CentOS 8+ and Fedora can work, but is not widely tested. If you really need it, you have to apply SeLinux rules. For that you have **selinux.sh**, check this script carefully if the rules a ok for you.

The most tested system is **Debian 10**.

If you prefer a dockerized version of ffplayout, checkout [ffplayout-docker](https://github.com/ffplayout/ffplayout-docker)

## Automated Installation
There is also a automated installation mode, where you can pass all values as an argument:

```bash
./install.sh \
    --domain=[domain name or IP] \
    --nginx=[y/n] \
    --https=[y/n] \
    --ffmpeg=[y/n] \
    --srs=[y/n] \
    --media=[path] \
    --playlist=[path] \
    --channels=[y/n] \
    --master=[y/n] \
    --user=[username] \
    --password=[password]
```

Run `./install.sh --help` for more information.
