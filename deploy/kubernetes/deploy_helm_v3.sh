#!/bin/bash

Helm_Ver="v3.6.3"
Helm_Tar="helm-${Helm_Ver}-linux-amd64.tar.gz"
Helm_Url="https://get.helm.sh"

Harbor_User="admin"
Harbor_Pass="Harbor12345"
Harbor_Host="192.168.49.33"
Project_Name="microservice"

Helm_Pri_Repo_Name="myrepo"
Helm_Pri_Repo_Url="http://${Harbor_Host}/chartrepo/${Project_Name}"
# Download helm v3
wget -c ${Helm_Url}/${Helm_Tar}
tar xvf ${Helm_Tar}

mv linux-amd64/helm /usr/bin/
rm -rf linux-amd64

# Add Helm repository
Helm_Repo_Name="bitnami"
Helm_Repo_Url="https://charts.bitnami.com/bitnami"
helm repo add ${Helm_Repo_Name} ${Helm_Repo_Url}
helm repo update

Helm_Push_Url="https://github.com/chartmuseum/helm-push.git"
# Install helm-push plugins
helm plugin install ${Helm_Push_Url}

# Add private repository
helm repo add --username ${Harbor_User} --password ${Harbor_Pass} ${Helm_Pri_Repo_Name=} ${Helm_Pri_Repo_Url}
helm repo update
helm repo list
