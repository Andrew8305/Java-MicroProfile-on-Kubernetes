#!/bin/sh

function install_bluemix_cli() {
#statements
echo "Installing Bluemix cli"
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.5_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
sudo ./Bluemix_CLI/install_bluemix_cli
}

function bluemix_auth() {
echo "Authenticating with Bluemix"
echo "y" | bx login -a https://api.ng.bluemix.net --apikey $API_KEY
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
bx plugin install container-service -r Bluemix
echo "Installing kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
}

function sleep_func() {
#statements
echo "sleeping for 3m"
sleep 3m
}

function run_tests() {
bx cs workers $cluster
$(bx cs cluster-config $cluster | grep -v "Downloading" | grep -v "OK" | grep -v "The")

echo "Removing deployments"
kubectl delete svc,rc,deployments,pods -l app=microprofile-app

echo "Installing Helm"
install_helm

echo "Deploying Cloudant"
kubectl create -f manifests/deploy-cloudant.yaml

echo "Deploying speaker"
kubectl create -f manifests/deploy-speaker.yaml

echo "Deploying schedule"
kubectl create -f manifests/deploy-schedule.yaml

echo "Deploying vote"
kubectl create -f manifests/deploy-vote.yaml

echo "Deploying session"
kubectl create -f manifests/deploy-session.yaml

echo "Deploying webapp"
kubectl create -f manifests/deploy-webapp.yaml

echo "Deploying nginx"
IP_ADDRESS=$(bx cs workers $(bx cs clusters | grep deployed | awk '{ print $1 }') | grep deployed | awk '{ print $2 }')
sed -i s#"xxx.xxx.xx.xxx"#$IP_ADDRESS# manifests/deploy-nginx.yaml
kubectl create -f manifests/deploy-nginx.yaml
sleep_func

}

function install_helm(){
  echo "Download Helm"
  curl  https://storage.googleapis.com/kubernetes-helm/helm-v2.2.3-linux-amd64.tar.gz > helm-v2.2.3-linux-amd64.tar.gz
  tar -xf helm-v2.2.3-linux-amd64.tar.gz
  chmod +x ./linux-amd64
  sudo mv ./linux-amd64/helm /usr/local/bin/helm

  # Install Tiller using Helm
  echo "Install Tiller"
  helm init

  #Add the repository
  helm repo add mb http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/wasdev/microservicebuilder/helm/

  #Install Microservice Builder Fabric using Helm
  helm install mb/fabric

  #Install Microservice Builder ELK Sample
  helm repo add mb-sample https://wasdev.github.io/sample.microservicebuilder.helm.elk/charts
  helm install mb-sample/sample-elk
}

function exit_tests() {
  kubectl delete pv,pvc,jobs,svc,rc,deployments,pods -l app=microprofile-app
}


install_bluemix_cli
bluemix_auth
run_tests
exit_tests
