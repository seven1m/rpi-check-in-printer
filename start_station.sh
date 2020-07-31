#!/bin/bash

sleep 5

while ! ping -c 1 -W 1 1.1.1.1; do
  echo "Waiting for network... (pinging 1.1.1.1 with no response)"
  sleep 1
done

cd $HOME/planning-center-check-ins
./planning-center-check-ins
