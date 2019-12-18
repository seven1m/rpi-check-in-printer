#!/bin/bash

check_ins_release_url="https://check-ins-printing.s3.amazonaws.com/planning-center-check-ins-1.4.1-armv7l.zip"
qz_release_url="https://github.com/qzind/tray/releases/download/v2.1.0/qz-tray-2.1.0.run"
autostart="/etc/xdg/lxsession/LXDE-pi/autostart"

ip=$(/sbin/ifconfig | egrep -o "inet [^ ]+" | grep -v 127.0.0.1 | awk '{ print $2 }')
if [[ "$ip" == "" ]]; then
  ip="192.168.X.Y"
fi

set -e

if [[ -e /run/sshwarn ]]; then
  echo "First, let's change the SSH password from the default..."
  passwd
fi

if [[ ! -e rpi-check-in-printer ]]; then
  rm -f rpi-check-in-printer-latest.zip
  wget https://github.com/seven1m/rpi-check-in-printer/archive/latest.zip
  unzip rpi-check-in-printer-latest.zip -d rpi-check-in-printer
fi

if [[ ! -e planning-center-check-ins.zip ]]; then
  wget -O planning-center-check-ins.zip $check_ins_release_url
  rm -rf planning-center-check-ins
  unzip planning-center-check-ins.zip -d planning-center-check-ins
fi

if [[ ! -e planning-center-check-ins ]]; then
  unzip planning-center-check-ins.zip -d planning-center-check-ins
fi

if [[ "$SKIP_APT_INSTALL" == "" ]]; then
  sudo apt-get update
  sudo apt-get install -y -q build-essential cups cups-bsd printer-driver-dymo vim ruby openjdk-8-jdk x11vnc
fi

sudo gpasswd -a pi lpadmin
sudo /usr/sbin/cupsctl --remote-admin --remote-any --share-printers
sudo systemctl restart cups

if ! grep "start_station.sh" $autostart; then
  sudo sed -i 's;point-rpi;@/home/pi/rpi-check-in-printer/start_station.sh\n\0;' $autostart
fi

if ! grep "start_qz_tray.sh" $autostart; then
  sudo sed -i 's;point-rpi;@/home/pi/rpi-check-in-printer/start_qz_tray.sh\n\0;' $autostart
fi

if ! grep "x11vnc" $autostart; then
  sudo sed -i 's;point-rpi;@x11vnc -geometry 1200x800\n\0;' $autostart
fi

qz_filename=$(basename $qz_release_url)
if [[ ! -e $qz_filename ]]; then
  wget $qz_release_url
  chmod +x $qz_filename
  sudo ./$qz_filename
fi

echo
echo "Great! Everything is installed. Now let's set up your printer."
echo "This script will attempt to add the printer automatically..."

function get_printer_device() {
  device=$(/usr/sbin/lpinfo -v | grep -i "direct.*dymozz" | awk '{ print $2 }' | head -n1)
}

function get_printer_name() {
  printer_name=$(lpstat -s | ruby -e "m=STDIN.read.match(/device for ([^:]+):/); print m[1] if m")
}

get_printer_name

if [[ -z "$printer_name" ]]; then
  get_printer_device

  while [[ -z "$device" ]]; do
    echo "We were not able to find any Dymo printers connected. Do you want to try again? [Yn]"
    read -r
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
      get_printer_device
    else
      break
    fi
  done

  if [[ -n "$device" ]]; then
    /usr/sbin/lpadmin -p Dymo -v $device -m drv:///sample.drv/dymo.ppd -E
  else
    echo "Let's try it this way instead..."
    echo "In your web browser, visit https://$ip:631 and add your Dymo printer."
    echo
    echo "Once you have added the printer manually, press enter to continue and test the printer..."
    read -r
  fi
fi

get_printer_name

if [[ -n "$printer_name" ]]; then
  echo "The printer was added. Let's send a test print..."
  echo "test" | lpr -P "$printer_name" -
  echo
  echo "OK, we sent a test print job to the printer. Please make sure that something printed!"
  echo "Assuming that worked ok, press enter to continue..."
  read -r
else
  echo "The Dymo printer could not be found. Did you add it?"
  echo "This script will now stop. You can run it again if you want to try again."
  exit 1
fi

echo "Great! Everything is installed. Now, let's reboot... Press enter to continue."
read -r
sudo reboot
