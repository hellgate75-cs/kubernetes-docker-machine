#!/bin/sh
##
## Functions file
##
FOLDER="$(realpath "$(dirname "$0")")"
PROTOCOL="http"

if [ "" != "$CUSTOM_RANCHER_SERVER_PROTOCOL" ]; then
	PROTOCOL="$CUSTOM_RANCHER_SERVER_PROTOCOL"
fi

CMD_PREFIX=""
if [ "windows" = "$($FOLDER/bin/os.sh)" ]; then
	echo "Welcome windows user ..."
	CMD_PREFIX="${FOLDER}/bin/"
else
	if [ "" = "$(which curl 2> /dev/null)" ]; then
		echo "Please install curl and check if you have installed jq, before proceed ..."
		#exit 1
	fi
	if [ "" = "$(which jq 2> /dev/null)" ]; then
		echo "Please install jq, before proceed ..."
		#exit 1
	fi
fi


#####################
### ENVIRONMENT
#####################

function getCattleAccessIdentity() {
	CATTLE_ID=""
	if [ "" != "$CATTLE_ACCESS_KEY" ] && [ "" != "$CATTLE_SECRET_KEY" ]; then
		CATTLE_ID="-u \"${CATTLE_ACCESS_KEY}:${CATTLE_SECRET_KEY}\""
	fi
	echo "$CATTLE_ID"
}

#####################
### HTTP
#####################
function changeTelemetryOption() {
	# 1 -> Rancher Master Ip 2 -> bool enabled
	VALUE="out"
	if [ "true" = "$2" ]; then
		VALUE="in"
	fi
	CURR="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' "${PROTOCOL}://$1:8080/v2-beta/settings/telemetry.opt" 2> /dev/null|${CMD_PREFIX}jq -r '.value' 2> /dev/null|grep -v null)"
	if [ "" = "$CURR" ]; then
		echo "Create: $(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d "{\"name\":\"telemetry.opt\", \"value\":\"$VALUE\"}" "${PROTOCOL}://$1:8080/v2-beta/settings" 2> /dev/null|${CMD_PREFIX}jq -r '.id' 2> /dev/null|grep -v null)"
	else
		BODY="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -H 'Content-Type: application/json' "${PROTOCOL}://$1:8080/v2-beta/settings/telemetry.opt" 2> /dev/null|${CMD_PREFIX}jq -r '.' 2> /dev/null|grep -v null)"
		CURR="$(echo "$CURR"|sed -e 's/\//\\\\\\\//g')"
		BODY="$(echo "$BODY"|sed -e "s/$CURR/$VALIE/g")"
		echo "Update: $(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json' -d "$BODY" "${PROTOCOL}://$1:8080/v2-beta/settings/telemetry.opt" 2> /dev/null|${CMD_PREFIX}jq -r '.id' 2> /dev/null|grep -v null)"
	fi
}
function setUpHostUrl() {
	# 1 -> Rancher Master Ip
	URL="http:\/\/$1:8080"
	CURR="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' "${PROTOCOL}://$1:8080/v2-beta/settings/api.host" 2> /dev/null|${CMD_PREFIX}jq -r '.value' 2> /dev/null|grep -v null)"
	if [ "" = "$CURR" ]; then
		echo "Create: $(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' -d "{\"name\":\"api.host\", \"value\":\"http:\/\/$1:8080\"}" "${PROTOCOL}://$1:8080/v2-beta/settings" 2> /dev/null|${CMD_PREFIX}jq -r '.id' 2> /dev/null|grep -v null)"
	else
		BODY="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -H 'Content-Type: application/json' "${PROTOCOL}://$1:8080/v2-beta/settings/api.host" 2> /dev/null|${CMD_PREFIX}jq -r '.' 2> /dev/null|grep -v null)"
		CURR="$(echo "$CURR"|sed -e 's/\//\\\\\\\//g')"
		BODY="$(echo "$BODY"|sed -e "s/$CURR/$URL/g")"
		echo "Update: $(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json' -d "$BODY" "${PROTOCOL}://$1:8080/v2-beta/settings/api.host" 2> /dev/null|${CMD_PREFIX}jq -r '.id' 2> /dev/null|grep -v null)"
	fi
}
function listAvailableProjects() {
	# 1 -> Rancher Master Ip
	IDX=0
	ID="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/projects 2> /dev/null|${CMD_PREFIX}jq -r '.data[${IDX}].id' 2> /dev/null|grep -v null")"
	NAME="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/projects 2> /dev/null|${CMD_PREFIX}jq -r '.data[${IDX}].name' 2> /dev/null|grep -v null")"
	while [ "" != "$ID" ]; do
		((IDX=IDX+1))
		echo "Project #${IDX}:"
		echo "  Id: $ID"
		echo "  Name: $NAME"
		echo " "
		ID="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/projects 2> /dev/null|${CMD_PREFIX}jq -r '.data[${IDX}].id' 2> /dev/null|grep -v null")"
		NAME="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/projects 2> /dev/null|${CMD_PREFIX}jq -r '.data[${IDX}].name' 2> /dev/null|grep -v null")"
	done
}

function retrieveGETCallFromServer {
	# 1 -> Rancher Master Ip 2-> v2-beta path 3 -> response field
	echo "$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/$2 2> /dev/null|${CMD_PREFIX}jq -r ".${3}" 2> /dev/null|grep -v null")"
}

