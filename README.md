## About

This script will:

 1. download the `Debian 7.1 "Wheezy"` server, 64bit iso
 2. ... do some magic to turn it into a vagrant box file
 3. output `package.box`

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

To add `package.box` with name `debian-71` into vagrant:

    vagrant box add "debian-71" package.box

## Usage on Linux

    ./build.sh

This should do everything you need. If you don't have `mkisofs` or `p7zip`:

    sudo apt-get install genisoimage
    sudo apt-get install p7zip-full

To add `package.box` with name `debian-71` into vagrant:

    vagrant box add "debian-71" package.box

### Notes

This script basted on original Carl's [repo](https://github.com/cal/vagrant-ubuntu-precise-64) and with some tweaks to be compatible Debian 7.1.
