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

	if [ ! -z "$ADMIN_PASSWD" ]; then
		echo "Changing Admin password for update"
		sed -i -- "s/Admin admin/\"Admin\" \"${ADMIN_PASSWD}\"/g" ${APP_HOME}config/update*
	fi

	echo "Extract modules and libs"
	unzip -q -d ${ARTIFACTS_FOLDER}TEMP ${ARTIFACTS_FOLDER}opencms.war
	mv ${ARTIFACTS_FOLDER}TEMP/WEB-INF/packages/modules/* ${ARTIFACTS_FOLDER}

	mv ${ARTIFACTS_FOLDER}TEMP/WEB-INF/lib/* ${ARTIFACTS_FOLDER}libs
	echo "Renaming modules to remove version number"
	for file in ${ARTIFACTS_FOLDER}*.zip
	do
   		mv $file ${file%-*}".zip"
	done

	echo "Creating backup of opencms-modules.xml at ${OPENCMS_HOME}/WEB-INF/config/backups/opencms-modules-preinst.xml"
	if [ ! -d ${OPENCMS_HOME}/WEB-INF/config/backups ]; then
		mkdir -v -p ${OPENCMS_HOME}/WEB-INF/config/backups
	fi
	cp -f -v ${OPENCMS_HOME}/WEB-INF/config/opencms-modules.xml ${OPENCMS_HOME}/WEB-INF/config/backups/opencms-modules-preinst.xml
	
	echo "Updating config files with the version from the OpenCms WAR"
	unzip -q -o -d ${OPENCMS_HOME} ${ARTIFACTS_FOLDER}opencms.war WEB-INF/packages/modules/*.zip WEB-INF/lib/*.jar
	IFS=',' read -r -a FILES <<< "$UPDATE_CONFIG_FILES"
	for FILENAME in ${FILES[@]}
	do
		if [ -f "${OPENCMS_HOME}${FILENAME}" ]
		then
			rm -rf "${OPENCMS_HOME}${FILENAME}"
		fi
		echo "Moving file from \"${ARTIFACTS_FOLDER}TEMP/${FILENAME}\" to \"${OPENCMS_HOME}${FILENAME}\" ..."
		mv "${ARTIFACTS_FOLDER}TEMP/${FILENAME}" "${OPENCMS_HOME}/${FILENAME}"
	done

	echo "Updating OpenCms core JARs"
	if [ -f ${OPENCMS_HOME}/WEB-INF/lib/core-libs.properties ]; then
		echo "Deleting old JARs first"
		while IFS='=' read -r key value
		do
			key=$(echo $key | tr '.' '_')
			eval ${key}=\${value}
		done < "${OPENCMS_HOME}/WEB-INF/lib/core-libs.properties"

		IFS=',' read -r -a CORE_LIBS <<< "$OPENCMS_CORE_LIBS"
		for CORE_LIB in ${CORE_LIBS[@]}
		do
			rm -f -v ${OPENCMS_HOME}/${CORE_LIB}
		done
	fi
	echo "Moving new JARs"
	mv ${ARTIFACTS_FOLDER}libs/* ${OPENCMS_HOME}/WEB-INF/lib/

	echo "Update modules core"
	bash ${APP_HOME}root/execute-opencms-shell.sh ${APP_HOME}config/update-core-modules.ocsh ${OPENCMS_HOME}

else

	cp -v ${OPENCMS_HOME}/WEB-INF/config/opencms.properties.orig ${OPENCMS_HOME}/WEB-INF/config/opencms.properties

	echo "Install OpenCms using org.opencms.setup.CmsAutoSetup with properties \"${CONFIG_FILE}\"" && \
	java -classpath "${OPENCMS_HOME}/WEB-INF/lib/*:${OPENCMS_HOME}/WEB-INF/classes:${TOMCAT_LIB}/*" org.opencms.setup.CmsAutoSetup -path ${CONFIG_FILE}

fi

echo "Deleting no longer  used files"
rm -rfv ${OPENCMS_HOME}/setup
rm -rfv ${OPENCMS_HOME}/WEB-INF/packages/modules/*.zip