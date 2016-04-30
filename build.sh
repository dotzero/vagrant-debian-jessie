#!/bin/bash

set -o nounset
set -o errexit
# set -o xtrace

# make sure we have dependencies
hash vagrant 2>/dev/null || { echo >&2 "ERROR: vagrant not found.  Aborting."; exit 1; }
hash VBoxManage 2>/dev/null || { echo >&2 "ERROR: VBoxManage not found.  Aborting."; exit 1; }
hash 7z 2>/dev/null || { echo >&2 "ERROR: 7z not found. Aborting."; exit 1; }
hash curl 2>/dev/null || { echo >&2 "ERROR: curl not found. Aborting."; exit 1; }
hash cpio 2>/dev/null || { echo >&2 "ERROR: cpio not found. Aborting."; exit 1; }

VBOX_VERSION="$(VBoxManage --version)"

if hash mkisofs 2>/dev/null; then
  MKISOFS="$(which mkisofs)"
elif hash genisoimage 2>/dev/null; then
  MKISOFS="$(which genisoimage)"
else
  echo >&2 "ERROR: mkisofs or genisoimage not found.  Aborting."
  exit 1
fi

if [ "$OSTYPE" = "linux-gnu" ]; then
  SED="$(which sed) -r"
  MD5="md5sum"
elif [ "$OSTYPE" = "msys" ]; then
  SED="$(which sed) -r"
  MD5="md5 -l"
else
  SED="$(which sed) -E"
  MD5="md5 -q"
fi

# Configurations

# location, location, location
FOLDER_BASE=$(pwd)
FOLDER_ISO="${FOLDER_BASE}/iso"
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_VBOX="${FOLDER_BUILD}/vbox"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"

# Env option: architecture (i386 or amd64)
ARCH=${ARCH:-amd64}

# Env option: Debian CD image mirror; default is http://cdimage.debian.org/debian-cd/
DEBIAN_CDIMAGE=${DEBIAN_CDIMAGE:-cdimage.debian.org}
DEBIAN_CDIMAGE_URL="http://${DEBIAN_CDIMAGE}/debian-cd/"
# Check if the Debian version is set manually (ie. DEBVER="8.4.0") or use the latest version
if [ -z ${DEBVER+x} ]; then
  DEBVER=$(curl -sS ${DEBIAN_CDIMAGE_URL} | grep -E ">[0-9]+\.[0-9]\.[0-9]/<" | ${SED} 's/.*>([0-9]+\.[0-9]\.[0-9])\/<.*/\1/')
  echo "Detected latest Debian version \"$DEBVER\" from $DEBIAN_CDIMAGE_URL"
else
  echo "Using Debian version \"$DEBVER\""
fi

# Env option: the vagrant box name; default is debian-jessie-$ARCH
BOX=${BOX:-debian-jessie-${ARCH}}

ISO_FILE="debian-${DEBVER}-${ARCH}-netinst.iso"
ISO_BASEURL="${DEBIAN_CDIMAGE_URL}${DEBVER}/${ARCH}/iso-cd"
ISO_URL="${ISO_BASEURL}/${ISO_FILE}"
ISO_MD5=$(curl -sS ${ISO_BASEURL}/MD5SUMS | grep ${ISO_FILE} | cut -f1 -d" ")

if [ "$ARCH" = "amd64" ]; then
  VBOX_OSTYPE=Debian_64
else
  VBOX_OSTYPE=Debian
fi

# Env option: Use headless mode or GUI
VM_GUI="${VM_GUI:-}"
if [ "x${VM_GUI}" == "xyes" ] || [ "x${VM_GUI}" == "x1" ]; then
  STARTVM="VBoxManage startvm ${BOX}"
else
  STARTVM="VBoxManage startvm ${BOX} --type headless"
fi
STOPVM="VBoxManage controlvm ${BOX} poweroff"

# Env option: Use custom preseed.cfg or default
DEFAULT_PRESEED="${FOLDER_BASE}/preseed.cfg"
PRESEED="${PRESEED:-"$DEFAULT_PRESEED"}"

# Env option: Use custom late_command.sh or default
DEFAULT_LATE_CMD="${FOLDER_BASE}/late_command.sh"
LATE_CMD="${LATE_CMD:-"$DEFAULT_LATE_CMD"}"

# Parameter changes from 4.2 to 4.3
if [[ "$VBOX_VERSION" < 4.3 ]]; then
  PORTCOUNT="--sataportcount 1"
else
  PORTCOUNT="--portcount 1"