function listGETCallFromServer() {
	# 1 -> Rancher Master Ip 2-> v2-beta path 3 -> response field 4 -> Output data item title
	IDX=0
	DATA="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/$2 2> /dev/null|${CMD_PREFIX}jq -r ".data[${IDX}].$3" 2> /dev/null|grep -v null")"
	while [ "" != "$DATA" ]; do
		((IDX=IDX+1))
		echo "$4 #${IDX}:"
		echo "  $4: $DATA"
		echo " "
		DATA="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/$2 2> /dev/null|${CMD_PREFIX}jq -r ".data[${IDX}].$3" 2> /dev/null|grep -v null")"
	done
}

function listCustomGETCallFromServer() {
	# 1 -> Rancher Master Ip 2-> v2-beta path 3 -> collection field name 4 -> export field name
	IDX=0
	DATA="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/$2 2> /dev/null|${CMD_PREFIX}jq -r ".${3}[${IDX}].${4}" 2> /dev/null|grep -v null")"
	while [ "" != "$DATA" ]; do
		((IDX=IDX+1))
		echo "$DATA"
		DATA="$(eval "${CMD_PREFIX}curl $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' -sL ${PROTOCOL}://$1:8080/v2-beta/$2 2> /dev/null|${CMD_PREFIX}jq -r ".${3}[${IDX}].${4}" 2> /dev/null|grep -v null")"
	done
}
function selectTemplate() {
	# 1-> Rancher master IP, 2-> template name (e.g.: Kubernetes)
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET ${PROTOCOL}://$1:8080/v2-beta/projecttemplates 2> /dev/null | ${CMD_PREFIX}jq -r ".data[] | select(.name==\"$2\") | .id" 2> /dev/null)"
}
function selectTemplateListJson() {
	# 1-> Rancher master IP
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET ${PROTOCOL}://$1:8080/v2-beta/projecttemplates)"
}
function deleteProject() {
	# 1-> Rancher master IP, 2-> project id
	eval "${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json'  -d '{}' \"${PROTOCOL}://$1:8080/v2-beta/projects/$2/?action=deactivate\" 2>&1 /dev/null "
	sleep 5
	eval "${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json'  -d '{}' \"${PROTOCOL}://$1:8080/v2-beta/projects/$2/?action=delete\" 2> /dev/null | ${CMD_PREFIX}jq 2> /dev/null"
	sleep 5
	eval "${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json'  -d '{}' \"${PROTOCOL}://$1:8080/v2-beta/projects/$2/?action=remove\" 2> /dev/null | ${CMD_PREFIX}jq 2> /dev/null"
	sleep 5
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X DELETE -H 'Accept: application/json' "${PROTOCOL}://$1:8080/v2-beta/projects/$2" 2> /dev/null | ${CMD_PREFIX}jq 2> /dev/null)"
}
function restartProject() {
	# 1-> Rancher master IP, 2-> project id
	eval "${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json'  -d '{}' \"${PROTOCOL}://$1:8080/v2-beta/projects/$2/?action=deactivate\" 2>&1 /dev/null "
	sleep 20
	eval "${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json'  -d '{}' \"${PROTOCOL}://$1:8080/v2-beta/projects/$2/?action=activate\" 2>&1 /dev/null "
	sleep 5
}
function assignProjectToDefault() {
	# 1-> Rancher master IP, 2-> project id
	ID="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' ${PROTOCOL}://$1:8080/v2-beta/userpreferences 2> /dev/null | ${CMD_PREFIX}jq -r '.data[]  | select(.name=="defaultProjectId") | .id' 2> /dev/null )"
	if [ "" = "$ID" ]; then
		BODY="{\"name\":\"defaultProjectId\",\"value\":\"\\\"$2\\\"\"}"
		ID="1up4"
		echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json'  -d "$BODY"  "${PROTOCOL}://$1:8080/v2-beta/userpreferences" 2> /dev/null | ${CMD_PREFIX}jq -r '.id' 2> /dev/null )"
	else
		VALUE="$(${CMD_PREFIX}curl -sL  $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' ${PROTOCOL}://$1:8080/v2-beta/userpreferences|${CMD_PREFIX}jq -r -c '.data[]  | select(.name=="defaultProjectId") | .value'| sed -e 's/\"/\\\\\\\"/g')"
		BODY="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' ${PROTOCOL}://$1:8080/v2-beta/userpreferences 2> /dev/null | ${CMD_PREFIX}jq -r -c '.data[]  | select(.name=="defaultProjectId") | .' | sed -e "s/${VALUE}/\\\\"${2}\\\\"/g")"
		echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json'  -d "$BODY"  "${PROTOCOL}://$1:8080/v2-beta/userpreferences/$ID" 2> /dev/null | ${CMD_PREFIX}jq -r '.id' 2> /dev/null )"
	fi
	#echo "fake: done|!!"
}
function createProject() {
	# 1-> Rancher master IP, 2-> project name 3-> project description 4-> template Id
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X POST -H 'Accept: application/json' -H 'Content-Type: application/json'  -d "{\"allowSystemRole\":false,\"virtualMachine\":false,\"type\":\"project\",\"name\":\"$2\",\"description\":\"$3\",\"projectTemplateId\":\"$4\",\"projectMembers\":[],\"created\":null,\"healthState\":null,\"kind\":null,\"removeTime\":null,\"removed\":null,\"uuid\":null,\"version\":null,\"hostRemoveDelaySeconds\":null,\"members\":[]}"  "${PROTOCOL}://$1:8080/v2-beta/projects" 2> /dev/null | ${CMD_PREFIX}jq -c -r '.' 2> /dev/null )"
}
function getProjectName() {
	# 1-> Rancher master IP, 2-> project id
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json'  "${PROTOCOL}://$1:8080/v2-beta/projects/$2" 2> /dev/null | ${CMD_PREFIX}jq -c -r '.data[0].name' 2> /dev/null )"
}
function getProjectIdByProjectName() {
	# 1-> Rancher master IP, 2-> project name
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json'  "${PROTOCOL}://$1:8080/v2-beta/projects?name=$2" 2> /dev/null | ${CMD_PREFIX}jq -c -r '.data[0].id' 2> /dev/null )"
}
function getOrchestratorByProjectName() {
	# 1-> Rancher master IP, 2-> project name
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json'  "${PROTOCOL}://$1:8080/v2-beta/projects?name=$2" 2> /dev/null | ${CMD_PREFIX}jq -c -r '.data[0].orchestration' 2> /dev/null )"
}
function getOrchestratorById() {
	# 1-> Rancher master IP, 2-> project id
	echo "$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json'  "${PROTOCOL}://$1:8080/v2-beta/projects/$2" 2> /dev/null | ${CMD_PREFIX}jq -c -r '.data[0].orchestration' 2> /dev/null )"
}

