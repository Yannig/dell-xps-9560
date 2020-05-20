#!/usr/bin/env bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

release=$(lsb_release -c -s)

# Check if the script is running under Ubuntu 20.04
if [ "$release" != "focal" ] ; then
    >&2 echo -e "${RED}This script is made for Ubuntu 20.04!${NC}"
    exit 1
fi

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    >&2 echo -e "${RED}Please run xps-tweaks as root!${NC}"
    exit 2
fi

# Enable universe and proposed
add-apt-repository -y universe
apt -y update
apt -y full-upgrade

apt -y install thermald tlp tlp-rdw powertop

# Fix Sleep/Wake Bluetooth Bug
sed -i '/RESTORE_DEVICE_STATE_ON_STARTUP/s/=.*/=1/' /etc/tlp.conf
systemctl restart tlp

# Fix Audio Feedback/White Noise from Headphones on Battery Bug
echo -e "${GREEN}Do you wish to fix the headphone white noise on battery bug? (if you do not have this issue, there is no need to enable it) (may slightly impact battery life)${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) sed -i '/SOUND_POWER_SAVE_ON_BAT/s/=.*/=0/' /etc/tlp.conf; systemctl restart tlp; break;;
        No ) break;;
    esac
done

# Install codecs
echo -e "${GREEN}Do you wish to install video codecs for encoding and playing videos?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) apt -y install ubuntu-restricted-extras va-driver-all vainfo libva2 gstreamer1.0-libav gstreamer1.0-vaapi; break;;
        No ) break;;
    esac
done

# Intel microcode
apt -y install intel-microcode iucode-tool

# Enable power saving tweaks for Intel chip
echo "options i915 enable_fbc=1 enable_guc=3 disable_power_well=0 fastboot=1" > /etc/modprobe.d/i915.conf

# Let users check fan speed with lm-sensors
echo "options dell-smm-hwmon restricted=0 force=1" > /etc/modprobe.d/dell-smm-hwmon.conf
if < /etc/modules grep "dell-smm-hwmon" &>/dev/null; then
    echo "dell-smm-hwmon is already in /etc/modules!"
else
    echo "dell-smm-hwmon" >> /etc/modules
fi
update-initramfs -u

# Tweak grub defaults
GRUB_OPTIONS_VAR_NAME="GRUB_CMDLINE_LINUX_DEFAULT"
GRUB_OPTIONS="quiet splash acpi_rev_override=1 acpi_osi=Linux nouveau.modeset=0"
GRUB_OPTIONS="$GRUB_OPTIONS i915.modeset=1 pcie_aspm=force drm.vblankoffdelay=1"
GRUB_OPTIONS="$GRUB_OPTIONS scsi_mod.use_blk_mq=1 nouveau.runpm=0 mem_sleep_default=deep "
echo -e "${GREEN}Do you wish to disable SPECTRE/Meltdown patches for performance?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes )
                GRUB_OPTIONS+="mitigations=off"
            break;;
        No ) break;;
    esac
done
GRUB_OPTIONS_VAR="$GRUB_OPTIONS_VAR_NAME=\"$GRUB_OPTIONS\""

if < /etc/default/grub grep "$GRUB_OPTIONS_VAR" &>/dev/null; then
    echo -e "${GREEN}Grub is already tweaked!${NC}"
else
    sed -i "s/^$GRUB_OPTIONS_VAR_NAME=.*/$GRUB_OPTIONS_VAR_NAME=\"$GRUB_OPTIONS\"/g" /etc/default/grub
    update-grub
fi

# Ask for disabling tracker
echo -e "${GREEN}Do you wish to disable GNOME tracker (it uses a lot of power)?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) systemctl mask tracker-extract.desktop tracker-miner-apps.desktop tracker-miner-fs.desktop tracker-store.desktop; break;;
        No ) break;;
    esac
done

# Ask for disabling fingerprint reader
echo -e "${GREEN}Do you wish to disable the fingerprint reader to save power (no linux driver is available for this device)?${NC}"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "# Disable fingerprint reader
        SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"27c6\", ATTRS{idProduct}==\"5395\", ATTR{authorized}=\"0\"" > /etc/udev/rules.d/fingerprint.rules; break;;
        No ) rm -f /etc/udev/rules.d/fingerprint.rules
        break;;
    esac
done

echo -e "${GREEN}FINISHED! Please reboot the machine!${NC}"
