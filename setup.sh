#!/bin/bash

check_ins_release_url="https://check-ins-printing.s3.amazonaws.com/planning-center-check-ins-1.8.3-armv7l.zip"
qz_release_url="https://github.com/qzind/tray/releases/download/v2.1.0/qz-tray-2.1.0+1.run"
autostart="/etc/xdg/lxsession/LXDE-pi/autostart"

ip=$(/sbin/ifconfig | egrep -o "inet [^ ]+" | grep -v 127.0.0.1 | awk '{ print $2 }')
if [[ "$ip" == "" ]]; then
  ip="192.168.X.Y"
fi

set -e

echo "Welcome to the rpi-check-in-printer setup script."
echo "This script will install some software on your Pi and help you set up your printer."
echo
echo "First, let's get this out of the way..."
echo
read -p "Did you change the password of the Pi user from the default 'raspberry'? [yN]" REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo "Great, let's continue..."
else
  echo "Please follow the instructions here: https://github.com/seven1m/rpi-check-in-printer"
  exit
fi

if [[ "$SKIP_ZIP_DOWNLOAD" == "" ]]; then
  rm -rf rpi-check-in-printer-latest.zip rpi-check-in-printer planning-center-check-ins.zip planning-center-check-ins

  wget -O rpi-check-in-printer-latest.zip https://github.com/seven1m/rpi-check-in-printer/archive/latest.zip
  unzip rpi-check-in-printer-latest.zip
  mv rpi-check-in-printer-latest rpi-check-in-printer

  wget -O planning-center-check-ins.zip $check_ins_release_url
  unzip planning-center-check-ins.zip -d planning-center-check-ins
fi

if [[ "$SKIP_APT_INSTALL" == "" ]]; then
  sudo apt-get update
  sudo apt-get install -y -q build-essential cups cups-bsd printer-driver-dymo vim ruby openjdk-8-jdk
fi

sudo gpasswd -a pi lpadmin
sudo /usr/sbin/cupsctl --remote-admin --remote-any --share-printers
sudo systemctl restart cups

if ! grep "start_station.sh" $autostart; then
  echo '@/home/pi/rpi-check-in-printer/start_station.sh' | sudo tee -a $autostart
fi

if ! grep "start_qz_tray.sh" $autostart; then
  echo '@/home/pi/rpi-check-in-printer/start_qz_tray.sh' | sudo tee -a $autostart
fi

qz_filename=$(basename $qz_release_url)
if [[ ! -e $qz_filename ]]; then
  wget $qz_release_url
  chmod +x $qz_filename
  sudo ./$qz_filename
fi

sudo cp /home/pi/rpi-check-in-printer/vncserver@.service /etc/systemd/system/vncserver@.service
sudo systemctl daemon-reload
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1

echo
echo "Great! Everything is installed. Now let's set up your printer."
echo "This script will attempt to add the printer automatically..."

function get_printer_device() {
  echo "Searching for connected printer..."
  set +e
  device=$(/usr/sbin/lpinfo -v | grep -i "direct.*dymo" | awk '{ print $2 }' | head -n1)
  set -e
}

function get_printer_name() {
  set +e
  printer_name=$(lpstat -s | grep -i "dymo" | ruby -e "m=STDIN.read.match(/device for ([^:]+):/); print m[1] if m")
  set -e
}

get_printer_name

if [[ -z "$printer_name" ]]; then
  get_printer_device

  while [[ -z "$device" ]]; do
    read -p "We were not able to find any Dymo printers connected. Do you want to try again? [Yn]" REPLY
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
      get_printer_device
    else
      break
    fi
  done

  if [[ -n "$device" ]]; then
    echo "Adding printer..."
    echo "/usr/sbin/lpadmin -p Dymo -v $device -m drv:///sample.drv/dymo.ppd -E" # FIXME: select driver appropriate for device. This fixes issues with print DPI/resolution.
    /usr/sbin/lpadmin -p Dymo -v $device -m drv:///sample.drv/dymo.ppd -E
  else
    echo "Let's try it this way instead..."
    echo "In your web browser, visit https://$ip:631 and add your Dymo printer."
    echo
    read -p "Once you have added the printer manually, press enter to continue and test the printer..."
  fi
fi

get_printer_name

if [[ -n "$printer_name" ]]; then
  echo "The printer was added:"
  echo
  echo "    $printer_name"
  echo
  echo "Let's send a test print..."
  echo "test" | lpr -P "$printer_name" -
  echo
  echo "OK, we sent a test print job to the printer. Please make sure that something printed!"
  echo "Assuming that worked ok, press enter to continue..."
  echo "If a label did not print, then Ctrl-C this script and run the test yourself:"
  echo
  echo "    echo \"test\" | lpr -P \"$printer_name\" -"
  echo
  read -r
else
  echo "The Dymo printer could not be found. Did you add it?"
  echo "This script will now stop. You can run it again if you want to try again."
  exit 1
fi

echo "Great! Everything is installed. Now, reboot:"
echo
echo "    sudo reboot"
echo
