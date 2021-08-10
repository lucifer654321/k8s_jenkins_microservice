# k8s_jenkins_microservice
> Kubernetes+Jenkins+Harbor+GitLab+Helm Deploy MicroService

# Deploy Steps:
## 1. Deploy K8s Cluster
### 1.1 run init_k8s.sh in all kubernetes cluster nodes 

sh ./k8s_jenkins_microservice/deploy/kubernetes/init_k8s.sh

### 1.2 Install kubeadm
#### Setting YUM repo for k8s
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
       http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

#### install kubeadm
yum list kubelet kubeadm kubectl  --showduplicates|sort -r

yum -y install kubeadm-1.20.9 kubectl-1.20.9 kubelet-1.20.9
systemctl enable kubelet.service

 
### 1.3 Deploy HA if you need

### 1.4 init k8s master
cd k8s_jenkins_microservice/deploy/kubernetes

#### output init-defaults config for YAML if you want to manual setup
kubeadm config print init-defaults --component-configs KubeProxyConfiguration > kubeadm-config.yml

#### apply the kubeadm-config.yml with default
##### pull the images for k8s at all nodes
kubeadm config images pull --config=kubeadm-config.yaml

#### init master
kubeadm init --config=kubeadm-config.yaml --upload-certs | tee kubeadm-init.log

#### kubectl命令自动补全
yum install -y bash-completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

### 1.5 Install Network Plugin
kubectl apply -f kube-flannel.yml

### 1.6 Install ingress-nginx
kubectl apply -f mandatory.yaml

### 1.7 Install NFS-Clinet for auto PVs
#### 1.7.1 install nfs in all nodes
yum install -y nfs-utils

#### 1.7.2 deploy NFS Server(storage Node)
##### 创建NFS共享目录
cat >>/etc/exports<<EOF
/ifs/kubernetes *(rw,no_root_squash)
EOF

mkdir -p /ifs/kubernetes

##### 启动NFS
systemctl enable --now nfs-server

#### 1.7.3 Deploy auto PVs(master)
cd k8s_jenkins_microservice/deploy/nfs-client
kubectl apply -f .

#### 1.7.4 PVC Status in Pending 
##### 修改kube-apiserver.yaml参数
sed -ri '25a    - --feature-gates=RemoveSelfLink=false' /etc/kubernetes/manifests/kube-apiserver.yaml

##### 重启apiserver
kubectl -n kube-system delete pods -l component=kube-apiserver

### 1.8 deploy helm
sh deploy_helm_v3.sh

## 2 Deploy Storage
cd k8s_jenkins_microservice/deploy/storage

### 2.1 Deploy Harbor
sh deploy_harbor_chart.sh

### 2.2 Deploy GitLab
sh deploy_gitlab.sh

## 3.deploy jenkins
cd k8s_jenkins_microservice/deploy/jenkins
kubectl apply -f .

## 4.jenkins-slave
cd k8s_jenkins_microservice/deploy/jenkins-slave
cp /usr/bin/helm .
cp /bin/kubectl .

docker login 192.168.49.33 -uadmin -pHarbor12345

docker build -t 192.168.49.33/library/jenkins-slave-jdk:1.8 .
docker push 192.168.49.33/library/jenkins-slave-jdk:1.8

## 5.install eureka-service
### 安装Java环境
yum install -y java-1.8.0-openjdk maven

### 创建项目namespace
kubectl create ns ms


cd k8s_jenkins_microservice/simple-microservice
cd k8s
./docker_build.sh eureka-service


