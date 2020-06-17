#!/bin/sh

FOLDER="$(realpath "$(dirname "$0")")"

PATH=$PATH:$FOLDER/bin

function usage(){
	echo "unregister-cluster-docker-machine-rancher.sh {cluster_name|cluster_id} {nodes_prefix} [-f]"
	echo "  cluster_name (mandatory)          Full Project/Environment name"
	echo "  cluster_id (mandatory)            Project/Environment rancher id (e.g.: 1a5)"
	echo "  nodes_prefix (optional)           Prefix used to create VMs and recover master node"
	echo "  -f (optional)     		          Force and create environment without questions"
	echo "Use: unregister-cluster-docker-machine-rancher.sh [-h|--help] for this help"
}

if [ "-h" = "$1" ] || [ "--help" = "$1" ]; then
	echo -e "$(usage)"
	exit 0
fi

if [ $# -lt 1 ]; then
	echo -e "$(usage)"
	exit 1
fi

source $FOLDER/functions-lib.sh

function printArgumentsAndNote() { 
	echo " "
	echo "Summary:"
	echo "-------------------------------------"
	echo "Rancher Cluster Id: $1"
	echo "Rancher Cluster Name: $2"
	echo "Note: $3"
	echo "-------------------------------------"
	echo " "
}

PREFIX="$(fixIdValue "$2")"
PROJECT_ID=
PROJECT_NAME=
TEXT=""
if [ -e $FOLDER/.settings/.${PREFIX}projects ]; then
	silentDos2Unix "$FOLDER/.settings/.${PREFIX}projects"
	TEXT=$(cat $FOLDER/.settings/.${PREFIX}projects | grep ":$1")
	if [ "" = "$TEXT" ]; then
		TEXT=$(cat $FOLDER/.settings/.${PREFIX}projects | grep "$1:")
	fi
	if [ "" != "$TEXT" ]; then
		# was found
		PROJECT_ID="$(echo "$TEXT"|awk 'BEGIN {FS=OFS=":"}{print $1}')"
		PROJECT_NAME="$(echo "$TEXT"|awk 'BEGIN {FS=OFS=":"}{print $2}')"
	else
		# Not found
		echo "Given Project Id/Name: $1 was not found in configuration ..."
		exit 1
	fi
else
	echo "System project file: $FOLDER/.settings/.${PREFIX}projects doesn't exist"
	exit 1
fi
DEFAULT="false"
NOTE=""
if [ "default" = "${PROJECT_NAME,,}" ]; then
	DEFAULT="true"
	NOTE="Removing Default Environment"
else
	NOTE="Removing ${PROJECT_NAME} Kubernetes Cluster"
fi

echo " "
echo " "
echo -e "$(printArgumentsAndNote "${PROJECT_ID}" "${PROJECT_NAME}" "${NOTE}")"
echo " "
echo " "

RANCHER_MASTER_NODE_NAME="$(getMasterNodeName "$PREFIX")"
RANCHER_MASTER_NODE_IP="$(getMasterNodeIp "$PREFIX")"
echo "Rancher Master Node (Name: ${RANCHER_MASTER_NODE_NAME}) Ip Address: ${RANCHER_MASTER_NODE_IP}"
echo " "
echo " "
if [ "" = "${RANCHER_MASTER_NODE_IP}" ]; then
	echo "Rancher Master Node: ${RANCHER_MASTER_NODE_NAME} is not available: Please bring it up, in case it's down ..."
	exit 1
fi

if [ "false" = "$DEFAULT" ]; then
	echo "Removing ${PROJECT_NAME} Cluster nodes ..."
	if [ -e $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env ]; then
		echo "Loading project: ${PROJECT_NAME} environment variables ..."
		source $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
		for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
			MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
			echo "Removing from project: '$PROJECT_NAME' Rancher WORKER node #${i} : $MACHINE_NAME ..."
			docker-machine rm --force -y "$MACHINE_NAME"
		done		
	else
		echo "Unable to find project file: $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env"
		exit 1
	fi
fi

echo "Deactivating ${PROJECT_NAME} project: ${PROJECT_ID} ..."
$(deleteProject "$RANCHER_MASTER_NODE_IP" "${PROJECT_ID}") 2> /dev/null
PROJECT_CONFIG_FILE="$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-config.yml"
if [ -e $PROJECT_CONFIG_FILE ]; then
	echo "Removing project (Id: $PROJECT_ID) helm config file: $PROJECT_CONFIG_FILE"
	rm -f $PROJECT_CONFIG_FILE
fi
PROJECT_NAMESPACES_FILE=$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-namespaces.yml
if [ -e $PROJECT_NAMESPACES_FILE ]; then
	echo "Removing project (Id: $PROJECT_ID) namespaces file: $PROJECT_NAMESPACES_FILE"
	NAMESPACES="$(cat $PROJECT_NAMESPACES_FILE)"
	rm -f $PROJECT_NAMESPACES_FILE
	IFS=$'\n';for ns in $NAMESPACES; do
		NS_NAME="$(echo $ns|awk 'BEGIN {IFS=OFS=":"}{print $1}')"
		NS_SUFFIX="$(echo $ns|awk 'BEGIN {IFS=OFS=":"}{print $2}')"
		PROJECT_NAMESPACE_FILE="$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-namespace-$NS_SUFFIX.yml"
		if [ -e $PROJECT_NAMESPACE_FILE ]; then
			echo "Removing project namespaces '$NS_NAME' file: $PROJECT_NAMESPACE_FILE"
			rm -f $PROJECT_NAMESPACE_FILE
		fi
		echo 
	done
fi
PROJECT_ENV_FILE=$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
if [ -e $PROJECT_ENV_FILE ]; then
	echo "Removing project (Id: $PROJECT_ID) project environment file: $PROJECT_ENV_FILE"
	rm -f $PROJECT_ENV_FILE
fi
echo "Removing project entry record in file: $FOLDER/.settings/.${PREFIX}projects"
cat $FOLDER/.settings/.${PREFIX}projects|grep -v "${PROJECT_ID}:${PROJECT_NAME}" > $FOLDER/.settings/.${PREFIX}projects

echo "Deactivation of project (Id: ${PROJECT_ID}): ${PROJECT_NAME} completed!!"
