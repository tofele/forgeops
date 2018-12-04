#!/bin/bash

#
# Proxy Config
#

pxon() {
    export PROXY=proxy.ogtg.swsnet.ch:3128
    export DOCKER_ENV="--docker-env http_proxy=$PROXY --docker-env http_proxy=$PROXY"

    export HTTP_PROXY=$PROXY
    export HTTPS_PROXY=$PROXY
    export NO_PROXY=192.168.0.0/16,169.254.0.0/16,localhost,127.0.0.1

    export http_proxy=$PROXY
    export https_proxy=$PROXY
    export no_proxy=192.168.0.0/16,169.254.0.0/16,localhost,127.0.0.1

}

pxoff() {
    export PROXY=
    export DOCKER_ENV=

    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset NO_PROXY

    unset http_proxy
    unset https_proxy
    unset no_proxy
}

pxon


install() {

    set -v

    #
    # 2.2 Installing Required Third-Party Software
    #

    # download & install docker
    sudo systemctl stop docker
    sudo yum remove -y docker-ce
    sudo rm -f /etc/yum.repos.d/docker-ce.repo
    rm -rf ~/.docker
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum install -y docker-ce
    sudo systemctl start docker
    sudo docker run hello-world

    # download & install kubectl
    sudo yum remove -y kubectl
    sudo rm -f /etc/yum.repos.d/kubernetes.repo
    rm -rf ~/.kube
    sudo chown $USER /etc/yum.repos.d
    sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
    sudo chown root /etc/yum.repos.d
    sudo yum install -y kubectl

    # download & install helm
    #HELM_VERSION=2.10.0
    HELM_VERSION=2.9.1
    wget -O /tmp/helm.tgz https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz
    sudo rm -f /usr/local/bin/helm*
    rm -rf ~/.helm
    cd /tmp
    tar xvzf /tmp/helm.tgz
    sudo rm -f /usr/local/bin/helm*
    sudo mv linux-amd64/helm /usr/local/bin/helm-$HELM_VERSION
    sudo chmod 755 /usr/local/bin/helm-$HELM_VERSION
    sudo rm -rf /tmp/helm.tgz /tmp/linux-amd64
    sudo ln -s /usr/local/bin/helm-$HELM_VERSION /usr/local/bin/helm

    # download & install kubectx & kubens
    sudo rm -rf /opt/kubectx /usr/local/bin/kubectx /usr/local/bin/kubens
    cd ~/git
    rm -rf ~/git/kubectx
    git clone https://github.com/ahmetb/kubectx
    sudo cp -rp ~/git/kubectx /opt
    sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
    sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

    # download & install stern
    STERN_VERSION=1.8.0
    sudo rm -f /usr/local/bin/stern*
    sudo curl -Lo /usr/local/bin/stern-$STERN_VERSION https://github.com/wercker/stern/releases/download/$STERN_VERSION/stern_linux_amd64
    sudo chmod 755 /usr/local/bin/stern-$STERN_VERSION
    sudo ln -s /usr/local/bin/stern-$STERN_VERSION /usr/local/bin/stern

    # download & install minikube
    MINIKUBE_VERSION=0.28.2
    #MINIKUBE_VERSION=0.28.0
    sudo rm -f /usr/local/bin/minikube*
    sudo curl -Lo /usr/local/bin/minikube-$MINIKUBE_VERSION https://storage.googleapis.com/minikube/releases/v$MINIKUBE_VERSION/minikube-linux-amd64
    sudo chmod 755 /usr/local/bin/minikube-$MINIKUBE_VERSION
    sudo ln -s /usr/local/bin/minikube-$MINIKUBE_VERSION /usr/local/bin/minikube


    # download & install Google Cloud SDK
    sudo yum remove -y google-cloud-sdk
    sudo rm -f /etc/yum.repos.d/google-cloud-sdk.repo
    sudo chown $USER /etc/yum.repos.d
    sudo cat <<EOM > /etc/yum.repos.d/google-cloud-sdk.repo
    [google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
    sudo chown root /etc/yum.repos.d
    sudo yum install -y google-cloud-sdk

    # download & install VirtualBox
    #VB_VERSION=5.2
    #sudo yum remove -y VirtualBox-$VB_VERSION
    #sudo rm -f /etc/yum.repos.d/virtualbox.repo
    #sudo curl -Lo /etc/yum.repos.d/virtualbox https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
    #sudo yum install -y VirtualBox-$VB_VERSION
    #
    #rm -rf /tmp/VirtualBox*
    #cd /tmp
    #curl -L https://download.virtualbox.org/virtualbox/5.2.18/VirtualBox-5.2-5.2.18_124319_el7-1.x86_64.rpm
    #sudo yum localinstall VirtualBox*


}



set -v

#install



#
# 2.3 Configuring Your Kubernetes Cluster
#
#minikube status
#minikube delete
#rm -rf ~/.minikube
#minikube config set WantUpdateNotification false
#minikube start --memory=8192 --disk-size=30g --vm-driver=virtualbox --bootstrapper kubeadm $DOCKER_ENV
#minikube ssh sudo ip link set docker0 promisc on

gcloud container clusters create toms-cluster --network default --num-nodes 1 --machine-type n1-standard-8 --zone us-central1-f --enable-autoscaling --min-nodes=1 --max-nodes=4 --disk-size 50

kubectl get pods --all-namespaces



#
# 2.4 Setting up a Kubernetes Context
#
kubectx
#kubectx minikube
kubectx gke_forgerock-cloud_us-central1-f_toms-cluster

#gcloud container clusters get-credentials toms-cluster --zone us-central1-f --project forgerock-cloud



#
# 2.5 Setting up Helm
#
#helm init --service-account default
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --wait --service-account tiller
#sleep 10
kubectl get pods --all-namespaces | grep tiller-deploy


#
# 2.6 Deploying an Ingress Controller
#
#minikube addons enable ingress
helm install stable/nginx-ingress --namespace nginx --set "controller.service.loadBalancerIP=35.239.219.247" --set "controller.publishService.enabled=true"



#
# 2.7 Creating a Kubernetes Namespace
#
NAMESPACE=eng
kubectl create namespace $NAMESPACE
kubens $NAMESPACE



#
# 2.8 Enabling Access to a Private Docker Registry
#



#
# 2.9 Enabling HTTPS Access to Forgerock Components
#
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -subj "/CN=openam.$NAMESPACE.example.com"
#kubectl delete secret openam.$NAMESPACE.example.com
kubectl create secret tls openam.$NAMESPACE.example.com --key /tmp/tls.key --cert /tmp/tls.crt



#
# 2.10.1 Creating Your Configuration Repository
#
##  ssh-add ~/.ssh/id_rsa_forgeops-init
##  #GIT_BRANCH=release/6.0.0
##  GIT_BRANCH=master
##  mkdir -p ~/git
##  rm -rf ~/git/forgeops-init*
##  cd ~/git
##  git clone https://github.com/ForgeRock/forgeops-init.git forgeops-init-from-forgerock
##  cd ~/git/forgeops-init-from-forgerock
##  git checkout $GIT_BRANCH
##  cd ~/git
##  git clone git@github.com:tofele/forgeops-init.git
##  cd ~/git/forgeops-init
##  rm -rf ~/git/forgeops-init/*
##  #git add -A .
##  #git commit -m "Removed old content"
##  #git push -u origin master
##  cp -rp ~/git/forgeops-init-from-forgerock/* .
##  git add .
##  git commit -m "Initialize with content from ForgeRock"
##  git push -u origin master



#
# 2.10.2 Installing the frconfig Helm Chart
#
#sleep 30
kubectl get pods --all-namespaces | grep tiller-deploy
kubectl delete secret frconfig
cd ~/git/forgeops/helm
helm install frconfig --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/frconfig



#
# 2.10.3 Replacing the Default frconfig Secret
#
cp ~/.ssh/id_rsa_forgeops-init /tmp/id_rsa
kubectl delete secret frconfig
kubectl create secret generic frconfig --from-file=/tmp/id_rsa
rm -f /tmp/id_rsa


#
# 4.4.2 Using Helm to Deploy the AM and DS Example
#
cd ~/git/forgeops/helm

helm install ds --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/configstore.yaml
helm install ds --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/userstore.yaml
helm install ds --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/ctsstore.yaml

helm install openam --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/openam.yaml
helm install amster --version 6.5.0 --values ~/git/forgeops/samples/config/swissid/amster.yaml