fi

# start with a clean slate
if VBoxManage list runningvms | grep "${BOX}" >/dev/null 2>&1; then
  echo "Stopping vm ..."
  ${STOPVM}
fi
if VBoxManage showvminfo "${BOX}" >/dev/null 2>&1; then
  echo "Unregistering vm ..."
  VBoxManage unregistervm "${BOX}" --delete
fi
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

# Setting things back up again
mkdir -p "${FOLDER_ISO}"
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_VBOX}"
mkdir -p "${FOLDER_ISO_CUSTOM}"
mkdir -p "${FOLDER_ISO_INITRD}"

ISO_FILENAME="${FOLDER_ISO}/${ISO_FILE}"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"

# download the installation disk if you haven't already or it is corrupted somehow
echo "Downloading `basename ${ISO_URL}` ..."
if [ ! -e "${ISO_FILENAME}" ]; then
  curl --output "${ISO_FILENAME}" -L "${ISO_URL}"
fi

# make sure download is right...
ISO_HASH=$($MD5 "${ISO_FILENAME}" | cut -d ' ' -f 1)
if [ "${ISO_MD5}" != "${ISO_HASH}" ]; then
  echo "ERROR: MD5 does not match. Got ${ISO_HASH} instead of ${ISO_MD5}. Aborting."
  exit 1
fi

# customize it
echo "Creating Custom ISO"
if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then

  echo "Using 7zip"
  7z x "${ISO_FILENAME}" -o"${FOLDER_ISO_CUSTOM}"

  # if virtualbox guest additions were found, include them
  VBOXGA_FILENAME=$(
    VBoxManage list dvds \
      | grep -E 'Location:.+VBoxGuestAdditions.iso$' \
      | awk '{ print $2 }'
  )
  if [ ! x"${VBOXGA_FILENAME}" == x"" ]; then
    echo "Including Virtualbox Guest Additions into Custom ISO"
    7z x "${VBOXGA_FILENAME}" -o"${FOLDER_ISO_CUSTOM}/vboxga"
  fi

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
  if [ "$OSTYPE" = "msys" ]; then
    gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -i --make-directories || true
  else
    gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -id || true
  fi
  cd "${FOLDER_BASE}"
  if [ "${PRESEED}" != "${DEFAULT_PRESEED}" ] ; then
    echo "Using custom preseed file ${PRESEED}"
  fi
  cp "${PRESEED}" "${FOLDER_ISO_INITRD}/preseed.cfg"
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
  cp ${FOLDER_BASE}/isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
  chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"

  # add late_command script
  echo "Add late_command script ..."
  chmod u+w "${FOLDER_ISO_CUSTOM}"
  cp "${LATE_CMD}" "${FOLDER_ISO_CUSTOM}/late_command.sh"

  echo "Running mkisofs ..."
  "$MKISOFS" -r -V "Custom Debian $DEBVER $ARCH CD" \
    -cache-inodes -quiet \
    -J -l -b isolinux/isolinux.bin \
    -c isolinux/boot.cat -no-emul-boot \
    -boot-load-size 4 -boot-info-table \
    -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"
fi

# create virtual machine
if ! VBoxManage showvminfo "${BOX}" >/dev/null 2>&1; then
  echo "Creating VM Box ${BOX}..."
  VBoxManage createvm \
    --name "${BOX}" \
    --ostype "${VBOX_OSTYPE}" \
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
    $PORTCOUNT \
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

  ${STARTVM}

  echo -n "Waiting for installer to finish "
  while VBoxManage list runningvms | grep "${BOX}" >/dev/null; do
    sleep 20
    echo -n "."
  done
  echo ""

  VBoxManage storageattach "${BOX}" \
    --storagectl "IDE Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium emptydrive
fi

echo "Building Vagrant Box ${BOX}..."
vagrant package --base "${BOX}" --output "${BOX}.box"

if [ -d "${FOLDER_BUILD}" ]; then
  echo "Cleaning build directory ..."
  chmod -R u+w "${FOLDER_BUILD}"
  rm -rf "${FOLDER_BUILD}"
fi

echo "DONE. To add ${BOX}.box with name debian-jessie into vagrant, just run:"
echo "vagrant box add \"debian-jessie\" ${BOX}.box"

# references:
# http://blog.ericwhite.ca/articles/2009/11/unattended-debian-lenny-install/
# http://docs-v1.vagrantup.com/v1/docs/base_boxes.html
# http://www.debian.org/releases/stable/example-preseed.txt
