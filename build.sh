#!/bin/bash

# make sure we have dependencies
hash vagrant 2>/dev/null || { echo >&2 "ERROR: vagrant not found.  Aborting."; exit 1; }
hash VBoxManage 2>/dev/null || { echo >&2 "ERROR: VBoxManage not found.  Aborting."; exit 1; }
hash 7z 2>/dev/null || { echo >&2 "ERROR: 7z not found. Aborting."; exit 1; }

if hash mkisofs 2>/dev/null; then
  MKISOFS="$(which mkisofs)"
elif hash genisoimage 2>/dev/null; then
  MKISOFS="$(which genisoimage)"
else
  echo >&2 "ERROR: mkisofs or genisoimage not found.  Aborting."
  exit 1
fi

set -o nounset
set -o errexit
#set -o xtrace

# Configurations
BOX="debian-wheezy-64"
ISO_URL="http://ftp.acc.umu.se/debian-cd/7.2.0/amd64/iso-cd/debian-7.2.0-amd64-netinst.iso"
ISO_MD5="b86774fe4de88be6378ba3d71b8029bd"

# location, location, location
FOLDER_BASE=`pwd`
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

if [ $OSTYPE = "linux-gnu" ];
then
  MD5="md5sum"
  ISO_GUESTADDITIONS="/usr/share/virtualbox/VBoxGuestAdditions.iso"
else
  MD5="md5 -q"
  ISO_GUESTADDITIONS="/Applications/VirtualBox.app/Contents/MacOS/VBoxGuestAdditions.iso"
fi

# start with a clean slate
if [ -d "${FOLDER_BUILD}" ]; then
  echo "Cleaning build directory ..."
  chmod -R u+w "${FOLDER_BUILD}"
  rm -rf "${FOLDER_BUILD}"
fi
if [ -f "${FOLDER_ISO}/custom.iso" ]; then
  echo "Removing custom iso ..."
  rm "${FOLDER_ISO}/custom.iso"
fi
if [ -f "${FOLDER_BASE}/${BOX}.box" ]; then
  echo "Removing old ${BOX}.box" ...
  rm "${FOLDER_BASE}/${BOX}.box"
fi
if VBoxManage showvminfo "${BOX}" >/dev/null 2>/dev/null; then
  echo "Unregistering vm ..."
  VBoxManage unregistervm "${BOX}" --delete
fi

# Setting things back up again
mkdir -p "${FOLDER_ISO}"
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_INITRD}"

ISO_FILENAME="${FOLDER_ISO}/`basename ${ISO_URL}`"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"

# download the installation disk if you haven't already or it is corrupted somehow
echo "Downloading `basename ${ISO_URL}` ..."
if [ ! -e "${ISO_FILENAME}" ]; then
  curl --output "${ISO_FILENAME}" -L "${ISO_URL}"
fi

# make sure download is right...
ISO_HASH=`$MD5 "${ISO_FILENAME}" | cut -d ' ' -f 1`
if [ "${ISO_MD5}" != "${ISO_HASH}" ]; then
  echo "ERROR: MD5 does not match. Got ${ISO_HASH} instead of ${ISO_MD5}. Aborting."
  exit 1
fi

# customize it
echo "Creating Custom ISO"
if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then

  echo "Using 7zip"
  7z x "${ISO_FILENAME}" -o"${FOLDER_ISO_CUSTOM}"

  # If that didn't work, you have to update p7zip
  if [ ! -e $FOLDER_ISO_CUSTOM ]; then
    echo "Error with extracting the ISO file with your version of p7zip. Try updating to the latest version."
    exit 1
  fi

  # backup initrd.gz
  echo "Backing up current init.rd ..."
  FOLDER_INSTALL=$(ls -1 -d "${FOLDER_ISO_CUSTOM}/install."* | sed 's/^.*\///')
  chmod u+w "${FOLDER_ISO_CUSTOM}/${FOLDER_INSTALL}" "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/${FOLDER_INSTALL}/initrd.gz"
  cp -r "${FOLDER_ISO_CUSTOM}/${FOLDER_INSTALL}/"* "${FOLDER_ISO_CUSTOM}/install/"
  mv "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # stick in our new initrd.gz
  echo "Installing new initrd.gz ..."
  cd "${FOLDER_ISO_INITRD}"
  gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -id || true
  cd "${FOLDER_BASE}"
  cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
  cd "${FOLDER_ISO_INITRD}"
  find . | cpio --create --format='newc' | gzip  > "${FOLDER_ISO_CUSTOM}/install/initrd.gz"

  # clean up permissions
  echo "Cleaning up Permissions ..."
  chmod u-w "${FOLDER_ISO_CUSTOM}/install" "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # replace isolinux configuration
  echo "Replacing isolinux config ..."
  cd "${FOLDER_BASE}"
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux" "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  rm "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  cp isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"

  # add late_command script
  echo "Add late_command script ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}"
  cp "${FOLDER_BASE}/late_command.sh" "${FOLDER_ISO_CUSTOM}"

  echo "Running mkisofs ..."
  $MKISOFS -r -V "Custom Debian Install CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"
fi

echo "Creating VM Box..."
# create virtual machine
if ! VBoxManage showvminfo "${BOX}" >/dev/null 2>/dev/null; then
  VBoxManage createvm \
    --name "${BOX}" \
    --ostype Debian_64 \
    --register \
    --basefolder "${FOLDER_VBOX}"

  VBoxManage modifyvm "${BOX}" \
    --memory 360 \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --vram 12 \
    --pae off \
    --rtcuseutc on

  VBoxManage storagectl "${BOX}" \
    --name "IDE Controller" \
    --add ide \
    --controller PIIX4 \
    --hostiocache on

  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${FOLDER_ISO}/custom.iso"

  VBoxManage storagectl "${BOX}" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --portcount 1 \
    --hostiocache off

  VBoxManage createhd \
    --filename "${FOLDER_VBOX}/${BOX}/${BOX}.vdi" \
    --size 40960

  VBoxManage storageattach "${BOX}" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "${FOLDER_VBOX}/${BOX}/${BOX}.vdi"

  VBoxManage startvm "${BOX}"

  echo -n "Waiting for installer to finish "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  # Forward SSH
  VBoxManage modifyvm "${BOX}" \
    --natpf1 "guestssh,tcp,,2222,,22"

  # Attach guest additions iso
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${ISO_GUESTADDITIONS}"

  VBoxManage startvm "${BOX}"

  # get private key
  curl --output "${FOLDER_BUILD}/id_rsa" "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant"
  chmod 600 "${FOLDER_BUILD}/id_rsa"

  # install virtualbox guest additions
  sleep 10
  ssh -i "${FOLDER_BUILD}/id_rsa" -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 2222 vagrant@127.0.0.1 "sudo mount /dev/cdrom /media/cdrom; sudo sh /media/cdrom/VBoxLinuxAdditions.run -- --force; sudo umount /media/cdrom; sudo shutdown -h now"
  echo -n "Waiting for machine to shut off "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  VBoxManage modifyvm "${BOX}" --natpf1 delete "guestssh"

  # Detach guest additions iso
  echo "Detach guest additions ..."
  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive
fi

echo "Building Vagrant Box ..."
vagrant package --base "${BOX}" --output "${BOX}.box"

# references:
# http://blog.ericwhite.ca/articles/2009/11/unattended-debian-lenny-install/
# http://docs-v1.vagrantup.com/v1/docs/base_boxes.html
# http://www.debian.org/releases/stable/example-preseed.txt
