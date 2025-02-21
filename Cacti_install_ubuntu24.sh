#!/bin/bash

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y fping apache2 php php-{mysql,curl,net-socket,gd,intl,pear,imap,memcache,pspell,tidy,xmlrpc,snmp,mbstring,gmp,json,xml,common,ldap} libapache2-mod-php mariadb-server snmp snmpd rrdtool git

# Enable Apache and MariaDB services
sudo systemctl enable --now apache2 mariadb

# Secure MariaDB installation (manual input required)
sudo mysql_secure_installation

# Create Cacti database and user
sudo mysql -u root -p <<EOF
CREATE DATABASE cacti DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;
GRANT ALL PRIVILEGES ON cacti.* TO 'cacti_user'@'localhost' IDENTIFIED BY 'strongpassword';
GRANT SELECT ON mysql.time_zone_name TO 'cacti_user'@'localhost';
ALTER DATABASE cacti CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
EOF

# Configure MariaDB settings
sudo tee /etc/mysql/mariadb.conf.d/50-server.cnf <<EOF
[server]
innodb_file_format=Barracuda
innodb_large_prefix=1
collation-server=utf8mb4_unicode_ci
character-set-server=utf8mb4
innodb_doublewrite=OFF
max_heap_table_size=128M
tmp_table_size=128M
join_buffer_size=128M
innodb_buffer_pool_size=1G
innodb_flush_log_at_timeout=3
innodb_read_io_threads=32
innodb_write_io_threads=16
innodb_io_capacity=5000
innodb_io_capacity_max=10000
innodb_buffer_pool_instances=9
EOF

# Restart MariaDB
sudo systemctl restart mariadb

# Update MySQL time zone info
sudo mysql_tzinfo_to_sql /usr/share/zoneinfo | sudo mysql -u root mysql

# Download and install Cacti
git clone https://github.com/Cacti/cacti.git
sudo mv cacti /var/www/html/

# Import Cacti default database
sudo mysql -u root cacti < /var/www/html/cacti/cacti.sql

# Configure Cacti
cd /var/www/html/cacti/include
cp config.php.dist config.php
sudo nano config.php

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/cacti

# Create systemd service for Cacti poller
sudo tee /etc/systemd/system/cactid.service <<EOF
[Unit]
Description=Cacti Daemon Main Poller Service
After=network.target

[Service]
Type=forking
User=www-data
Group=www-data
EnvironmentFile=/etc/default/cactid
ExecStart=/var/www/html/cacti/cactid.php
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Cacti service
sudo touch /etc/default/cactid
sudo systemctl daemon-reload
sudo systemctl enable --now cactid

# Restart services
sudo systemctl restart apache2 mariadb

# Display installation completion message
echo "Cacti installation completed. Access it via: http://your-server-IP-address/cacti/"
