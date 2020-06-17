#!/bin/sh

FOLDER="$(realpath "$(dirname "$0")")"


PATH=$PATH:$FOLDER/bin


function usage(){
	echo "destroy-docker-machine-rancher.sh {nodes_prefix}"
	echo "  nodes_prefix   	Prefix used to create VMs"
	echo "Use: destroy-docker-machine-rancher.sh [-h|--help] for this help"
}

if [ "-h" = "$1" ] || [ "--help" = "$1" ]; then
	echo -e "$(usage)"
	exit 0
fi

source $FOLDER/functions-lib.sh

PREFIX="$(fixIdValue "$1")"

echo "Destroying infrastructure -> prefix: $PREFIX ..."

MAX_ID=$(findFirstAvailableNodeId "$PREFIX")

for (( i=1; i<$MAX_ID; i++ )); do
	echo "Destroying Rancher WORKER node #${i} ..."
	MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
	docker-machine rm -f -y "${MACHINE_NAME}" 2> /dev/null
done

echo "Destroying Rancher MASTER node ..."
docker-machine rm -f -y "$(getMasterNodeName "${PREFIX}")" 2> /dev/null

INFRA_HYPERVISOR_FILE="$FOLDER/.settings/.${PREFIX}hypervisor"
if [ -e $INFRA_HYPERVISOR_FILE ]; then
	echo "Removing hpervisor file: $INFRA_HYPERVISOR_FILE"
	rm -f $INFRA_HYPERVISOR_FILE
fi

INFRA_PRJECTS_FILE="$FOLDER/.settings/.${PREFIX}projects"
if [ -e $INFRA_PRJECTS_FILE ]; then
	echo "Removing projects file: $INFRA_PRJECTS_FILE"
	PROJECTS="$(cat $INFRA_PRJECTS_FILE)"
	rm -f $INFRA_PRJECTS_FILE
	IFS=$'\n';for prj in $PROJECTS; do
		PROJECT_NAME="$(echo $prj|awk 'BEGIN {IFS=OFS=":"}{print $2}')"
		if [ "" != "$PROJECT_NAME" ]; then
			PROJECT_ID="$(echo $prj|awk 'BEGIN {IFS=OFS=":"}{print $1}')"
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
		fi
	done
fi

exit 0
