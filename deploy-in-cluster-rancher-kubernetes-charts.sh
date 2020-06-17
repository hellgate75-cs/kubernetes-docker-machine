#!/bin/sh
FOLDER="$(realpath "$(dirname "$0")")"

function usage(){
	echo "deploy-in-cluster-rancher-kubernetes-charts.sh {chart config}{nodes_prefix} [-f] [--create-infra-and-exit]"
	echo "  chart config (mandatory)   			Env file containing Chart Deploy configuration"
	echo "  nodes_prefix (optional)   			Prefix used to create VMs"
	echo "  -f  (optional)    		  			Force and create environment without questions"
	echo "  --create-infra-and-exit (optional)  create naspaces if needed, service accounts and secrets, then exit"
	echo "Use: deploy-in-cluster-docker-machine-rancher.sh [-h|--help] for this help"
}

if [ "-h" = "$1" ] || [ "--help" = "$1" ]; then
	echo -e "$(usage)"
	exit 0
fi

if [ $# -lt 1 ]; then
	echo -e "$(usage)"
	exit 1
fi

ENV_FILE="$1"

if [ ! -e $ENV_FILE ]; then
	echo "Please provide chart config file: $ENV_FILE doesn't exist!!"
	exit 1
else
	source $ENV_FILE
fi

source $FOLDER/functions-lib.sh
if [ "" = "$REPO_URL" ]; then
	echo "Chart file: $ENV_FILE doesn't contain valid repoitory url!!"
	exit 1
fi
if [ "" = "$REPO_BRANCH" ]; then
	echo "Chart file: $ENV_FILE doesn't contain valid repository branch!!"
	exit 1
fi
if [ "" = "${ENVIRONMENT_NAME}" ]; then
	echo "Chart file: $ENV_FILE doesn't contain valid environment name!!"
	exit 1
fi
if [ "" = "$NAMESPACE" ]; then
	echo "Chart file: $ENV_FILE doesn't contain valid Kubernetes Namespace!!"
	exit 1
fi

if [ "--create-infra-and-exit" != "${4,,}" ]; then
	if [ "" = "$MAIN_CHART_FILE" ]; then
		echo "Chart file: $ENV_FILE doesn't contain valid main Helm Chart file name!!"
		exit 1
	fi
fi

OS="$(sh $FOLDER/bin/os.sh)"
if [ "unknown" = "$OS" ]; then
	echo "Unable to detect you system..."
	exit 1
fi

if [ "windows" = "$OS" ]; then
	EXT=".exe"
fi

MACHINE="amd64"

PATH=$PATH:$FOLDER/bin


PREFIX="$(fixIdValue "$2")"

PROJECT_ID=""
PROJECT_NAME=""
PROJECTS_FILE="${FOLDER}/.settings/.${PREFIX}projects"
if [ -e $PROJECTS_FILE ]; then
	PROJ_DATA="$(cat $PROJECTS_FILE|grep ":${ENVIRONMENT_NAME}")"
	if [ "" != "$PROJ_DATA" ]; then
		PROJECT_ID="$(echo $PROJ_DATA|awk 'BEGIN {FS=OFS=":"}{print $1}')"
		PROJECT_NAME="$(echo $PROJ_DATA|awk 'BEGIN {FS=OFS=":"}{print $2}')"
		if [ "" = "$PROJECT_ID" ] || [ "" = "$PROJECT_NAME" ]; then
			echo "Errors reading project(s) file: $PROJECTS_FILE"
			exit 1
		fi
	else
		echo "Cannot find project: ${PROJECT_NAME} in file: $PROJECTS_FILE"
		exit 1
	fi
else
	echo "Cannot find project(s) file: $PROJECTS_FILE"
	exit 1
fi

if [ "" = "$(which kubectl 2> /dev/null)" ]; then
	echo "Install mini-kube ..."
	LATEST="$(curl -sL https://storage.googleapis.com/kubernetes-release/release/stable.txt)"
	if [ "" = "$LATEST" ]; then
		LATEST="v1.17.0"
		echo "Unable to locate latest version using : $LATEST"
	else
		echo "Latest verion is : $LATEST"
	fi
	curl -sLO https://storage.googleapis.com/kubernetes-release/release/$LATEST/bin/$OS/amd64/kubectl$EXT -o $FOLDER/bin/kubectl$EXT
	if [ "" == "$(which kubectl 2> /dev/null)" ]; then
		echo "Error: Unable to install kubectl!!"
		exit 4
	fi
	chmod +x $FOLDER/bin/kubectl$EXT
	echo "Tool kubectl installed correctly!!"
fi

if [ "" = "$(which helm 2> /dev/null)" ]; then
	echo "Install helm ..."
	LATEST="$(curl -sL https://github.com/helm/helm/releases |grep helm|grep releases|grep tag|grep Helm|head -1|awk 'BEGIN {FS=OFS=" "}{print $NF}'|tail -1|awk 'BEGIN {FS=OFS="<"}{print $1}'|awk 'BEGIN {FS=OFS=">"}{print $NF}')"
	if [ "" = "$LATEST" ]; then
		LATEST="v2.16.3"
		echo "Unable to locate latest version using : $LATEST"
	else
		echo "Latest verion is : $LATEST"
	fi
	LATEST="v2.11.0"
	echo "Latest verion is : $LATEST"
	curl -sL https://raw.githubusercontent.com/helm/helm/master/scripts/get > $FOLDER/get_helm.sh
	if [ -e $FOLDER/get_helm.sh ]; then
		bash -c "export HELM_INSTALL_DIR="$FOLDER/bin"&& alias sudo=\"/bin/sh\" && $FOLDER/get_helm.sh --no-sudo -v $LATEST"
		rm -f $FOLDER/helm-*.tar.gz
		rm -f $FOLDER/get_helm.sh
	fi
	if [ "" == "$(which helm 2> /dev/null)" ]; then
		echo "Error: Unable to install helm!!"
		exit 4
	fi
	chmod +x $FOLDER/bin/helm*
	echo "Tool helm installed correctly!!"
fi

if [ "" = "$(which kops 2> /dev/null)" ]; then
	echo "Install kops ..."
	LATEST="$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)"
	if [ "" = "$LATEST" ]; then
		LATEST="v1.15.2"
		echo "Unable to locate latest version using : $LATEST"
	else
		echo "Latest verion is : $LATEST"
	fi
	
	curl -sL  https://github.com/kubernetes/kops/releases/download/1.15.0/kops-$OS-amd64 -o $FOLDER/bin/kops$EXT
	if [ "" == "$(which kops 2> /dev/null)" ]; then
		echo "Error: Unable to install kops!!"
		exit 4
	fi
	chmod +x $FOLDER/bin/kops$EXT
	echo "Tool kops installed correctly!!"
fi

if [ "" = "$(which kind 2> /dev/null)" ]; then
	echo "Install kind ..."
	LATEST="v$(curl -s https://github.com/kubernetes-sigs/kind/releases|grep kind|grep releases|grep tag|grep '/v'|head -1|awk 'BEGIN {FS=OFS=" "}{print $NF}'|tail -1|awk 'BEGIN {FS=OFS="<"}{print $1}'|awk 'BEGIN {FS=OFS=">"}{print $NF}')"
	if [ "" = "$LATEST" ]; then
		LATEST="v0.7.0"
		echo "Unable to locate latest version using : $LATEST"
	else
		echo "Latest verion is : $LATEST"
	fi
	
	curl -sL  https://github.com/kubernetes-sigs/kind/releases/download/$LATEST/kind-$OS-amd64 -o $FOLDER/bin/kind$EXT
	if [ "" == "$(which kind 2> /dev/null)" ]; then
		echo "Error: Unable to install kind!!"
		exit 4
	fi
	chmod +x $FOLDER/bin/kind$EXT
	echo "Tool kind installed correctly!!"
fi

HELM_EXTRA=""

HELM_CONTENT_PATH="$HOME"
if [ "" != "$DEFAULT_HELM_CONTENT_PATH" ]; then
	HELM_CONTENT_PATH="$DEFAULT_HELM_CONTENT_PATH"
fi

if [ ! -e ~/.helm ]; then
	mkdir -p $HELM_CONTENT_PATH/.helm/repository
	mkdir -p $HELM_CONTENT_PATH/.helm/cache
	mkdir -p $HELM_CONTENT_PATH/.helm/config
	mkdir -p $HELM_CONTENT_PATH/.helm/data
	touch $HELM_CONTENT_PATH/.helm/registry.json
	touch $HELM_CONTENT_PATH/.helm/repositories.yaml
	silentDos2Unix "$HELM_CONTENT_PATH/.helm/registry.json"
	silentDos2Unix "$HELM_CONTENT_PATH/.helm/repositories.yaml"
fi
HELM_DIR="$HELM_CONTENT_PATH/.helm"
HELM_EXTRA="--registry-config $HELM_DIR/registry.json"
HELM_EXTRA="$HELM_EXTRA --repository-cache $HELM_DIR/repository"
HELM_EXTRA="$HELM_EXTRA --repository-config $HELM_DIR/repositories.yaml"

export XDG_CACHE_HOME=$HELM_CONTENT_PATH/.helm/cache
export XDG_CONFIG_HOME=$HELM_CONTENT_PATH/.helm/config
export XDG_DATA_HOME=$HELM_CONTENT_PATH/.helm/data
#export HELM_DRIVER=#One of configmap, secret, memory       |
#export HELM_NO_PLUGINS=#1 to disable plugins.                  |

RANCHER_MASTER_NODE_NAME="$(getMasterNodeName "${PREFIX}")"

if [ "" = "$RANCHER_MASTER_NODE_NAME" ]; then
	echo "Rancher MASTER node '$RANCHER_MASTER_NODE_NAME' NOT available!!"
	exit 1
fi

echo "Rancher MASTER node: $RANCHER_MASTER_NODE_NAME"

RANCHER_MASTER_NODE_IP="$(getMasterNodeIp "${PREFIX}")"

if [ "" = "$RANCHER_MASTER_NODE_IP" ]; then
	echo "Rancher MASTER node '$RANCHER_MASTER_NODE_NAME' NOT reported or not active in docker-machine!!"
	exit 1
fi

echo "Rancher MASTER node IP: $RANCHER_MASTER_NODE_IP"
echo " "
echo "--------------------------------"
echo "Origin Repository: $REPO_URL"
echo "Repository Branch: $REPO_BRANCH"
echo "Kubernetes Namespece: $NAMESPACE"
echo "Kubernetes Namespece: $MAIN_CHART_FILE"
echo "Load Balancer File: $LOAD_BALANCERS_FILE"
echo "--------------------------------"

echo "Looking for Helm  remote configuration ..."
HELM_CONFIG_FILE="$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-config.yml"
if [ ! -e $HELM_CONFIG_FILE ]; then
	echo "Helm configuration file : $HELM_CONFIG_FILE doesn't exists ..."
	echo "Please download key/config for Helm and Use on Rancher Serer Web-ui Kubernetes -> Kubernetes CLI -> Create Config -> Download File "
	echo "Save it please in the project folder: $FOLDER/.settings on this file path to $HELM_CONFIG_FILE"
	exit 1
fi
silentDos2Unix "$HELM_CONFIG_FILE"
export KUBECONFIG=$HELM_CONFIG_FILE
KUBECTL_BASE="kubectl --kubeconfig=$HELM_CONFIG_FILE"
HELM_BASE="helm --kubeconfig=$HELM_CONFIG_FILE"
echo " "
echo "Cluster:"
echo "$($KUBECTL_BASE get all)"
echo " "
echo " "
echo "Namespaces:"
NAMESPACES="$($KUBECTL_BASE get namespaces|grep -v NAME|awk 'BEGIN {FS=OFS=" "}{print $1}')"
SIZE=0
NS_FOUND="false"
IFS=$'\n'; for i in $NAMESPACES; do
	echo "$i"
	let SIZE=SIZE+1
	if [ "$NAMESPACE" == "$i" ]; then
		NS_FOUND=true
	fi
done
echo "Total: $SIZE"
echo " "

if [ "true" == "$NS_FOUND" ]; then
	NAMESPACE_YAML="$(sh -c "$KUBECTL_BASE get namespace $NAMESPACE -o yaml")"
	echo "k8s namespace '$NAMESPACE' already esists!!"
else
	echo "k8s namespace '$NAMESPACE' doesn't esist!!"
	echo "creating k8s namespace '$NAMESPACE' in kubernetes cluster (Id: ${PROJECT_ID}) '${PROJECT_NAME}' ..."
	NAMESPACE_YAML="$(sh -c "$KUBECTL_BASE create namespace $NAMESPACE -o yaml")"
	IFS=' ';for file in $(ls $FOLDER/secrets|xargs echo); do
		secret_file_name="$FOLDER/secrets/$file"
		if [[ $file =~ '.env' ]]; then
			echo "ENV Secret file: $secret_file_name"
			source $secret_file_name
			if [ "" != "${REG_NAME}" ] && [ "" != "${REG_URL}" ] && [ "" != "${REG_USERNAME}" ]  && [ "" != "${REG_PASSWORD}" ]; then
				CMD="$KUBECTL_BASE --namespace=$NAMESPACE create secret docker-registry ${REG_NAME}secret --docker-server=${REG_URL} --docker-username=${REG_USERNAME} --docker-password=${REG_PASSWORD} --docker-email=${REG_EMAIL}" 2> /dev/null
				sh -c "$CMD"
			else
				echo "Insufficient properties in file ${file} -> needed: REG_NAME, REG_URL, REG_USERNAME and REG_PASSWORD"
			fi
			REG_NAME=
			REG_USERNAME=
			REG_PASSWORD=
			REG_EMAIL=
			REG_URL=
		elif [[ $file =~ '.yaml' ]] || [[ $file =~ '.yml' ]]; then
			echo "YAML K8s Secret file: $secret_file_name"
			CMD="$KUBECTL_BASE --namespace=$NAMESPACE apply -f $secret_file_name"
			sh -c "$CMD"
		else
			echo "Unknown Secret file type: $secret_file_name"
		fi
	done
	sh -c "$KUBECTL_BASE --namespace=$NAMESPACE get secrets"
	IFS=' ';for file in $(ls $FOLDER/serviceaccounts|xargs echo); do
		sa_file_name="$FOLDER/serviceaccounts/$file"
		if [[ $file =~ '.yaml' ]] || [[ $file =~ '.yml' ]]; then
			echo "YAML K8s service account: $sa_file_name"
			CMD="$KUBECTL_BASE --namespace=$NAMESPACE apply -f $sa_file_name"
			sh -c "$CMD"
		else
			echo "Unknown Service Account file type: $sa_file_name"
		fi
	done
	sh -c "$KUBECTL_BASE --namespace=$NAMESPACE get serviceaccounts"
fi
NS_SUFFIX="$(fixIdValue "$NAMESPACE")"
HELM_NSS_FILE="$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-namespaces.yml"
HELM_NS_FILE="$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-namespace-$NS_SUFFIX.yml"
echo -e "$NAMESPACE:$NS_SUFFIX" >> $HELM_NSS_FILE
echo -e "$NAMESPACE_YAML" > $HELM_NS_FILE
silentDos2Unix "$HELM_NSS_FILE"
silentDos2Unix "$HELM_NS_FILE"
echo "Name space: $NAMESPACE descriptor: "
cat $HELM_NS_FILE
echo " "
echo " "

KUBECTL_BASE="$KUBECTL_BASE --namespace=$NAMESPACE"
HELM_BASE="$HELM_BASE --namespace=$NAMESPACE"
echo "Cluster Info"
BUFFER="$($KUBECTL_BASE cluster-info 2> /dev/null | grep -v kubectl)"
if [ "" = "$BUFFER" ]; then
	echo "No Cluster Info available: No object available right now"
else
	echo "$BUFFER"
fi
echo " "
echo " "
echo "Available Services"
BUFFER="$($KUBECTL_BASE get services 2> /dev/null | grep -v NAME)"
if [ "" = "$BUFFER" ]; then
	echo "No Services available right now"
else
	echo "$BUFFER"
fi
echo " "
echo " "

if [ "--create-infra-and-exit" = "${4,,}" ]; then
	echo "Infrastructure created... now exiting as required!!"
	OUT_FILE="$FOLDER/${PREFIX}${PROJECT_NAME}-deploy-config.env"
	echo "You can use this file to configure local environment and execute commands: $OUT_FILE"
	echo "Run: source $OUT_FILE"
	echo "Then use kube-ns and helm-ns already configured for your Namespace"
	echo "NAMESPACE=\"${NAMESPACE}\"" > $OUT_FILE
	echo "NAMESPACE_YAML_FILE=\"${HELM_NS_FILE}\"" >> $OUT_FILE
	echo "KUBECTL_BASE=\"$KUBECTL_BASE\"" >> $OUT_FILE
	echo "PATH=\"\$PATH\":$FOLDER/bin" >> $OUT_FILE
	echo "KUBECONFIG=\"$HELM_CONFIG_FILE\"" >> $OUT_FILE
	echo "HELM_DIR=\"$HELM_DIR\"" >> $OUT_FILE
	echo "alias kube-ns=\"$KUBECTL_BASE\"" >> $OUT_FILE
	echo "alias helm-ns=\"$HELM_BASE $HELM_EXTRA\"" >> $OUT_FILE
	cat "$FOLDER/.settings/${PREFIX}${PROJECT_NAME}-project.env" >> $OUT_FILE
	exit 0
fi

if [ ! -e $FOLDER/repositories ]; then
	echo "Creating $FOLDER/repositories folder ..."
	mkdir $FOLDER/repositories
fi

cd $FOLDER/repositories
git clone $REPO_URL
REPO_FOLDER="$(echo $REPO_URL|awk 'BEGIN {FS=OFS="/"}{print $NF}'|awk 'BEGIN {FS=OFS="."}{print $1}')"
cd "$REPO_FOLDER"
git checkout $REPO_BRANCH
git pull origin $REPO_BRANCH


if [ "" = "$$MAIN_CHART_FILE" ] && [ "" = "$CHART_NAME" ] && [ "" = "$UPGRADE_CHART" ]; then
	echo "Please provide CHART file and name or up upgrade name"
fi


echo "Start Verify of main chart ..."

if [ "" != "$MAIN_CHART_FILE" ]; then
	echo "Start Lint of main chart ..."
	
	helm $HELM_EXTRA lint ./$MAIN_CHART_FILE
	state="$?"
	if [ "0" != "$state" ]; then
		echo "HELM LINT failed, please review the repository: $REPO_URL!!"
		exit 1
	fi

	echo "Start Verify of main chart ..."

	helm $HELM_EXTRA verify ./$MAIN_CHART_FILE
	state="$?"
	if [ "0" != "$state" ]; then
		echo "HELM VERIFY failed, please review the repository: $REPO_URL!!"
		exit 1
	fi
else
	echo "Upgrade required, no Lint and Verify required ..."
fi

echo "Start Chart deploy ..."
if [ "yes" = "$UPGRADE_CHART" ]; then
	echo "Start upgrading the Chart: $UPGRADE_CHART_NAME ..."
	UPGRADE="no"
	if [ "" != "$UPGRADE_CHART_NAME" ]; then
		echo "List of information of Chart: $UPGRADE_CHART_NAME"
		echo "-----------------------------------------------------"
		echo "$(helm show all "$UPGRADE_CHART_NAME")"
		echo "-----------------------------------------------------"
		echo " "
		if [ "" != "$$UPGRADE_CHART_RELEASE" ]; then
			helm $HELM_EXTRA upgrade "$UPGRADE_CHART_NAME" "$UPGRADE_CHART_RELEASE"
			state="$?"
			if [ "0" != "$state" ]; then
				echo "HELM UPGRADE failed, please review the Chart upgrade information!!"
				exit 1
			fi
			UPGRADE="yes"
			echo "status of Chart Release: $UPGRADE_CHART_RELEASE"
			echo "-----------------------------------------------------"
			echo "$(helm status "$UPGRADE_CHART_RELEASE")"
			echo "-----------------------------------------------------"
			echo " "
		fi
		if [ "no" == "$UPGRADE" ]; then
			echo "HELM UPGRADE not performed, please review your configuration!!"
			exit 1
		else
			echo "HELM UPGRADE successful!!"
		fi
	fi
else
	echo "Start creating the Chart..."
	CREATED="no"
	if [ "" != "$CHART_NAME" ] && [ "" != "$CHART_LOCAL_NAME" ]; then
		VARS=""
		if [ "" != "$CHART_VARS_FILE" ] && [ "." != "$CHART_VARS_FILE" ] && [ -e $CHART_VARS_FILE ]; then
			silentDos2Unix "$CHART_VARS_FILE"
			if [[ $CHART_VARS_FILE == *".yaml" ]] || [[ $CHART_VARS_FILE == *".yml" ]]; then
				VARS="--values=$CHART_VARS_FILEs"
			else
				IFS=$'\n'; for line in $(cat $CHART_VARS_FILE); do
					if [ "" !=  "$line" ]; then
						VARS="$VARS --set $line";
					fi
				done
			fi
		fi
		helm $HELM_EXTRA install --repo $REPO_URL $VARS "$CHART_LOCAL_NAME" $CHART_NAME 
		state="$?"
		if [ "0" != "$state" ]; then
			echo "HELM INSTALL failed, please review the Chart install information!!"
			exit 1
		fi
		CREATED="yes"
		echo "List of information of Chart: $CHART_NAME"
		echo "-----------------------------------------------------"
		echo "$(helm show all "$CHART_NAME")"
		echo "-----------------------------------------------------"
		echo " "
	fi
	if [ "no" == "$CREATED" ]; then
		echo "HELM INSTALL not performed, please review your configuration!!"
		exit 1
	else
		echo "HELM INSTALL successful!!"
	fi
fi

if [ "" != "$LOAD_BALANCERS_FILE" ] && [ "." != "$LOAD_BALANCERS_FILE" ]; then
	if [ -e $LOAD_BALANCERS_FILE ]; then
		sh -c "$FOLDER/deploy-in-cluster-rancher-kubernetes-load-balancers.sh $$LOAD_BALANCERS_FILE"
	else
		echo "Load Balancers config file: $LOAD_BALANCERS_FILE doesn't exist"
		exit 1
	fi
else
	echo "Skipping creation of Load Balancers for the chart"
fi

cd $FOLDER

exit 0