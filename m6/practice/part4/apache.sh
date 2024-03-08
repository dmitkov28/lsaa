#!/bin/bash

apt-get update
apt-get install -y apache2
echo "Hello from $(hostname)" > /var/www/html/index.html
systemctl enable --now apache2

