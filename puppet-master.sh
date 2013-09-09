#!/usr/bin/env bash
#
# This bootstraps Puppet on Ubuntu 12.04 LTS.
#
set -e

REPO_DEB_URL="http://apt.puppetlabs.com/puppetlabs-release-precise.deb"

#--------------------------------------------------------------------
# NO TUNABLES BELOW THIS POINT
#--------------------------------------------------------------------
if [ "$EUID" -ne "0" ]; then
  echo "This script must be run as root." >&2
  exit 1
fi

if [ -e /usr/share/puppet-dashboard ]; then
  echo "Puppet dashboard already installed. You may have to start the services manually."
  exit 0
fi

# Install the PuppetLabs repo
echo "Configuring PuppetLabs repo..."
repo_deb_path=$(mktemp)
wget --output-document=${repo_deb_path} ${REPO_DEB_URL} 2>/dev/null
dpkg -i ${repo_deb_path} >/dev/null
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null

# Install Puppet
echo "Installing Puppet..."
DEBIAN_FRONTEND=noninteractive apt-get install -y puppet >/dev/null

echo "Puppet installed!"

# Install Puppet Dashboard
echo "Installing Puppet Dashboard..."
DEBIAN_FRONTEND=noninteractive apt-get install -y puppet-dashboard >/dev/null

# Fix puppet-dashboard service
echo "Fixing puppet-dashboard service..."
#
# The init.d script is broken because -d causes the service to detach, so the actual process ID
# differs from the one logged in the pidfile. The --background option means start-stop-daemon
# cannot check the exit status if the process fails to execute for any reason.
#
sed --in-place 's/\(start-stop-daemon --start\) \(.*\) -d$/\1 --background \2/' /etc/init.d/puppet-dashboard
sed --in-place 's/^### START=yes/START=yes/' /etc/default/puppet-dashboard
sed --in-place 's/^### START=no/START=no/' /etc/default/puppet-dashboard-workers

# Install MySQL
echo "Installing MySQL..."
DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server >/dev/null

# Configure MySQL
echo "Configuring MySQL..."
mysql <<CONFIGURATION
CREATE DATABASE dashboard_production  CHARSET utf8;
CREATE DATABASE dashboard_development CHARSET utf8;
CREATE DATABASE dashboard_test        CHARSET utf8;
CREATE USER 'dashboard'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON dashboard_production.*  TO 'dashboard'@'localhost';
GRANT ALL PRIVILEGES ON dashboard_development.* TO 'dashboard'@'localhost';
GRANT ALL PRIVILEGES ON dashboard_test.*        TO 'dashboard'@'localhost';
CONFIGURATION

sed --in-place 's/^\(max_allowed_packet\s*\)=.*/\1 = 32M/' /etc/mysql/my.cnf

# Prepare Schema
echo "Preparing schema..."
cd /usr/share/puppet-dashboard
rake RAILS_ENV=production db:migrate >/dev/null 2>/dev/null
rake db:migrate db:test:prepare >/dev/null 2>/dev/null

# Restart services
echo "Restarting services..."
service mysql restart
./script/delayed_job -p dashboard -n 1 -m start >/dev/null 2>/dev/null
service puppet-dashboard start