function updateProjectValue() {
	# 1-> Rancher master IP, 2-> project id 3-> jq field path 4-> new value
	CURRENT_VALUE="`${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' "${PROTOCOL}://$1:8080/v2-beta/projects/${2}" 2> /dev/null | ${CMD_PREFIX}jq -r "$3" 2> /dev/null | grep -v null `"
	if [ "" != "$CURRENT_VALUE" ]; then
		BODY="$(${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X GET -H 'Accept: application/json' "${PROTOCOL}://$1:8080/v2-beta/projects/${2}" 2> /dev/null | ${CMD_PREFIX}jq -r -c '.' 2> /dev/null )"
		BODY="$(echo "$BODY"|sed -e "s/$CURRENT_VALUE/${4}/g")"
		OUT="null"
		eval "OUT=`${CMD_PREFIX}curl -sL $(getCattleAccessIdentity) -X PUT -H 'Accept: application/json' -H 'Content-Type: application/json' -d '$BODY'  \"${PROTOCOL}://$1:8080/v2-beta/projects/${2}\" 2> /dev/null | ${CMD_PREFIX}jq -r "$3" 2> /dev/null | grep -v null`"
		echo "$3: $CURRENT_VALUE->$4"
	else
		echo "$3: 404->VALUE_NOT_FOUND"
	fi
}


#####################
### DOCKER MACHINE
#####################

function findFirstAvailableNodeId() {
	# 1-> PREFIX
	ID=0
	TOKEN="."
	while [ "" != "$TOKEN" ]; do
		let ID=ID+1
		TOKEN="$(docker-machine inspect "$(getWorkerNodeName "${1}" "${ID}")" 2> /dev/null)"
	done
	echo "$ID"
}

function getMasterNodeIp() {
	# 1-> PREFIX
	echo "$(docker-machine ip "$(getMasterNodeName "${1}")" 2> /dev/null)"
}

function getWorkerNodeIp() {
	# 1-> PREFIX 2-> Worker Number
	echo "$(docker-machine ip "$(getWorkerNodeName "${1}" "${2}")" 2> /dev/null)"
}

#####################
### VALIDATION
#####################

function checkNumber() {
	case $1 in
		''|*[!0-9]*) echo "false" ;;
		*) echo "true" ;;
	esac
}

function checkProjectId() {
	regex='[0-9]+[a-zA-Z]+[0-9]+$'
	if [[ $1 =~ $regex ]]; then
		echo "true"
	else
		echo "false"
	fi
}

function fixIdValue() {
	PREFIX="$1"
	if [ "" != "$PREFIX" ]; then
		PREFIX="$(echo ${PREFIX,,}|sed -e 's/ /-/g')"
		PREFIX="${PREFIX}-"
	fi
	echo "$PREFIX"
}

function destoryInfrastructure() {
	echo "$(sh -c "$FOLDER/destroy-docker-machine-rancher.sh \"$1\"")"
}

function getMasterNodeName() {
	# 1-> PREFIX
	echo "${1}rancher-master-node"
}

function getWorkerNodeName() {
	# 1-> PREFIX 2-> Worker Number
	echo "${1}rancher-worker-node-${2}"
}
function openBrowserUrl() {
	# 1 -> Rancher Master Ip 2 -> web path
	OS="$(sh -c "$FOLDER/bin/os.sh")"
	if [ "windows" == "$OS" ]; then
		eval "start \"Rancher Server\" \"${PROTOCOL}://$1:8080${2}\""
	elif [ "linux" == "$OS" ]; then
		if [ "" = "$(which linx)" ]; then
			SUDO=""
			if [ "" != "$(which sudo)" ]; then
				SUDO="sudo "
			fi
			if [ "" != "$(which apt)" ]; then
				sh -c "${SUDO}apt-get update && ${SUDO}apt-get install -y lynx"
			elif [ "" != "$(which yum)" ]; then
				sh -c "${SUDO}yum update && ${SUDO}yum -y install lynx"
			else
				echo "Unknown way to install lynx"
				exit 1
			fi
		fi
		if [ "" = "$(which linx)" ]; then
			echo "No Web Browser available please install lynx"
			exit 1
		fi
		eval "lynx ${PROTOCOL}://$1:8080${2} &"
	else
		eval "open ${PROTOCOL}://$1:8080${2} &"
	fi
}

