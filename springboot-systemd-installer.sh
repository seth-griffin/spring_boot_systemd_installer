#!/usr/bin/env bash

##
# This script will install your springboot executable jar as a systemd service
# It has been tested on Ubuntu 18.04
#
# Once your install succeeds you can use the following to control your app like a service
#     systemctl enable service-name.service - Enables the service for use
#     systemctl start service-name.service - Starts the service
#     systemctl status service-name.service - Check the status of the service
#     journalctl -f -u - Show the logs for the service
#
# Note that for this script to work correctly all of the files must be in the current working directory
# The beautiful thing about this script is that it can also be used to upgrade an app already installed using it
##

##
# Interpret args
# This script requires the following positional arguments
#   $1 = Service Name
#   $2 = Service Description
#   $3 = Jar File Name
#   $4 = Environment file name
#   $5 = syslog|nosyslog
#        syslog - send logs to syslog
#        nosyslog - only use systemd journal
##

if [[ -z "$1" && -z "$2" && -z "$3" && -z "$4" && -z "$5" ]]
    then
    	echo -e "Not enough arguments supplied\nUsage:\n\t${0} service-name service-description jar-file-name environment-file-name syslog|nosyslog\n"
        exit 1
fi

##
# Set up our environment variables
##

service_name="${1}"
service_description="${2}"
jar_file_name="${3}"
environment_file_name="${4}"
use_syslog="${5}"

##
# Confirm with the end user that we're going to make the right changes
##

echo "It looks like you entered the following arguments:"
echo -e "  Service Name: ${service_name}"
echo -e "  Service Description: ${service_description}"
echo -e "  Jar File Name: ${jar_file_name}"
echo -e "  Environment File: ${environment_file_name}"
echo -e "  Use Syslog: ${use_syslog}"
read -n1 -p "Is this correct [Y/N]?" user_choice

echo ""

case $user_choice in
    y|Y) echo "Installing..." ;;
    n|N) echo "Please correct your errors and try again" && exit ;;
    *) echo "Invalid selection" && exit ;;
esac

# Create the user for the service if the user doesn't already exist
user_exists=$(id -u ${service_name})
if [[ user_exists -eq 0 ]]
    then
         useradd ${service_name} -s /sbin/nologin -M
fi

##
# Write the systemd unit file from our template
##

echo "Writing unit file from template unit_file_template.service to /lib/systemd/system/${service_name}.service"
cp unit_file_template.service /lib/systemd/system/${service_name}.service
sed -i "s|{{SERVICE_NAME}}|${service_name}|g" /lib/systemd/system/${service_name}.service
sed -i "s|{{SERVICE_DESCRIPTION}}|${service_description}|g" /lib/systemd/system/${service_name}.service
sed -i "s|{{JAR_FILE_NAME}}|${jar_file_name}|g" /lib/systemd/system/${service_name}.service
chown root:root /lib/systemd/system/${service_name}.service
chmod 755 /lib/systemd/system/${service_name}.service

##
# Write the environment file to /etc
##
echo "Writing environment file to /etc/${service_name}/${service_name}"
mkdir -p /etc/${service_name}
cp ${environment_file_name} /etc/${service_name}/${service_name}

##
# Write the syslog config for the unit
##
if [ $use_syslog = "syslog" ]
    then		    
	echo "Syslog usage was elected...setting up syslog space in /var/log/${service_name}"
	
	mkdir -p /var/log/${service_name}
	chown syslog:${service_name} /var/log/${service_name}
	chmod 755 /var/log/${service_name}
	touch /var/log/${service_name}/${service_name}.log
	chown syslog:${service_name} /var/log/${service_name}/${service_name}.log
	chmod 755 /var/log/${service_name}/${service_name}.log

	echo "Configuring syslog"
        sed -i "s|#module(load=\"imtcp\")|module(load=\"imtcp\")|g" /etc/rsyslog.conf
        sed -i "s|input(type=\"imtcp\" port=\"514\")|input(type=\"imtcp\ port\"514\")|g" /etc/rsyslog.conf
        echo -e "if \$programname == '${service_name}' or \$syslogtag == '${service_name}' then /var/log/${service_name}/${service_name}.log & stop" > /etc/rsyslog.d/30-${service_name}.conf

	echo "Reloading rsyslog"
        systemctl restart rsyslog
fi

##
# Install the jar file 
##

echo "Copying the jar file ${jar_file_name} to /opt/${service_name}/${jar_file_name}"
mkdir -p /opt/${service_name}
cp ${jar_file_name} /opt/${service_name}/${jar_file_name}
chown -R /opt/${service_name}/
chmod g+x root:${service_name} /opt/${service_name}/${jar_file_name}

echo "Reloading systemd daemon"
systemctl daemon-reload

echo "Enabling systemd unit ${service_name}.service"
systemctl enable ${service_name}.service

echo "Restarting systemd unit ${service_name}"
systemctl restart ${service_name}
