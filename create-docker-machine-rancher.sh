#!/bin/sh

FOLDER="$(realpath "$(dirname "$0")")"

PATH=$PATH:$FOLDER/bin

function usage(){
	echo "create-docker-machine-rancher.sh [-hv|-vb|-gce|-aws] {nodes_prefix} [-f] [--no-prov]"
	echo "  -hv    		   Use Hyper-V provisioning provider"
	echo "  -vb    		   Use VirtualBox provisioning provider"
	echo "  -gce		   Use Google Cloud Engine provider"
	echo "  -aws		   Use Amazon Web Service EC2 provider"
	echo "  nodes_prefix   Prefix used to create VMs"
	echo "  -f     		   Force and create environment without questions"
	echo "  --no-prov	   Prevent to provision first cluster, and delete the default environment"
	echo "Use: create-docker-machine-rancher.sh [-h|--help] for this help"
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

RANCHER_NODES=2

if [ "" != "$RANCHER_DEFAULT_NODES" ] && [ "true" = "$(checkNumber $RANCHER_DEFAULT_NODES)" ]; then
	RANCHER_NODES=$RANCHER_DEFAULT_NODES
fi

RANCHER_ENVIRONMENT="Kubernetes"

if [ "" != "$RANCHER_DEFAULT_ENVIRONMENT_TEMPLATE" ]; then
	RANCHER_ENVIRONMENT="$RANCHER_DEFAULT_ENVIRONMENT_TEMPLATE"
fi


ENGINE="$1"
echo "Engine: $ENGINE"

if [ "-gce" = "$ENGINE" ] && [ -e $FOLDER/config/install-docker.sh ]; then
	silentDos2Unix "$FOLDER/config/install-docker.sh"
fi

echo "Loading eventually optinal files ..."
loadOptionalFiles "$ENGINE"

CMD_PREFIX=""

MEMORY="2048"
#DISKSIZE="25000"
DISKSIZE="15000"
CORES="3"
EXTRA_VARS="MEMORY=$MEMORY\nDISKSIZE=$DISKSIZE\nCORES=$CORES\n"

PREFIX="$(fixIdValue "$2")"
PASS_PRFX="$2"

if [ -e $FOLDER/.settings/.${PREFIX}hypervisor ]; then
	echo "Infrastructure ${PASS_PRFX} already present in .settings folder, please choose another prefix!!"
	exit 1
fi

echo "Creating infrastructure -> prefix: $PREFIX ..."

echo "Rancher Project: $PASS_PRFX"

echo "Rancher Project Docker Machines Prefix: $PREFIX"

if [ "windows" = "$($FOLDER/bin/os.sh)" ]; then
	echo " "
	echo "We assign to you custom curl and jq commands!!"
	echo " "
	CMD_PREFIX="$FOLDER/bin/"
else
	if [ "" = "$(which curl)" ]; then
		echo " "
		echo "Please install curl and check if you have installed jq, before proceed ..."
		echo " "
		exit 1
	fi
	if [ "" = "$(which jq)" ]; then
		echo " "
		echo "Please install jq, before proceed ..."
		echo " "
		exit 1
	fi
fi

echo -e "$(validateEngine "$ENGINE" "$(usage)")"

echo "Default VM attributes:"
echo -e "$(printVMAttributes $ENGINE)"
if [ "-f" != "$3" ]; then 
	ANSWER=""
	while [ "y" != "$ANSWER" ] && [ "Y" != "$ANSWER" ] && [ "n" != "$ANSWER" ] && [ "N" != "$ANSWER" ]; do
		read -p "Do you agree with given resources for used by 3 hosts? [y/N]: " ANSWER
	done

	CHANGES="no"

	while [ "n" = "$ANSWER" ] || [ "N" = "$ANSWER" ]; do
		if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
			read -p "Please provide memory used by any machine in MB? [default $MEMORY]: " MEM_INPUT
			if [ "" != "$MEM_INPUT" ]; then
				if [ "true" = "$(checkNumber "$MEM_INPUT")" ]; then
					CHANGES="yes"
				else
					MEM_INPUT="$MEMORY"
					echo "Memory parameter must be  number, we keep $MEMORY value"
				fi
			else
				MEM_INPUT="$MEMORY"
			fi
			read -p "Please provide disk size used by any machine in MB? [default $DISKSIZE]: " DISK_INPUT
			if [ "" != "$DISK_INPUT" ]; then
				if [ "true" = "$(checkNumber "$DISK_INPUT")" ]; then
					CHANGES="yes"
				else
					DISK_INPUT="$DISKSIZE"
					echo "Disk size parameter must be  number, we keep $DISKSIZE value"
				fi
			else
				DISK_INPUT="$DISKSIZE"
			fi
			read -p "Please provide host assigned CPU cores used by any machine? [default $CORES]: " CORES_INPUT
			if [ "" != "$CORES_INPUT" ]; then
				if [ "true" = "$(checkNumber "$CORES_INPUT")" ]; then
					CHANGES="yes"
				else
					CORES_INPUT="$CORES"
					echo "Host assigned CPU cores parameter must be  number, we keep $CORES value"
				fi
			else
				CORES_INPUT="$CORES"
			fi
		elif [ "-gce" = "$ENGINE" ]; then
			read -p "Please provide GCE project? [default $GOOGLE_PROJECT]: " GCE_PROJECT_INPUT
			if [ "" != "$GCE_PROJECT_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_PROJECT_INPUT="$GOOGLE_PROJECT"
				echo "GCE Project parameter must be not empty, we keep $GOOGLE_PROJECT value"
			fi
			read -p "Please provide GCE zone? [default $GOOGLE_ZONE]: " GCE_REGION_INPUT
			if [ "" != "$GCE_REGION_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_REGION_INPUT="$GOOGLE_ZONE"
				echo "GCE zone parameter must be not empty, we keep $GOOGLE_ZONE value"
			fi
			read -p "Please provide GCE machine type? [default $GOOGLE_MACHINE_TYPE]: " GCE_MACHINE_SIZE_INPUT
			if [ "" != "$GCE_MACHINE_SIZE_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_MACHINE_SIZE_INPUT="$GOOGLE_MACHINE_TYPE"
				echo "GCE machine type parameter must be not empty, we keep $GOOGLE_MACHINE_TYPE value"
			fi
			read -p "Please provide GCE machine image? [default $GOOGLE_MACHINE_IMAGE]: " GCE_MACHINE_IMAGE_INPUT
			if [ "" != "$GCE_MACHINE_IMAGE_INPUT" ]; then
				CHANGES="yes"
			else
				GCE_MACHINE_IMAGE_INPUT="$GOOGLE_MACHINE_IMAGE"
				echo "GCE machine type parameter must be not empty, we keep $GOOGLE_MACHINE_IMAGE value"
			fi
			read -p "Please provide GCE disk size used by any machine in MB? [default $GOOGLE_DISK_SIZE]: " GCE_DISK_SIZE_INPUT
			if [ "" != "$GCE_DISK_SIZE_INPUT" ]; then
				if [ "true" = "$(checkNumber "$GCE_DISK_SIZE_INPUT")" ]; then
					CHANGES="yes"
				else
					GCE_DISK_SIZE_INPUT="$GOOGLE_DISK_SIZE"
					echo "GCE Disk size parameter must be  number, we keep $GOOGLE_DISK_SIZE value"
				fi
			else
				GCE_DISK_SIZE_INPUT="$GOOGLE_DISK_SIZE"
			fi
		fi
		if [ "yes" = "$CHANGES" ]; then
			echo " "
			echo "Here applied changes:"
			echo -e "$(printNewVMAttributes "$ENGINE" "$MEM_INPUT" "$DISK_INPUT" "$CORES_INPUT" "$GCE_PROJECT_INPUT" "$GCE_REGION_INPUT" "$GCE_MACHINE_SIZE_INPUT" "$GCE_MACHINE_IMAGE_INPUT" "$GCE_DISK_SIZE_INPUT")"
		else
			echo " "
			echo "No changes done on the default VM attributes..."
			echo " "
		fi
		read -p "Do you agree with given resources for used by 3 hosts? [y/N]: " ANSWER
		if [ "yes" = "$CHANGES" ]; then
			if [ "y" = "$ANSWER" ] || [ "Y" = "$ANSWER" ]; then
				if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
					MEMORY="$MEM_INPUT"
					DISKSIZE="$DISK_INPUT"
					CORES="$CORES_INPUT"
					EXTRA_VARS="MEMORY=$MEM_INPUT\nDISKSIZE=$DISK_INPUT\nCORES=$CORES_INPUT\n"
				elif [ "-gce" = "$ENGINE" ]; then
					GOOGLE_PROJECT="$GCE_PROJECT_INPUT"
					GOOGLE_ZONE="$GCE_REGION_INPUT"
					GOOGLE_MACHINE_TYPE="$GCE_MACHINE_SIZE_INPUT"
					GOOGLE_MACHINE_IMAGE="$GCE_MACHINE_IMAGE_INPUT"
					GOOGLE_DISK_SIZE="$GCE_DISK_SIZE_INPUT"
					EXTRA_VARS="GOOGLE_PROJECT=$GCE_PROJECT_INPUT\nGOOGLE_ZONE=$GCE_REGION_INPUT\nGOOGLE_MACHINE_TYPE=$GCE_MACHINE_SIZE_INPUT\nGOOGLE_MACHINE_IMAGE=$GCE_MACHINE_IMAGE_INPUT\nGOOGLE_DISK_SIZE=$GCE_DISK_SIZE_INPUT\n"
				fi
			fi
		fi
	done
fi


if [ ! -e $FOLDER/.settings ]; then
	mkdir $FOLDER/.settings
fi

echo "ENGINE=$ENGINE" > "$FOLDER/.settings/.${PREFIX}hypervisor"
if [ "" != "$EXTRA_VARS" ]; then
	echo -e "$EXTRA_VARS" >> "$FOLDER/.settings/.${PREFIX}hypervisor"
fi
silentDos2Unix "$FOLDER/.settings/.${PREFIX}hypervisor"
echo " "
echo "Created $FOLDER/.settings/.${PREFIX}hypervisor invironment file!!"
echo "Content:"
cat "$FOLDER/.settings/.${PREFIX}hypervisor"
echo " "
echo " "
if [ "--no-prov" != "$3" ] && [ "--no-prov" != "$4" ]; then 
	echo "Number of workers: $RANCHER_NODES"
else
	echo "Number of workers: <NO FIRST RANCHER CLUSTER>"
fi
echo " "
MASTER_NODE_NAME="$(getMasterNodeName "${PREFIX}")"
echo "Creating Rancher MASTER node: $MASTER_NODE_NAME ..."

MACHINE_RESOURCES="$(calculateMachineResource "$ENGINE" "true" 0 "$(usage)")"

echo " "
ISO_IMAGE="$(getIsoImage "$ENGINE")"
echo "Using Docker ISO Image: $ISO_IMAGE"
echo " "

if [ "" != "$ISO_IMAGE" ]; then
	MACHINE_RESOURCES="$MACHINE_RESOURCES $ISO_IMAGE"
fi
echo "Rancher MASTER node - VM creation arguments: $MACHINE_RESOURCES"
docker-machine create $MACHINE_RESOURCES "$MASTER_NODE_NAME"
CREATE_EXIT_CODE="$?"
sleep 10
if [ "0" != "$CREATE_EXIT_CODE" ] && [ "127" != "$CREATE_EXIT_CODE" ]; then
	echo "Rancher MASTER node creation exit code : $CREATE_EXIT_CODE"
	echo "Trying regenerating host certificates ..."
	docker-machine regenerate-certs --force "$MASTER_NODE_NAME"
fi
if [ "-gce" = "$ENGINE" ]; then
	echo "Rancher MASTER node: installing docker on host ..."
	docker-machine ssh "$MASTER_NODE_NAME" "echo '$( cat $FOLDER/config/install-docker.sh )' > ./install-docker.sh && chmod 777 ./install-docker.sh && ./install-docker.sh && rm -f ./install-docker.sh"
fi
echo "Rancher MASTER node installing curl container ..."
docker-machine ssh "$MASTER_NODE_NAME" "sudo sh -c \"echo \\\"docker run --rm curlimages/curl \$ @\\\" > /usr/bin/curl && chmod +x /usr/bin/curl && sed -i 's/$ @/\\\$@/g' /usr/bin/curl && curl --help \""
echo "Rancher MASTER node installing Rancher Server ..."
## Use more sophisticated way to create a Rancher Server, using a sidekick and named local volumes
dos2Unix $FOLDER/config/create-rancher-server.sh
docker-machine ssh "$MASTER_NODE_NAME" "echo '$( cat $FOLDER/config/create-rancher-server.sh )' > ./create-rancher-server.sh && chmod 777 ./create-rancher-server.sh && ./create-rancher-server.sh && rm -f create-rancher-server.sh"
RANCHER_MASTER_NODE_IP="$(getMasterNodeIp "${PREFIX}")"
echo "Rancher MASTER node Ip: $RANCHER_MASTER_NODE_IP"
if [ "" == "RANCHER_MASTER_NODE_IP" ]; then
	echo "Unable to recover Rancher Master Node Id, exiting..."
	exit 1
fi
while [ "" = "$(${CMD_PREFIX}curl -sL http://$RANCHER_MASTER_NODE_IP:8080/v1 2> /dev/null)" ]; do echo "Waiting for Rancher server to be active: http://$RANCHER_MASTER_NODE_IP:8080"; sleep 30; done
PROP_ID="$(setUpHostUrl "$RANCHER_MASTER_NODE_IP" 2> /dev/null)"
if [ "" = "$PROP_ID" ]; then
	PROP_ID="$(setUpHostUrl "$RANCHER_MASTER_NODE_IP" 2> /dev/null)"
fi
echo "Setting up default host url - Property Id : $PROP_ID"
PROP_ID="$(changeTelemetryOption "$RANCHER_MASTER_NODE_IP" "false" 2> /dev/null)"
if [ "" = "$PROP_ID" ]; then
	PROP_ID="$(changeTelemetryOption "$RANCHER_MASTER_NODE_IP" "false" 2> /dev/null)"
fi
echo "Disabling Telemetry - Property Id : $PROP_ID"
DEFAULT_PROJECT_ID="$(${CMD_PREFIX}curl -sL http://$RANCHER_MASTER_NODE_IP:8080/v1/projects | ${CMD_PREFIX}jq -r '.data[0].id')"
if [ "" = "$DEFAULT_PROJECT_ID" ]; then
	echo "Default Project id not found on the Rancher Server."
	echo "Available projects: "
	echo -e "$(listAvailableProjects "$RANCHER_MASTER_NODE_IP")"
	exit 1
fi
DEFAULT_PROJECT_NAME="$(${CMD_PREFIX}curl -sL http://$RANCHER_MASTER_NODE_IP:8080/v1/projects | ${CMD_PREFIX}jq -r '.data[0].name')"
if [ "" = "$DEFAULT_PROJECT_NAME" ]; then
	echo "Default Project Name kine to id: $DEFAULT_PROJECT_ID not found on the Rancher Server."
	echo "Available projects: "
	echo -e "$(listAvailableProjects "$RANCHER_MASTER_NODE_IP")"
	exit 1
fi
echo "WARNING: Opening system browser for first access. Please do not change anything until procedure complete!!"
openBrowserUrl "$RANCHER_MASTER_NODE_IP" "/settings/env"
echo "Waiting 20 seconds for giving the API engine time to read database data..."
sleep 20


echo "--------------------------------------------------------------------"
echo "Rancher Nodes List"
echo "--------------------------------------------------------------------"
echo "Rancher Master Node: $RANCHER_MASTER_NODE_IP"
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
echo " "
if [ "--no-prov" != "$3" ] && [ "--no-prov" != "$4" ]; then 
	echo "Provisinging First Rancher $RANCHER_ENVIRONMENT cluster ..."
	sh -c "$FOLDER/provision-cluster-docker-machines-rancher.sh $RANCHER_NODES \"$2\" \"$2\" \"$RANCHER_ENVIRONMENT\" \"yes\" \"$2\" \"$3\""
	PROVISION_EXIT_CODE="$?"
	if [ "" != "$PROVISION_EXIT_CODE" ] && [ "0" != "$PROVISION_EXIT_CODE" ]; then
		echo "Errors executing First Rancher $RANCHER_ENVIRONMENT cluster: exit code -> $PROVISION_EXIT_CODE"
		exit 1
	fi
	echo "Deactivating default project: $DEFAULT_PROJECT_ID ..."
	$(deleteProject "$RANCHER_MASTER_NODE_IP" "$DEFAULT_PROJECT_ID") 2> /dev/null
else
	mkdir $FOLDER/.settings 2> /dev/null
	echo "${DEFAULT_PROJECT_ID}:${DEFAULT_PROJECT_NAME}" >> $FOLDER/.settings/.${PREFIX}projects
	silentDos2Unix "$FOLDER/.settings/.${PREFIX}projects"
	echo "Provisinging First Rancher $RANCHER_ENVIRONMENT stopped, as required!!"
	echo "Please execute following command to provision one or more clusters :"
	sh -c "$FOLDER/provision-cluster-docker-machines-rancher.sh -h"
	echo "Please execute following command to remove default environment :"
	echo "$FOLDER/unregister-cluster-docker-machines-rancher.sh \"${DEFAULT_PROJECT_ID}\" \"$2\" \"$3\""
fi

exit 0