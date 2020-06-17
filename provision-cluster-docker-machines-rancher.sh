#!/bin/sh

FOLDER="$(realpath "$(dirname "$0")")"

PATH=$PATH:$FOLDER/bin

function usage(){
	echo "provision-cluster-docker-machine-rancher.sh {number_of_nodes} {project name} {project description} {template name} {set default project} {nodes_prefix} [-f]"
	echo "  number_of_nodes (mandatory)       Numeber of nodes to add to this project/kubernetes cluster"
	echo "  project name (mandatory)          Prefix used to Name Project/Environment"
	echo "  project description (mandatory)   Prefix used to Describe Project/Environment"
	echo "  template name (mandatory)         Environment Template Name (Kubernetes, Mesos, Cattle, Windows, Swarm, or custom templates )"
	echo "  set default project (mandatory)   Set new as default Environment (yes or no)"
	echo "  nodes_prefix (optional)           Prefix used to create VMs and recover master node"
	echo "  -f (optional)     		          Force and create environment without questions"
	echo "Use: provision-cluster-docker-machine-rancher.sh [-h|--help] for this help"
	echo "Use: provision-cluster-docker-machine-rancher.sh [-l|--list] {nodes_prefix} for list of available projects"
}

if [ "-h" = "$1" ] || [ "--help" = "$1" ]; then
	echo -e "$(usage)"
	exit 0
fi

if [ "-l" = "$1" ] || [ "--list" = "$1" ]; then
	source $FOLDER/functions-lib.sh
	echo "Available projects: "
	RANCHER_MASTER_NODE_IP="$(getMasterNodeIp "$(fixIdValue "$2")")"
	echo -e "$(listAvailableProjects "$RANCHER_MASTER_NODE_IP")"
	exit 0
fi

