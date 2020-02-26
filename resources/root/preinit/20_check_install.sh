#!/bin/bash
if [ ! -d ${ARTIFACTS_FOLDER}libs ]; then
	mkdir -v -p ${ARTIFACTS_FOLDER}libs
fi

echo "Writing properties file to contain list of JARs used by the OpenCms core, to be used in later updates."
JAR_NAMES=$( zipinfo -1 ${ARTIFACTS_FOLDER}opencms.war *.jar | tr '\n' ',' )
JAR_NAMES_PROPERTIES="OPENCMS_CORE_LIBS=$JAR_NAMES"
JAR_NAMES_PROPERTIES_FILE=${ARTIFACTS_FOLDER}libs/core-libs.properties
echo "$JAR_NAMES_PROPERTIES" > $JAR_NAMES_PROPERTIES_FILE

if [ ! -d ${WEBAPPS_HOME} ]; then
	mkdir -v -p ${WEBAPPS_HOME}
fi

echo "Unzip the .war"
unzip -q -d ${OPENCMS_HOME} ${ARTIFACTS_FOLDER}opencms.war

mv ${ARTIFACTS_FOLDER}libs/core-libs.properties ${OPENCMS_HOME}/WEB-INF/lib

echo ""
echo "---------------------"
echo "Write DB config file"
sed -i -e "s/__DB_HOST__/${DB_HOST}/g" ${APP_HOME}config/opencms.properties
sed -i -e "s/__DB_NAME__/${DB_NAME}/g" ${APP_HOME}config/opencms.properties
sed -i -e "s/__DB_USER__/${DB_USER}/g" ${APP_HOME}config/opencms.properties
sed -i -e "s/__DB_PASSWD__/${DB_PASSWD}/g" ${APP_HOME}config/opencms.properties
echo "---------------------"
echo ""

cp -v ${OPENCMS_HOME}/WEB-INF/config/opencms.properties ${OPENCMS_HOME}/WEB-INF/config/opencms.properties.orig
cp -v ${APP_HOME}config/opencms.properties ${OPENCMS_HOME}/WEB-INF/config/

if [ ! -z "$ADMIN_PASSWD" ]; then
	echo "Changing Admin password for setup"
	sed -i -- "s/login \"Admin\" \"admin\"/login \"Admin\" \"admin\"\nsetPassword \"Admin\" \"$ADMIN_PASSWD\"\nlogin \"Admin\" \"$ADMIN_PASSWD\"/g" "${OPENCMS_HOME}/WEB-INF/setupdata/cmssetup.txt"
fi

pwd
cd ${OPENCMS_HOME}/WEB-INF/
echo "java -classpath "${OPENCMS_HOME}/WEB-INF/classes/:${OPENCMS_HOME}/WEB-INF/lib/*:${TOMCAT_LIB}/*" org.opencms.main.CmsShell -script=${APP_HOME}config/check-if-installed.ocsh"
java -classpath "${OPENCMS_HOME}/WEB-INF/classes/:${OPENCMS_HOME}/WEB-INF/lib/*:${TOMCAT_LIB}/*" org.opencms.main.CmsShell -script=${APP_HOME}config/check-if-installed.ocsh > ${APP_HOME}app.log

if grep -q "path: /system/modules/org.opencms.base/.config," /home/app/app.log
then

	echo "OpenCms installed"

else

	cp -v ${OPENCMS_HOME}/WEB-INF/config/opencms.properties.orig ${OPENCMS_HOME}/WEB-INF/config/opencms.properties

	echo "Install OpenCms using org.opencms.setup.CmsAutoSetup with properties \"${CONFIG_FILE}\"" && \
	java -classpath "${OPENCMS_HOME}/WEB-INF/lib/*:${OPENCMS_HOME}/WEB-INF/classes:${TOMCAT_LIB}/*" org.opencms.setup.CmsAutoSetup -path ${CONFIG_FILE}

fi

echo "Deleting no longer  used files"
rm -rfv ${OPENCMS_HOME}/setup
rm -rfv ${OPENCMS_HOME}/WEB-INF/packages/modules/*.zip