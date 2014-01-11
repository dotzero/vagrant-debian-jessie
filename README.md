## About

This script will:

 1. download the `Debian 7.3 "Wheezy"` server, 64bit iso
 2. ... do some magic to turn it into a vagrant box file
 3. output `debian-wheezy-64.box`

## Requirements

 * Oracle VM VirtualBox
 * Vagrant
 * mkisofs
 * 7zip

## Usage on OSX

    ./build.sh

This should do everything you need. If you don't have `mkisofs` or `p7zip`, install [homebrew](http://mxcl.github.com/homebrew/), then:

    brew install cdrtools
    brew install p7zip
    
Also, you can supply your own preseed.cfg, e.g. in case if you need some customizations for your private base box (user name, passwords etc.):
    
    PRESEED=/path/to/my-preseed.cfg ./build.sh

To add `debian-wheezy-64.box` with name `debian-73` into vagrant:

    vagrant box add "debian-73" debian-wheezy-64.box

## Usage on Linux

    ./build.sh

This should do everything you need. If you don't have `mkisofs` or `p7zip`:

    sudo apt-get install genisoimage
    sudo apt-get install p7zip-full
    
Also, you can supply your own preseed.cfg, e.g. in case if you need some customizations for your private base box (user name, passwords etc.):
    
    PRESEED=/path/to/my-preseed.cfg ./build.sh

To add `debian-wheezy-64.box` with name `debian-73` into vagrant:

    vagrant box add "debian-73" debian-wheezy-64.box

### Notes

This script basted on original Carl's [repo](https://github.com/cal/vagrant-ubuntu-precise-64) and with some tweaks to be compatible Debian 7.3.

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/dotzero/vagrant-debian-wheezy-64/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
