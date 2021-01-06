#!/bin/bash

#Order of operation
## - Start DB
## - Start ACS
## - Start SOLR

printf "\n------------------------------ Starting services ------------------------- \n"

#User can pass ALF_HOME path. Defaults to "/opt/alfresco-community62ga".
export ALF_HOME=${1:-"/opt/alfresco-community62ga"}
#User can pass SOLR_HOME path. Defaults to "/opt/alfresco-search-services".
export SOLR_HOME=${2:-"/opt/alfresco-search-services"}

export CATALINA_HOME=$ALF_HOME/tomcat
export CATALINA_TMPDIR=$CATALINA_HOME/temp
export JRE_HOME=$JAVA_HOME

# Check if JRE_HOME is set in path varible or not, else set default path. It is mandatory for acs to start
if [ -z "$JRE_HOME" ]
then
  echo "JRE_HOME could not be found, setting the default..." 
  export JRE_HOME="/usr/lib/jvm/java-11"
fi

#Export JRE_HOME to PATH
export PATH=$PATH:$JRE_HOME/bin

# Check if ALF_HOME is set in path varible or not, we may need it for executing shell scripts as needed.
if [[ "$PATH" == *"$ALF_HOME"* ]]; then
  echo "$ALF_HOME already set in PATH variable."
else
  export PATH=$PATH:$ALF_HOME
fi

# Check if SOLR_HOME is set in path varible or not, we may need it for executing shell scripts as needed.
if [[ "$PATH" == *"$SOLR_HOME"* ]]; then
  echo "$SOLR_HOME already set in PATH variable."
else
  export PATH=$PATH:$SOLR_HOME
fi

#User need to pass this param on initial startup in order to create the cores. if core values are not passed then default 'alfresco and archive' will be used.
SOLR_CORES=${3:-"alfresco,archive"}

JAVA_OPTS="-Xms1G -Xmx2G -Xss1024k"
JAVA_OPTS="${JAVA_OPTS} -XX:+UseG1GC -XX:+UseStringDeduplication"
JAVA_OPTS="${JAVA_OPTS} -Djava.security.egd=file:/dev/./urandom"
JAVA_OPTS="${JAVA_OPTS} -Djava.io.tmpdir=${CATALINA_TMPDIR}"
JAVA_OPTS="${JAVA_OPTS} -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
JAVA_OPTS="${JAVA_OPTS} -Dalfresco.home=${ALF_HOME} -Dcom.sun.management.jmxremote=true"
JAVA_OPTS="${JAVA_OPTS} -server"


echo "-------------------------------------------"
echo CATALINA_HOME: $CATALINA_HOME
echo CATALINA_TMPDIR: $CATALINA_TMPDIR
echo JRE_HOME: $JRE_HOME
echo JAVA_OPTS: $JAVA_OPTS
echo PATH: $PATH
echo SOLR_HOME: $SOLR_HOME
echo ALF_HOME: $ALF_HOME
echo "-------------------------------------------"

StartDB() {
	printf "\nStarting Postgressql... \n"
	#sudo systemctl start postgresql-11.service
	
	if [[ $? = 0 ]]
        then
	   echo "postgresql-11.service started successfully."
	else
	   echo "Failed to start postgresql-11.service!"
	   exit 1
        fi
}

StartACS() {
        printf "\nStarting Alfresco Tomcat... \n"
	#sudo systemctl start tomcat.service
	
	if [[ $? = 0 ]]
	then
           echo "tomcat service started successfully."
	else
	   echo "Failed to start tomcat service!"
	   exit 1
        fi
}

StartSOLR() {

	#flag for creating the cores on first startup
	INITIAL=false
		
	#Setting the context to solrhome
	cd $SOLR_HOME/solrhome
	for CORE in ${SOLR_CORES//,/ }
        do
	   echo "Checking availablity of the core: $CORE"
	   if [ -d "$CORE" ]; then
              echo "'$CORE' found.."
	      INITIAL=false
	   else
	      echo "Warning: '$CORE' NOT found."
   	      INITIAL=true
	   fi
        done
	  
        #Going back to original context
        cd $ALF_HOME
	
        if [[ $INITIAL == true ]]; then
	   printf "\nStarting solr6 with initial mode, core '$SOLR_CORES' will be created... \n"
           sudo -u solr $SOLR_HOME/solr/bin/solr start -a "-Dcreate.alfresco.defaults=alfresco,archive"
        else
           
           printf "\nStarting solr6... \n"
    	   sudo systemctl start solr.service
	   if [[ $? = 0 ]]
	   then
	     echo "solr6 service started successfully."
	   else
	     echo "Failed to start solr6 service!"
	     exit 1
    	   fi
       fi
}

tailLogs() {
	multitail -ci green $ALF_HOME/alfresco.log -ci yellow -I $ALF_HOME/share.log
}

###################################

StartDB
StartACS
StartSOLR

###################################
