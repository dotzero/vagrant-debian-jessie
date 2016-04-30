#!/bin/bash

# passwordless sudo
echo "%sudo   ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# public ssh key for vagrant user
mkdir /home/vagrant/.ssh
wget -O /home/vagrant/.ssh/authorized_keys "https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub"
chmod 755 /home/vagrant/.ssh
chmod 644 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# speed up ssh
echo "UseDNS no" >> /etc/ssh/sshd_config

# installs virtualbox guest additions
if [ -d /tmp/vboxga ]; then
  apt-get remove --purge -y virtualbox-*
  /bin/bash /tmp/vboxga/VBoxLinuxAdditions.run
  echo rm -rf /tmp/vboxga
fi

# Install chef from omnibus
curl -L https://www.getchef.com/chef/install.sh | bash

# display grub timeout and login promt after boot
sed -i \
  -e "s/quiet splash//" \
  -e "s/GRUB_TIMEOUT=[0-9]/GRUB_TIMEOUT=0/" \
  /etc/default/grub
update-grub

# clean up
apt-get autoremove --purge -y
apt-get clean

# Zero free space to aid VM compression
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
