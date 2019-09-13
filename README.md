## Overview

This script will install your Spring Boot executable jar as a systemd service

It has been tested on Ubuntu 18.04

Once your install succeeds you can use the following to control your app like a service

* `systemctl enable service-name.service` - Enables the service for use
* `systemctl start service-name.service` - Starts the service
* `systemctl status service-name.service` - Check the status of the service
* `journalctl -f -u - service-name.service` Show the logs for the service

Note that for this script to work correctly all of the files must be in the current working directory.

The beautiful thing about this script is that it can be used to upgrade a service to the next build of a jar file by simply running it once more and providing a different arg for jar-file-name.

## Usage

The script takes 5 positional, non-optional arguments. It will confirm with you before running.

* $1 = Service Name
* $2 = Service Description
* $3 = Jar File Name
* $4 = Environment file name
* $5 = syslog|nosyslog
    * syslog - send logs to syslog
    * nosyslog - only use systemd journal

Example:

```

./springboot-systemd-installer.sh \
    my-service-name \
    "My Service Desription" \
    my-app-name.jar \
    my_env_file \
    syslog

```

Once the script runs it performs the following actions:

* Maps your positional arguments to global variables used by the script
* Confirms with the end user that we're going to make the right changes
* Creates a service account / user + group for the service to run as with no shell
* Copies and modifies a unit file template to suit your parameters passed in to /lib/systemd/system/my-service-name.service
* Writes the environment file to /etc so that your environment mapped app properties are read by the service on start up
* Modifies your syslog configuration enabling imtcp on port 514 and generates the syslog config file for your service 
* Installs your jar file at /opt/my-service-name/my-app-name.jar and changes the perms so that your service user can execute it
* Reloads the systemd daemon
* Enables your new service
* Starts the service

