#!/bin/bash

docker_registry=192.168.49.33
db_host=192.168.49.33
db_url="jdbc:mysql://${db_host}:3306/tb_product?characterEncoding=utf-8"
db_user="root"
db_pass="12345"
Harbor_User="admin"
Harbor_Pass="Harbor12345"
Harbor_Email="admin@ctnrs.com"
Harbir_Project="microservice"
docker_registry_secret_name="registry-pull-secret"
project_namespace="ms"

# Create docker-registry secret
kubectl create secret docker-registry $docker_registry_secret_name \
	--docker-server=$docker_registry \
	--docker-username=$Harbor_User \
	--docker-password=$Harbor_Pass \
	--docker-email=$Harbor_Email -n $project_namespace

service_list="eureka-service gateway-service order-service product-service stock-service portal-service"
service_list=${1:-${service_list}}
work_dir=$(dirname $PWD)
current_dir=$PWD

# Package for java
cd $work_dir
mvn clean package -Dmaven.test.skip=true

# Build the Docker images and push to Harbor, and apply in k8s
for service in $service_list; do
   cd $work_dir/$service
   if ls |grep biz &>/dev/null; then
      cd ${service}-biz
      # Change DB info
      app="src/main/resources/application-fat.yml"
      sed -ri "s#(url: )(.*)#\1${db_url}#;s#(username: )(.*)#\1${db_user}#;s#(password: )(.*)#\1$(db_pass)#" $app
   fi
   service=${service%-*}
   image_name=$docker_registry/${Harbir_Project}/${service}:$(date +%F-%H-%M-%S)
   docker build -t ${image_name} .
   docker push ${image_name} 
   sed -i -r "s#(image: )(.*)#\1$image_name#" ${current_dir}/${service}.yaml
   kubectl apply -f ${current_dir}/${service}.yaml
done