function countArrayInString() {
	# 1 -> string  2 -> separator
	LOCALARR=()
	VAL="LOCALARR=$(echo "(${1})" | sed "s/${2}/ /g" | xargs echo)"
	eval "$VAL"
	echo ${#LOCALARR[@]}
}

function getArrayInStringAtPosition() {
	# 1 -> string  2 -> separator 3-> position
	LOCALARR=()
	VAL="LOCALARR=$(echo "(${1})" | sed "s/${2}/ /g" | xargs echo)"
	eval "$VAL"
	echo "${LOCALARR[$3]}"
}

function getModuleOf() {
	# 1 -> current val  2 -> module val
	RET=0
	RES="RET=$((${1} % ${2}))"
	eval "$RES"
	echo $RET
}

function printScalarVariable() {
	# 1-> varibale prefix 2 -> variable descr 3 -> value wrapper 4 ->  block separator
	OUT=""
	IDX=1
	VALUE=""
	eval "VALUE=\$${1}${IDX}"
	while [ "" != "$VALUE" ]; do
		OUT="$OUT ${2} ${3}$VALUE${3}${4}" # (multiple)
		let IDX=IDX+1
		eval "VALUE=\$${1}${IDX}"
	done
}

function calculateMachineResource() {
	DRIVER="$1"
	MASTER="$2"
	WORKER_INDEX=$3
	USAGE=$4
	MACHINE_RESOURCES=""

	if [ "-hv" = "$DRIVER" ]; then
		MACHINE_RESOURCES="-d hyperv --hyperv-memory $MEMORY --hyperv-disk-size $DISKSIZE --hyperv-cpu-count $CORES --hyperv-disable-dynamic-memory --hyperv-boot2docker-url "
	elif  [ "-vb" = "$DRIVER" ]; then
		MACHINE_RESOURCES="-d virtualbox --virtualbox-memory $MEMORY --virtualbox-disk-size $DISKSIZE --virtualbox-cpu-count $CORES --virtualbox-disable-dynamic-memory --virtualbox-boot2docker-url "
	elif  [ "-gce" = "$DRIVER" ]; then
		if [ "" = "$GOOGLE_PROJECT" ]; then
			echo "Variable GOOGLE_PROJECT is mandatory for running the virtual machines ... EXIT!!"
			exit 1
		fi
		MACHINE_RESOURCES="-d google"
		if [ "" != "$GOOGLE_ADDRESS" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-address $GOOGLE_ADDRESS"
		fi
		if [ "" != "$GOOGLE_DISK_SIZE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-disk-size $GOOGLE_DISK_SIZE"
		fi
		if [ "" != "$GOOGLE_DISK_TYPE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-disk-type $GOOGLE_DISK_TYPE"
		fi
		if [ "" != "$GOOGLE_MACHINE_IMAGE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-machine-image $GOOGLE_MACHINE_IMAGE"
		fi
		if [ "" != "$GOOGLE_MACHINE_TYPE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-machine-type $GOOGLE_MACHINE_TYPE"
		fi
		if [ "" != "$GOOGLE_NETWORK" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-network $GOOGLE_NETWORK"
		fi
		if [ "" != "$GOOGLE_OPEN_PORT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-open-port $GOOGLE_OPEN_PORT"
		fi
		if [ "" != "$GOOGLE_PREEMPTIBLE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-preemptible $GOOGLE_PREEMPTIBLE"
		fi
		if [ "" != "$GOOGLE_PROJECT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-project $GOOGLE_PROJECT"
		fi
		if [ "" != "$GOOGLE_SCOPES" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-scopes $GOOGLE_SCOPES"
		fi
		if [ "" != "$GOOGLE_SERVICE_ACCOUNT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-service-account $GOOGLE_SERVICE_ACCOUNT"
		fi
		if [ "" != "$GOOGLE_SUBNETWORK" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-subnetwork $GOOGLE_SUBNETWORK"
		fi
		if [ "" != "$GOOGLE_TAGS" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-tags $GOOGLE_TAGS"
		fi
		if [ "" != "$GOOGLE_USE_EXISTING" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-existing $GOOGLE_USE_EXISTING"
		fi
		if [ "" != "$GOOGLE_USE_INTERNAL_IP" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-internal-ip $GOOGLE_USE_INTERNAL_IP"
		fi
		if [ "" != "$GOOGLE_USE_INTERNAL_IP_ONLY" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-use-internal-ip-only $GOOGLE_USE_INTERNAL_IP_ONLY"
		fi
		if [ "" != "$GOOGLE_USERNAME" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-username \"$GOOGLE_USERNAME\""
		fi
		if [ "" != "$GOOGLE_ZONE" ] && [ "true" = "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-zone \"$GOOGLE_ZONE\""
		elif [ "" != "$GOOGLE_ZONE_WORKERS" ] && [ "true" != "$MASTER" ]; then
			MOD=$(countArrayInString "$GOOGLE_ZONE_WORKERS" ",")
			CURR=$(getModuleOf $WORKER_INDEX $MOD)
			ZONE="$(getArrayInStringAtPosition "$GOOGLE_ZONE_WORKERS" "," $CURR)"
			MACHINE_RESOURCES="$MACHINE_RESOURCES --google-zone \"$ZONE\""
		fi

		#echo "GCE: $MACHINE_RESOURCES"
	elif [ "-aws" = "$DRIVER" ]; then
		MACHINE_RESOURCES="-d amazonec2"
		if [ "" != "$AWS_ACCESS_KEY_ID" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES --amazonec2-access-key"
		fi
		if [ "" != "$AWS_AMI" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-ami"
		fi
		if [ "" != "$AWS_BLOCK_DURATION_MINUTES" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-block-duration-minutes $AWS_BLOCK_DURATION_MINUTES"
		fi
		if [ "" != "$AWS_DEVICE_NAME" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-device-name \"$AWS_DEVICE_NAME\""
		fi
		if [ "" != "$AWS_ENDPOINT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-endpoint"
		fi
		if [ "" != "$AWS_INSTANCE_PROFILE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-iam-instance-profile"
		fi
		if [ "yes" = "$AWS_INSECURE_TRANSPORT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-insecure-transport" # if AWS_INSECURE_TRANSPORT=yes
		fi
		if [ "" != "$AWS_INSTANCE_TYPE_MASTER" ] && [ "true" = "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-instance-type \"$AWS_INSTANCE_TYPE_MASTER\""
		fi
		if [ "" != "$AWS_INSTANCE_TYPE_WORKERS" ] && [ "true" != "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-instance-type \"$AWS_INSTANCE_TYPE_WORKERS\""
		fi
		if [ "" != "$AWS_SSH_KEYPATH" ]; then
			if [ "" != "$AWS_KEYPAIR_NAME" ]; then
				MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-keypair-name"
			fi
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-ssh-keypath"
		fi
		if [ "yes" = "$AWS_ENABLE_CLOUDWATCH_MONITORING" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-monitoring" # if AWS_ENABLE_CLOUDWATCH_MONITORING=yes
		fi
		if [ "" != "$AWS_OPEN_PORT_OPTION_1" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-open-port \"$AWS_OPEN_PORT_OPTION_1\"" # (multiple)
			IDX=2
			VALUE=""
			eval "VALUE=\$AWS_OPEN_PORT_OPTION_${IDX}"
			while [ "" != "$VALUE" ]; do
				MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-open-port \"$VALUE\"" # (multiple)
				let IDX=IDX+1
				eval "VALUE=\$AWS_OPEN_PORT_OPTION_${IDX}"
			done
		fi
		if [ "yes" = "$AWS_PRIVATE_ADDRESS_ONLY" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-private-address-only" # if AWS_PRIVATE_ADDRESS_ONLY=yes
		fi
		if [ "" != "$AWS_DEFAULT_REGION" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-region \"$AWS_DEFAULT_REGION\""
		fi
		if [ "yes" = "$AWS_REQUEST_SPOT_INSTANCE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-request-spot-instance" # if AWS_REQUEST_SPOT_INSTANCE=yes
		fi
		if [ "" != "$AWS_FAILURE_RETRY" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-retries \"$AWS_FAILURE_RETRY\""
		fi
		if [ "" != "$AWS_ROOT_SIZE_MASTER" ] && [ "true" = "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-root-size \"$AWS_ROOT_SIZE_MASTER\""
		fi
		if [ "" != "$AWS_ROOT_SIZE_WORKER" ] && [ "true" != "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-root-size \"$AWS_ROOT_SIZE_WORKER\""
		fi
		if [ "" != "$AWS_SECRET_ACCESS_KEY" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-secret-key"
		fi
		if [ "" != "$AWS_SECURITY_GROUP_OPTION_1" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-security-group \"$AWS_SECURITY_GROUP_OPTION_1\"" # (multiple)
			IDX=2
			VALUE=""
			eval "VALUE=\$AWS_SECURITY_GROUP_OPTION_${IDX}"
			while [ "" != "$VALUE" ]; do
				MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-security-group \"$VALUE\"" # (multiple)
				let IDX=IDX+1
				eval "VALUE=\$AWS_SECURITY_GROUP_OPTION_${IDX}"
			done
		fi
		if [ "yes" = "$AWS_SECURITY_GROUP_READONLY" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-security-group-readonly" # if $AWS_SECURITY_GROUP_READONLY=yes
		fi
		if [ "yes" = "$AWS_SESSION_TOKEN" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-session-token" # if AWS_SESSION_TOKEN=yes
		fi
		if [ "" != "$AWS_INSTANCE_SPOT_PRICE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-spot-price \"$AWS_INSTANCE_SPOT_PRICE\""
		fi
		if [ "" != "$AWS_SSH_PORT" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-ssh-port \"$AWS_SSH_PORT\""
		fi
		if [ "" != "$AWS_SSH_USER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-ssh-user \"$AWS_SSH_USER\""
		fi
		if [ "" != "$AWS_SUBNET_ID" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-subnet-id"
		fi
		if [ "" != "$AWS_TAGS" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-tags"
		fi
		if [ "yes" = "$AWS_USE_EBS_OPTIMIZED_INSTANCE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-use-ebs-optimized-instance" # if AWS_USE_EBS_OPTIMIZED_INSTANCE=yes
		fi
		if [ "yes" = "$AWS_USE_PRIVATE_ADDRESS" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-use-private-address" # if AWS_USE_PRIVATE_ADDRESS=yes
		fi
		if [ "" != "$AWS_USERDATA" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-userdata"
		fi
		if [ "" != "$AWS_VOLUME_TYPE" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-volume-type \"$AWS_VOLUME_TYPE\""
		fi
		if [ "" != "$AWS_VPC_ID" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-vpc-id"
		fi
		if [ "" != "$AWS_ZONE_MASTER" ] && [ "true" = "$MASTER" ]; then
			MACHINE_RESOURCES="$MACHINE_RESOURCES  --amazonec2-zone \"$AWS_ZONE_MASTER\""
		fi
		if [ "" != "$AWS_ZONES_WORKERS" ] && [ "true" != "$MASTER" ]; then
			MOD=$(countArrayInString "$AWS_ZONES_WORKERS" ",")
			CURR=$(getModuleOf $WORKER_INDEX $MOD)
			ZONE="$(getArrayInStringAtPosition "$AWS_ZONES_WORKERS" "," $CURR)"
			MACHINE_RESOURCES="$MACHINE_RESOURCES --amazonec2-zone \"$ZONE\""
		fi

#		echo "AWS: $MACHINE_RESOURCES"
#		exit 0
	else
		echo "$USAGE"
		exit 1
	fi
	echo "$MACHINE_RESOURCES"
}

function getIsoImage() {
	# 1 -> Engine
	ENGINE=$1
	ISO_IMAGE=""
	ISO_IMAGE="https://releases.rancher.com/os/latest/rancheros.iso"
	if [ "-hv" = "$ENGINE" ]; then
		ISO_IMAGE="https://releases.rancher.com/os/latest/hyperv/rancheros.iso"
	elif [ "-vw" = "$ENGINE" ]; then
		ISO_IMAGE="https://releases.rancher.com/os/latest/vmware/rancheros.iso"
	else
		ISO_IMAGE=""
	fi
	echo "$ISO_IMAGE"
}

function validateEngine() {
	# 1 -> Engine 2 -> usage
	ENGINE="$1"
	if [ "-hv" = "$ENGINE" ]; then
		echo "Using Microsoft Hyper-V provisioner ..."
	elif  [ "-vb" = "$ENGINE" ]; then
		echo "Using Oracle VirtualBox provisioner ..."
	elif  [ "-gce" = "$ENGINE" ]; then
		echo "Using Google Cloud Engine provisioner ..."
	elif  [ "-aws" = "$ENGINE" ]; then
		echo "Using Google Cloud Engine provisioner ..."
	else
		echo "$2"
	fi
}

function loadOptionalFiles() {
	ENGINE="$1"
	echo "Looking for optional files for Engine : $ENGINE"
	if [ "-gce" = "$ENGINE" ]; then
		CONFIG_FILE_NAME="config/gce-config.env"
		if [ "" != "$GOOGLE_CUSTOM_CONFIG_FILE" ]; then
			CONFIG_FILE_NAME="$GOOGLE_CUSTOM_CONFIG_FILE"
		fi
		if [ "" = "$CONFIG_FILE_NAME" ] && [ -e "$FOLDER/$CONFIG_FILE_NAME" ]; then
			silentDos2Unix "$CONFIG_FILE_NAME"
			echo "Loading GCE env config file: $FOLDER/$CONFIG_FILE_NAME ..."
			source $FOLDER/$CONFIG_FILE_NAME
		fi
		if [ "-gce" = "$ENGINE" ] && [ "" = "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
			echo "Please set-up credentials file in variable: GOOGLE_APPLICATION_CREDENTIALS, cannot continue..."
		fi
	elif [ "-aws" = "$ENGINE" ]; then
		AWS_CONFIG_FILE_NAME="config/aws-config.env"
		if [ "" != "$AWS_CUSTOM_CONFIG_FILE" ]; then
			AWS_CONFIG_FILE_NAME="$AWS_CUSTOM_CONFIG_FILE"
		fi
		echo "AWS: Using options file: $AWS_CONFIG_FILE_NAME ..."
		if [ "" != "$AWS_CONFIG_FILE_NAME" ] && [ -e "$FOLDER/$AWS_CONFIG_FILE_NAME" ]; then
			silentDos2Unix "$FOLDER/$AWS_CONFIG_FILE_NAME"
			echo "Loading AWS env config file: $FOLDER/$AWS_CONFIG_FILE_NAME ..."
			source $FOLDER/$AWS_CONFIG_FILE_NAME
		else
			echo "File doesn't exists. Exit!!"
			exit 1
		fi
	else
		echo "No optional file discovered for the engine: $ENGINE"
	fi
}

function dos2Unix() {
	if [ "" != "$(which dos2unix)" ] && [ "" != "$1" ] && [ -e "$1" ]; then
		dos2unix "$1" 2> /dev/null
	fi
}

function silentDos2Unix() {
	if [ "" != "$(which dos2unix)" ] && [ "" != "$1" ] && [ -e "$1" ]; then
		dos2unix "$1" 2>&1 > /dev/null
	fi
}

#####################
### REPORTING
#####################

function printVMAttributes(){
	ENGINE="$1"
	echo "-------------------------------------"
	if [ "-hv" = "$ENGINE" ] || [ "-vb" = "$ENGINE" ]; then
		echo "Memory is $MEMORY MB"
		echo "Disk Size is $DISKSIZE MB"
		echo "Number of cores: $CORES"
	elif [ "-gce" = "$ENGINE" ]; then
		echo "GCE project: $GOOGLE_PROJECT"
		echo "GCE zone: $GOOGLE_ZONE"
		echo "GCE machine type: $GOOGLE_MACHINE_TYPE"
		echo "GCE machine image: $GOOGLE_MACHINE_IMAGE"
		echo "GCE disk size: $GOOGLE_DISK_SIZE"
		echo "Only from config file '$FOLDER/$CONFIG_FILE_NAME' :"
		echo "GCE address: $GOOGLE_ADDRESS"
		echo "GCE disk type: $GOOGLE_DISK_TYPE"
		echo "GCE network: $GOOGLE_NETWORK"
		echo "GCE open port: $GOOGLE_OPEN_PORT"
		echo "GCE Preemptible: $GOOGLE_PREEMPTIBLE"
		echo "GCE Scopes: $GOOGLE_SCOPES"
		echo "GCE service account: $GOOGLE_SERVICE_ACCOUNT"
		echo "GCE Subnetworks: $GOOGLE_SUBNETWORK"
		echo "GCE Tags: $GOOGLE_TAGS"
		echo "GCE Use Existing: $GOOGLE_USE_EXISTING"
		echo "GCE Use Internal IP: $GOOGLE_USE_INTERNAL_IP"
		echo "GCE Use Only Internal IP: $GOOGLE_USE_INTERNAL_IP_ONLY"
		echo "GCE User name: $GOOGLE_USERNAME"
	elif [ "-aws" = "$ENGINE" ]; then
		echo "AWS Access Key: $AWS_ACCESS_KEY_ID"
		echo "AWS AMI: $AWS_AMI"
		echo "AWS Device name= $AWS_DEVICE_NAME"
		echo "AWS Block Duration in minutes: $AWS_BLOCK_DURATION_MINUTES"
		echo "AWS custom Endpoint: $AWS_ENDPOINT"
		echo "AWS IAM Profile: $AWS_INSTANCE_PROFILE"
		echo "AWS Use Insecure Transport: $AWS_INSECURE_TRANSPORT"
		echo "AWS Rancher Master EC2 Instance Type: $AWS_INSTANCE_TYPE_MASTER"
		echo "AWS Kubernetes Node EC2 Instance Type: $AWS_INSTANCE_TYPE_WORKERS"
		echo "AWS Keypair Wanted Name: $AWS_KEYPAIR_NAME"
		echo "AWS Enable CloudWatch Monitoring: $AWS_ENABLE_CLOUDWATCH_MONITORING"
		OPEN_PORT="$(printScalarVariable "AWS_OPEN_PORT_OPTION_" "AWS Open Port Option: " "" "\n")"
		if [ "" != "$OPEN_PORT" ]; then
			echo -e "$OPEN_PORT" #"$AWS_OPEN_PORT_OPTION_1"
		fi
		echo "AWS Use Provate Address Only: $AWS_PRIVATE_ADDRESS_ONLY"
		echo "AWS Default Region: $AWS_DEFAULT_REGION"
		echo "AWS Use Request Spot Ec2 Instance: $AWS_REQUEST_SPOT_INSTANCE"
		echo "AWS Errors Retry: $AWS_FAILURE_RETRY"
		echo "AWS Rancher Master Disk Size: $AWS_ROOT_SIZE_MASTER"
		echo "AWS Kubernetes Node Disk Size: $AWS_ROOT_SIZE_WORKER"
		echo "AWS Secret Access Key: $AWS_SECRET_ACCESS_KEY"
		SEC_GRP="$(printScalarVariable "AWS_SECURITY_GROUP_OPTION_" "AWS Security Group Option: " "" "\n")"
		if [ "" != "$SEC_GRP" ]; then
			echo -e "$SEC_GRP" #"$AWS_SECURITY_GROUP_OPTION_1"
		fi
		echo "AWS Use Security Group Readonly: $AWS_SECURITY_GROUP_READONLY"
		echo "AWS Use Temporary Session Token: $AWS_SESSION_TOKEN"
		echo "AWS Ec2 Instance Spot Price (in USD): $AWS_INSTANCE_SPOT_PRICE"
		echo "AWS SSH Key Path: $AWS_SSH_KEYPATH"
		echo "AWS SSH Port: $AWS_SSH_PORT"
		echo "AWS SSH Access User: $AWS_SSH_USER"
		echo "AWS Subnet ID: $AWS_SUBNET_ID"
		echo "AWS EC2 Instance Tags: $AWS_TAGS"
		echo "AWS Use EBS Optimized Instance: $AWS_USE_EBS_OPTIMIZED_INSTANCE"
		echo "AWS Use Private IP Address: $AWS_USE_PRIVATE_ADDRESS"
		echo "AWS User Data: $AWS_USERDATA"
		echo "AWS EBD Volume Type: $AWS_VOLUME_TYPE"
		echo "AWS VPC ID: $AWS_VPC_ID"
		echo "AWS Rancher Master Preferred Availability Zone: $AWS_ZONE_MASTER"
		echo "AWS Kubernetes Nodes Preferred Availability Zones: $AWS_ZONES_WORKERS"
	fi
	echo "-------------------------------------"
	echo " "
}

function printNewVMAttributes(){
	echo "-------------------------------------"
	if [ "-hv" = "$1" ] || [ "-vb" = "$1" ]; then
		echo "Memory is $2 MB"
		echo "Disk Size is $3 MB"
		echo "Number of cores: $4"
	elif [ "-gce" = "$1" ]; then
		echo "GCE project: $5"
		echo "GCE region: $6"
		echo "GCE machine type: $7"
		echo "GCE machine image: $8"
		echo "GCE disk size: $9"
		echo "Only from config file '$FOLDER/$CONFIG_FILE_NAME' :"
		echo "GCE address: $GOOGLE_ADDRESS"
		echo "GCE disk type: $GOOGLE_DISK_TYPE"
		echo "GCE network: $GOOGLE_NETWORK"
		echo "GCE open port: $GOOGLE_OPEN_PORT"
		echo "GCE Preemptible: $GOOGLE_PREEMPTIBLE"
		echo "GCE Scopes: $GOOGLE_SCOPES"
		echo "GCE service account: $GOOGLE_SERVICE_ACCOUNT"
		echo "GCE Subnetworks: $GOOGLE_SUBNETWORK"
		echo "GCE Tags: $GOOGLE_TAGS"
		echo "GCE Use Existing: $GOOGLE_USE_EXISTING"
		echo "GCE Use Internal IP: $GOOGLE_USE_INTERNAL_IP"
		echo "GCE Use Only Internal IP: $GOOGLE_USE_INTERNAL_IP_ONLY"
		echo "GCE User name: $GOOGLE_USERNAME"
	elif [ "-aws" = "$ENGINE" ]; then
		echo "AWS Access Key: $AWS_ACCESS_KEY_ID"
		echo "AWS AMI: $AWS_AMI"
		echo "AWS Device name= $AWS_DEVICE_NAME"
		echo "AWS Block Duration in minutes: $AWS_BLOCK_DURATION_MINUTES"
		echo "AWS custom Endpoint: $AWS_ENDPOINT"
		echo "AWS IAM Profile: $AWS_INSTANCE_PROFILE"
		echo "AWS Use Insecure Transport: $AWS_INSECURE_TRANSPORT"
		echo "AWS Rancher Master EC2 Instance Type: $AWS_INSTANCE_TYPE_MASTER"
		echo "AWS Kubernetes Node EC2 Instance Type: $AWS_INSTANCE_TYPE_WORKERS"
		echo "AWS Keypair Wanted Name: $AWS_KEYPAIR_NAME"
		echo "AWS Enable CloudWatch Monitoring: $AWS_ENABLE_CLOUDWATCH_MONITORING"
		OPEN_PORT="$(printScalarVariable "AWS_OPEN_PORT_OPTION_" "AWS Open Port Option: " "" "\n")"
		if [ "" != "$OPEN_PORT" ]; then
			echo -e "$OPEN_PORT" #"$AWS_OPEN_PORT_OPTION_1"
		fi
		echo "AWS Use Provate Address Only: $AWS_PRIVATE_ADDRESS_ONLY"
		echo "AWS Default Region: $AWS_DEFAULT_REGION"
		echo "AWS Use Request Spot Ec2 Instance: $AWS_REQUEST_SPOT_INSTANCE"
		echo "AWS Errors Retry: $AWS_FAILURE_RETRY"
		echo "AWS Rancher Master Disk Size: $AWS_ROOT_SIZE_MASTER"
		echo "AWS Kubernetes Node Disk Size: $AWS_ROOT_SIZE_WORKER"
		echo "AWS Secret Access Key: $AWS_SECRET_ACCESS_KEY"
		SEC_GRP="$(printScalarVariable "AWS_SECURITY_GROUP_OPTION_" "AWS Security Group Option: " "" "\n")"
		if [ "" != "$SEC_GRP" ]; then
			echo -e "$SEC_GRP" #"$AWS_SECURITY_GROUP_OPTION_1"
		fi
		echo "AWS Use Security Group Readonly: $AWS_SECURITY_GROUP_READONLY"
		echo "AWS Use Temporary Session Token: $AWS_SESSION_TOKEN"
		echo "AWS Ec2 Instance Spot Price (in USD): $AWS_INSTANCE_SPOT_PRICE"
		echo "AWS SSH Key Path: $AWS_SSH_KEYPATH"
		echo "AWS SSH Port: $AWS_SSH_PORT"
		echo "AWS SSH Access User: $AWS_SSH_USER"
		echo "AWS Subnet ID: $AWS_SUBNET_ID"
		echo "AWS EC2 Instance Tags: $AWS_TAGS"
		echo "AWS Use EBS Optimized Instance: $AWS_USE_EBS_OPTIMIZED_INSTANCE"
		echo "AWS Use Private IP Address: $AWS_USE_PRIVATE_ADDRESS"
		echo "AWS User Data: $AWS_USERDATA"
		echo "AWS EBD Volume Type: $AWS_VOLUME_TYPE"
		echo "AWS VPC ID: $AWS_VPC_ID"
		echo "AWS Rancher Master Preferred Availability Zone: $AWS_ZONE_MASTER"
		echo "AWS Kubernetes Nodes Preferred Availability Zones: $AWS_ZONES_WORKERS"
	fi
	echo "-------------------------------------"
	echo " "
}