if [ $# -lt 4 ]; then
	echo -e "$(usage)"
	exit 1
fi

function printArguments() { 
	echo " "
	echo "Summary:"
	echo "-------------------------------------"
	echo "Rancher Environment Id: $1"
	echo "Rancher Environment Name: $2"
	echo "Rancher Environment  Description: $3"
	echo "-------------------------------------"
	echo " "
}

source $FOLDER/functions-lib.sh

RANCHER_NODES=$1

if [ "" = "$RANCHER_NODES" ] && [ "" != "$RANCHER_DEFAULT_NODES" ] && [ "true" = "$(checkNumber $RANCHER_DEFAULT_NODES)" ]; then
	RANCHER_NODES=$RANCHER_DEFAULT_NODES
fi

if [ "" = "$RANCHER_NODES" ]; then
	echo "Unable to find number of nodes..."
	exit 1
fi

PROJECT_NAME="$2"
#format correctly project name lower case and spaces as '-'
PREFIX="$(fixIdValue "$6")"
DEF_VAR="$5"
SET_DEFAULT="false"
TEMPLATE_NAME="$4"
PROJECT_NAME="$(echo ${PROJECT_NAME,,}|sed -e 's/ /-/g')-${TEMPLATE_NAME,,}-env"
PROJECT_DESCR="$3 ${TEMPLATE_NAME} Environment"
if [ "yes" = "${DEF_VAR,,}" ]; then
	SET_DEFAULT="true"
fi

if [ -e $FOLDER/.settings/.${PREFIX}projects ]; then
	EXISTS="$(cat $FOLDER/.settings/.${PREFIX}projects | grep ":${PROJECT_NAME}")"
	if [ "" != "$EXISTS" ]; then
		echo "Project ${PROJECT_NAME} already present in projects file, please choose another name!!"
		exit 1
	fi
fi


echo "Provisioning infrastructure -> prefix: $PREFIX type: $TEMPLATE_NAME ..."

echo "Rancher Project: $PROJECT_NAME"

echo "Rancher Project Docker Machines Prefix: $PREFIX"

PROJECT_ID=""


CMD_PREFIX=""
if [ "windows" = "$($FOLDER/bin/os.sh)" ]; then
	CMD_PREFIX="$FOLDER/bin/"
else
	if [ "" = "$(which curl 2> /dev/null)" ]; then
		echo "Please install curl and check if you have installed jq, before proceed ..."
		exit 1
	fi
	if [ "" = "$(which jq 2> /dev/null)" ]; then
		echo "Please install jq, before proceed ..."
		exit 1
	fi
fi

if [ "-f" != "$7" ]; then 
	ANSWER=""
	while [ "y" != "$ANSWER" ] && [ "Y" != "$ANSWER" ] && [ "n" != "$ANSWER" ] && [ "N" != "$ANSWER" ]; do
		read -p "Do you agree with given input arguments? [y/N]: " ANSWER
	done
	if [ "n" = "$ANSWER" ] || [ "N" = "$ANSWER" ]; then
		echo "User required exit ..."
		exit 0
	fi
fi

MEMORY="1024"
#DISKSIZE="25000"
DISKSIZE="10000"
CORES="2"

loadOptionalFiles "$ENGINE"

ENGINE=""
if [ -e $FOLDER/.settings/.${PREFIX}hypervisor ]; then
	source $FOLDER/.settings/.${PREFIX}hypervisor
else
	echo "Engine: Missing hypervisor creation data in file: $FOLDER/.settings/.${PREFIX}hypervisor, exiting..."
	exit 1
fi
if [ "" = "$ENGINE" ]; then
	echo "Engine: Missing Docker Machine Driver data into file: $FOLDER/.settings/.${PREFIX}hypervisor, exiting..."
	exit 1
fi

echo -e "$(validateEngine "$ENGINE" "$(usage)")"

echo "Default VM attributes:"
echo -e "$(printVMAttributes)"
echo " "
echo " "


RANCHER_MASTER_NODE_NAME="$(getMasterNodeName "${PREFIX}")"

if [ "" = "$RANCHER_MASTER_NODE_NAME" ]; then
	echo "Rancher MASTER node name NOT available!!"
	exit 1
fi

echo "Rancher MASTER node: $RANCHER_MASTER_NODE_NAME"

RANCHER_MASTER_NODE_IP="$(getMasterNodeIp "${PREFIX}")"

if [ "" = "$RANCHER_MASTER_NODE_IP" ]; then
	echo "Rancher MASTER node $RANCHER_MASTER_NODE_NAME NOT reported in docker-machine!!"
	exit 1
fi

echo "Rancher MASTER node IP: $RANCHER_MASTER_NODE_IP"


echo " "
echo " "
echo "Creating Environment with following information:"
echo "---------------------------------"
echo "Project Name: $PROJECT_NAME"
echo "Project Description: $PROJECT_DESCR"
echo "Number of new nodes: $RANCHER_NODES"
echo "Rancher MASTER node: $RANCHER_MASTER_NODE_NAME"
echo "Rancher MASTER node ip: $RANCHER_MASTER_NODE_IP"
echo "---------------------------------"
echo " "
echo " "

ISO_IMAGE="$(getIsoImage "$ENGINE")"
echo "Using Docker ISO Image: $ISO_IMAGE"
echo " "

IP_W=()
FROM_ID=$(findFirstAvailableNodeId "$PREFIX")
MAX_ID=$RANCHER_NODES
let MAX_ID=MAX_ID+FROM_ID
echo "Creating Workers from id : $FROM_ID (included) to id: $MAX_ID (excluded)"
for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
	MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
	echo "Creating Rancher WORKER node #${i} : $MACHINE_NAME ..."
	HYPERVISOR_CMD="$(calculateMachineResource "$ENGINE" "false" $i "$(usage)")"
	if [ "" != "$ISO_IMAGE" ]; then
		HYPERVISOR_CMD="$HYPERVISOR_CMD $ISO_IMAGE"
	fi
	echo "Rancher WORKER node #${i} - VM creation arguments: $HYPERVISOR_CMD"
	docker-machine create $HYPERVISOR_CMD "${MACHINE_NAME}"
	CREATE_EXIT_CODE="$?"
	sleep 10
	if [ "0" != "$CREATE_EXIT_CODE" ] && [ "127" != "$CREATE_EXIT_CODE" ]; then
		echo "Rancher WORKER node #${i} creation exit code : $CREATE_EXIT_CODE"
		echo "Trying regenerating host certificates ..."
		docker-machine regenerate-certs  --force "${MACHINE_NAME}"
	fi
	if [ "-gce" = "$ENGINE" ]; then
		echo "Rancher WORKER node #${i}: installing docker on host ..."
		docker-machine ssh "${MACHINE_NAME}" "echo '$( cat $FOLDER/install-docker.sh )' > ./install-docker.sh && chmod 777 ./install-docker.sh && ./install-docker.sh"
	fi
	echo "Rancher WORKER node #${i} installing curl container ..."
	docker-machine ssh "${MACHINE_NAME}" "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
	docker-machine ssh "${MACHINE_NAME}" "sudo mkdir -p var/etcd/backups"
	IP_WORKER="$(getWorkerNodeIp "$PREFIX" "${i}")"
	IP_W[${i}]="$IP_WORKER"
	echo "Created Rancher WORKER node #${i} With Ip Address: $IP_WORKER"
done


echo "Seeking for Project Template '$TEMPLATE_NAME' Id..."
TEMPLATES_LIST_JSON="$(selectTemplateListJson "$RANCHER_MASTER_NODE_IP")"
TEMPLATE_ID="$(selectTemplate "$RANCHER_MASTER_NODE_IP" "$TEMPLATE_NAME")"
echo "Using Project Template ($TEMPLATE_NAME) Id: $TEMPLATE_ID"
if [ "" = "$TEMPLATE_ID" ] || [ "false" = "$(checkProjectId "$TEMPLATE_ID")" ]; then
	echo "Project Template $TEMPLATE_NAME: Unable to discover Id on $RANCHER_MASTER_NODE_NAME!!"
	TEMPLATES_LIST_JSON="$(selectTemplateListJson "$RANCHER_MASTER_NODE_IP")"
	echo "Template List: $TEMPLATES_LIST_JSON"
	for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
		MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
		echo "Removing Rancher WORKER node #${i} : $MACHINE_NAME ..."
		docker-machine rm -f "$MACHINE_NAME"
		sleep 10
	done
	exit 1
fi
PROJECT_OUT="$(createProject "$RANCHER_MASTER_NODE_IP" "$PROJECT_NAME" "$PROJECT_DESCR" "$TEMPLATE_ID")"
if [ "-f" != "$7" ]; then
	echo "Project Creation Output: $PROJECT_OUT"
fi
PROJECT_ID="$(echo "$PROJECT_OUT"|${CMD_PREFIX}jq -r '.id')"
echo "Created Project with Id: $PROJECT_ID"
if [ "" = "$PROJECT_ID" ] || [ "false" = "$(checkProjectId "$PROJECT_ID")" ]; then
	echo "Rancher master node $RANCHER_MASTER_NODE_NAME: Unable to create project (id: $PROJECT_ID) with name: ${PROJECT_NAME}!!"
	for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
		MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
		echo "Removing Rancher WORKER node #${i} : $MACHINE_NAME ..."
		docker-machine rm -f "$MACHINE_NAME"
		sleep 10
	done
	exit 1
fi

echo "${PROJECT_ID}:${PROJECT_NAME}" >> $FOLDER/.settings/.${PREFIX}projects

echo " "
echo "Waiting for grace time (20 secs) allowing Environment: '$PROJECT_NAME' complete build ...."
sleep 20
echo " "
echo " "
HOSTS_REGISTRATION_TIMEOUT=180
if [ "" != "$DEFAULT_HOSTS_REGISTRATION_TIMEOUT" ] && [ "true" = "$(checkNumber $DEFAULT_HOSTS_REGISTRATION_TIMEOUT)" ]; then
	HOSTS_REGISTRATION_TIMEOUT=$DEFAULT_HOSTS_REGISTRATION_TIMEOUT
fi
for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
	MACHINE_NAME="$(getWorkerNodeName "${PREFIX}" "${i}")"
	echo "Affiliating to project: '$PROJECT_NAME' Rancher WORKER node #${i} : $MACHINE_NAME ..."
	STATE="$(${CMD_PREFIX}curl -sL -X POST -H 'Accept: application/json' http://$RANCHER_MASTER_NODE_IP:8080/v2-beta/projects/$PROJECT_ID/registrationtokens> /dev/null|${CMD_PREFIX}/jq -r '.state' 2> /dev/null)"
	if [ "active" != "$STATE" ]; then
		REG_TOKEN_REFERENCE="$(${CMD_PREFIX}curl -sL -X POST -H 'Accept: application/json' http://$RANCHER_MASTER_NODE_IP:8080/v2-beta/projects/$PROJECT_ID/registrationtokens 2> /dev/null|${CMD_PREFIX}/jq -r '.actions.activate' 2> /dev/null | grep -v null)"
		sleep 5
		COMMAND="$(${CMD_PREFIX}curl -s -X GET $REG_TOKEN_REFERENCE 2> /dev/null | ${CMD_PREFIX}jq -r '.command' 2> /dev/null)"
	else
		echo "Running: ${CMD_PREFIX}curl -sL -X POST -H 'Accept: application/json' http://$RANCHER_MASTER_NODE_IP:8080/v2-beta/projects/$PROJECT_ID/registrationtokens?state=active&limit=-1&sort=name 2> /dev/null|${CMD_PREFIX}/jq -r '.command' 2> /dev/null | grep -v null"
		COMMAND="$(${CMD_PREFIX}curl -sL -X POST -H 'Accept: application/json' http://$RANCHER_MASTER_NODE_IP:8080/v2-beta/projects/$PROJECT_ID/registrationtokens?state=active&limit=-1&sort=name 2> /dev/null|${CMD_PREFIX}/jq -r '.command' 2> /dev/null | grep -v null)"
	fi
	echo "Rancher WORKER node #${i} Command: $COMMAND"
	if [ "" != "$COMMAND" ]; then
		docker-machine ssh "${MACHINE_NAME}" "$COMMAND --address eth0"
	else
		echo "Please register your WORKER HOST ${MACHINE_NAME} manually on the web interface at: http://$RANCHER_MASTER_NODE_IP:8080 -> Host"
	fi
	echo "Waiting for grace time (${HOSTS_REGISTRATION_TIMEOUT} secs) allowing Node: '$MACHINE_NAME' affiliation process ends ...."
	sleep ${HOSTS_REGISTRATION_TIMEOUT}
done

echo "Waiting for grace time (30 secs)  allowing Environment: '${PROJECT_NAME}' ${TEMPLATE_NAME} Nodes Provisioning starts ...."
sleep 30

if [ "$SET_DEFAULT" = "true" ]; then
	echo "Setting up Project: $PROJECT_NAME as default environment"
	DEFAULT="$(assignProjectToDefault "$RANCHER_MASTER_NODE_IP" "$PROJECT_ID")"
	echo "Default Environment Setting Up Response: $DEFAULT"
else
	echo "Prject $PROJECT_NAME will not be setted up as DEFAULT Environment!!"
fi

echo -e "$(printArguments "${PROJECT_ID}" "${PROJECT_NAME}" "${PROJECT_DESCR}")"


echo "--------------------------------------------------------------------"
echo "Rancher Nodes List"
echo "--------------------------------------------------------------------"
echo "Rancher Master Node: $RANCHER_MASTER_NODE_IP"
echo "PROJECT_ID=${PROJECT_ID}" > $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
echo "PROJECT_NAME=${PROJECT_NAME}" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
echo "KUBECTL_CONFIG_FILE=$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-config.yml" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
echo "FROM_ID=${FROM_ID}" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
echo "MAX_ID=${MAX_ID}" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
echo "RANCHER_MASTER_NODE=${RANCHER_MASTER_NODE_NAME}:${RANCHER_MASTER_NODE_IP}" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
for (( i=$FROM_ID; i<$MAX_ID; i++ )); do
	IP_X="${IP_W[${i}]}"
	echo "Rancher WORKER Node #${i}: $IP_X"
	echo "RANCHER_WORKER_NODE_${i}=$(getWorkerNodeName "${PREFIX}" "${i}"):${IP_X}" >> $FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env
done
echo "--------------------------------------------------------------------"
echo "  "
echo "  "
echo "--------------------------------------------------------------------"
echo "Rancher Services Url(s)"
echo "--------------------------------------------------------------------"
echo "Rancher Server: http://$RANCHER_MASTER_NODE_IP:8080"
echo "--------------------------------------------------------------------"
echo "  "
echo "  "


echo "Project id: $PROJECT_ID"
echo "Project name: $PROJECT_NAME"
echo "Cluster id prefix: $CLUSTER_ID"
echo " "

echo "Available Catalogs for Project '$PROJECT_NAME':"
CATALOGS_VALUE="$(retrieveGETCallFromServer "$RANCHER_MASTER_NODE_IP" "projects/$PROJECT_ID/settings/catalog.url" "value" "$CMD_PREFIX" )"
if [ "" != "$CATALOGS_VALUE" ]; then
	echo -e "$(echo "$CATALOGS_VALUE" | ${CMD_PREFIX}jq -r '.catalogs' )"
else
	echo "No catalogs found!!"
fi
echo " "
echo " "
echo "Please be patient and wait for $TEMPLATE_NAME Cluster is up"
if [ "Kubernetes" = "$TEMPLATE_NAME" ]; then
	echo "Then please download key/config for Helm and Use the Rancher Serer Web-UI Kubernetes -> Kubernetes -> CLI -> Create Config -> Copy Config "
	echo "Then paste and save the configuration into this project folder: $FOLDER/.settings using file name: ${PREFIX}${PROJECT_NAME}-config.yml "
	echo "You can now use 'kubectl --kubeconfig=$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-config.yml ....' (to run kubectl commands on the K8s cluster)"
	echo "Or you can use 'export KUBECONFIG=$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-config.yml' to use helm charts/commands running on the K8s cluster"
fi
echo " "
echo "Enjoy the use of the new $TEMPLATE_NAME cluster!!"

exit 0