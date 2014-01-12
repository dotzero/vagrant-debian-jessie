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
    
To add `debian-wheezy-64.box` with name `debian-73` into vagrant:

    vagrant box add "debian-73" debian-wheezy-64.box

## Usage on Linux

    ./build.sh

This should do everything you need. If you don't have `mkisofs` or `p7zip`:

    sudo apt-get install genisoimage
    sudo apt-get install p7zip-full
    
To add `debian-wheezy-64.box` with name `debian-73` into vagrant:

    vagrant box add "debian-73" debian-wheezy-64.box

## Environment variables

You can affect the default behaviour of the script using environment variables:

    VAR=value ./build.sh

The following variables are supported:

    PRESEED — path to custom preseed file. May be useful when if you need some customizations for your private base box (user name, passwords etc.):

    LATE_CMD — path to custom late_comman.sh. May be useful when if you need some customizations for your private base box (user name, passwords etc.):

    VM_GUI — if set to "yes" or "1", disables headless mode for vm. May be useful for debugging installer


### Notes

This script basted on original Carl's [repo](https://github.com/cal/vagrant-ubuntu-precise-64) and with some tweaks to be compatible Debian 7.3.

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/dotzero/vagrant-debian-wheezy-64/trend.png)](https://bitdeli.com/free "Bitdeli Badge")
