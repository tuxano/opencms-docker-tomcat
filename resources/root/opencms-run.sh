#!/bin/bash

# OpenCms startup script executed when Docker loads the image

# Set the timezone
echo "Adjusting the timezone"
bash ${APP_HOME}root/set-timezone.sh ${TIME_ZONE}

ls ${APP_HOME}root/preinit/

chmod -v +x ${APP_HOME}root/preinit/*.sh

ls ${APP_HOME}root/postinit/

chmod -v +x ${APP_HOME}root/postinit/*.sh


# Execute pre-init configuration scripts
bash ${APP_HOME}root/process-script-dir.sh ${APP_HOME}root/preinit runonce

echo "Starting OpenCms / Tomcat in background"
${TOMCAT_HOME}/bin/catalina.sh run &> ${TOMCAT_HOME}/logs/catalina.out &

# Write startup time to file
date > ${OPENCMS_HOME}/WEB-INF/opencms-starttime

# Execute post-init configuration scripts
bash ${APP_HOME}root/process-script-dir.sh ${APP_HOME}root/postinit runonce

# We need a running process for docker
sleep 10000d
