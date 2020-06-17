#!/bin/sh
function usage() {
	echo "cd-kubernetes-nodes.sh <env prefix> <cluster prefix> <hypervisor> <cluster nodes>"
	echo "  <env prefix>      Prefix name for docker-machine, that identify a clusters group"
	echo "  <cluster prefix>  Prefix name for Kubernetes clusters "
	echo "                    such as: ...-apps-kubernetes-clusters"
	echo "                             ...-database-kubernetes-clusters"
	echo "  <hypervisor>      Engine hypervisor, try ../create-docker-machine-rancher.sh -h fro details"
	echo "  <cluster nodes>   Number of nodes per cluster"
}
FOLDER="$(realpath "$(dirname "$0")")"
WORKDIR="$(realpath "..")"
if [ "-h" != "$1" ] || [ "--help" != "$1" ]; then
	echo -e "$(usage)"
	exit 0
fi

echo "Current folder $FOLDER ..."
echo "Executing scripts in folder $WORKDIR ..."
source $WORKDIR/functions-lib.sh
RANCHER_DEFAULT_NODES=3
RANCHER_DEFAULT_ENVIRONMENT_TEMPLATE="Kubernetes"
GOOGLE_CUSTOM_CONFIG_FILE=
GOOGLE_APPLICATION_CREDENTIALS=optiim-sample/optiim-gce-config.env
AWS_CUSTOM_CONFIG_FILE=optiim-sample/optiim-aws-config.env
ENV_NAME_PREFIX="Optiim"
CLUSTER_NAME_PREFIX="Optiim"
ENGINE="-hv"
DEFAULT_PRJ="true"
if [ "" != "$1" ]; then
	ENV_NAME_PREFIX="$1"
fi
if [ "" != "$2" ]; then
	CLUSTER_NAME_PREFIX="$2"
fi
if [ "" != "$3" ]; then
	ENGINE="$3"
fi
if [ "" != "$4" ] && [ "true" = "$(checkNumber $4)" ]; then
	RANCHER_DEFAULT_NODES=$4
fi
echo "Executing cluster creation without provisioning..."
export ENV_NAME_PREFIX && export CLUSTER_NAME_PREFIX && \
export RANCHER_DEFAULT_NODES && cd $WORKDIR &&\
./create-docker-machine-rancher.sh "$ENGINE" "$ENV_NAME_PREFIX" -f --no-prov
if "0" != "$?" ]; then
	echo "Environment $ENV_NAME_PREFIX creation failed ..."
	cd $WORKDIR && ./destroy-docker-machine-rancher.sh "$ENV_NAME_PREFIX"
	exit 1
fi

APP_CLUSTER_PREFIX="$CLUSTER_NAME_PREFIX Apps"
DB_CLUSTER_PREFIX="$CLUSTER_NAME_PREFIX Database"
APPS_PREFIX="$(fixIdValue "${CLUSTER_NAME_PREFIX}")-apps"
APPS_NAMESPACE="${APPS_PREFIX}-namespace"
FULL_APP_CLUSTER_NAME="${APPS_PREFIX}-kubernetes-env"
DB_PREFIX="$(fixIdValue "${CLUSTER_NAME_PREFIX}")-database"
DB_NAMESPACE="${DB_PREFIX}-namespace"
FULL_DB_CLUSTER_NAME="${DB_PREFIX}-kubernetes-env"

echo "Creating application cluster ..."
cd $WORKDIR && ./provision-cluster-docker-machines-rancher.sh $RANCHER_DEFAULT_NODES \
"$APP_CLUSTER_PREFIX" "$APP_CLUSTER_PREFIX" "Kubernetes" "$DEFAULT_PRJ" "$ENV_NAME_PREFIX" -f
if "0" != "$?" ]; then
	echo "Cluster $FULL_APP_CLUSTER_NAME creation failed ..."
	cd $WORKDIR && ./destroy-docker-machine-rancher.sh "$ENV_NAME_PREFIX"
	exit 1
fi

echo "Creating database cluster ..."
cd $WORKDIR && ./provision-cluster-docker-machines-rancher.sh $RANCHER_DEFAULT_NODES \
"$DB_CLUSTER_PREFIX" "$DB_CLUSTER_PREFIX" "Kubernetes" "$DEFAULT_PRJ" "$ENV_NAME_PREFIX" -f
if "0" != "$?" ]; then
	echo "Cluster $FULL_DB_CLUSTER_NAME creation failed ..."
	cd $WORKDIR && ./destroy-docker-machine-rancher.sh "$ENV_NAME_PREFIX"
	exit 1
fi
#ENVIRONMENT_NAME=environment
#NAMESPACE=namespace
#MAIN_CHART_FILE=chart_file
#CHART_NAME=chart_name
#CHART_LOCAL_NAME=chart_name
#CHART_VARS_FILE=chart_vars_file
#LOAD_BALANCERS_FILE=load_balancer_files
#UPGRADE_CHART=upgrade_chart
#UPGRADE_CHART_RELEASE=upgrade_chart_release
#UPGRADE_CHART_NAME=upgrade_chart_name

function fixFileContent(){
	FILE="$1"
	ENV="$2"
	 NS="$3"
	 CF="$4"
	 CN="$5"
	CLN="$6"
	 VF="$7"
	LBF="$8"
	UPG="$9"
	UPR="$10"
	UPN="$11"
	if [ "" = "$FILE" ] || [ ! -e "$FILE" ]; then
		echo "File $FILE doesn't exist ..."
		exit 1
	fi
	if [ "" = "$ENV" ]; then
		echo "For file $FILE: environment is mandatory ..."
		exit 1
	else
		sed -i "s/=environment/=${ENV}/g" $FILE
	fi
	if [ "" = "$NS" ]; then
		echo "For file $FILE: namespace is mandatory ..."
		exit 1
	else
		sed -i "s/=namespace/=${NS}/g" $FILE
	fi
	if [ "" = "$CF" ]; then
		echo "For file $FILE: chart file name is mandatory ..."
		exit 1
	else
		sed -i "s/=chart_file/=${CF}/g" $FILE
	fi
}

if [ ! -e $WORKDIR/tmp ]; then
	mkdir $WORKDIR/tmp
fi
apps_chart_base_path="$WORKDIR/tmp/${APP_CLUSTER_PREFIX}-base-chart-config.env"
cp $WORKDIR/optiim-sample/optiim-chart-config.env.tpl \
$apps_chart_base_path

echo "Preparing app cluster software provisioning ..."
