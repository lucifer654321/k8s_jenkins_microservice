#!/bin/bash

K8S_Master_IP=(192.168.49.30)
K8S_Node_IP=(192.168.49.31 192.168.49.32)
K8S_Storage_IP="192.168.49.33"
K8S_Master_Host=(k8smaster01)
K8S_Node_Host=(k8snode01 k8snode02)
K8S_Storage_Host="storage"
K8S_ALL_IP=(${K8S_Master_IP[@]} ${K8S_Node_IP[@]} ${K8S_Storage_IP})
K8S_ALL_HOST=(${K8S_Master_Host[@]} ${K8S_Node_Host[@]} ${K8S_Storage_Host})

sed -ri '3,$d' /etc/hosts
for num in ${#K8S_ALL_IP[@]}
do
	echo "${K8S_ALL_IP[num]}  ${K8S_ALL_HOST[num]}" >> /etc/hosts
done

# 禁用防火墙和selinux
systemctl disable firewalld
systemctl stop firewalld
sed -ri '/^SELINUX=/cSELINUX=disabled'  /etc/selinux/config
setenforce 0

# 关闭swap
swapoff -a
sed -ri '/swap/s/^/#/' /etc/fstab

# 时间同步
yum install -y chrony
systemctl enabled chronyd

# 配置limit
ulimit -SHn 65535

sed -i '/# End of file/d'  /etc/security/limits.conf
cat >>/etc/security/limits.conf<<EOF
# 末尾添加如下内容
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
# End of file
EOF

# 安装IPVS
yum install ipvsadm ipset sysstat conntrack libseccomp -y

modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack

cat >/etc/modules-load.d/ipvs.conf<<EOF
# 加入以下内容
ip_vs
ip_vs_lc
ip_vs_wlc
ip_vs_rr
ip_vs_wrr
ip_vs_lblc
ip_vs_lblcr
ip_vs_dh
ip_vs_sh
ip_vs_fo
ip_vs_nq
ip_vs_sed
ip_vs_ftp
ip_vs_sh
nf_conntrack
ip_tables
ip_set
xt_set
ipt_set
ipt_rpfilter
ipt_REJECT
ipip
EOF

systemctl enable --now systemd-modules-load.service

cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 65536
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF
sysctl --system

# 安装依赖软件包
yum install -y yum-utils device-mapper-persistent-data lvm2
# 添加Docker repository，这里使用国内阿里云yum源
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# 安装docker-ce，这里直接安装最新版本
Docker_Ver="19.03.*"
yum install docker-ce-${Docker_Ver} docker-ce-cli-${Docker_Ver} -y
mkdir -p /data/docker/{data,exec}
#修改docker配置文件
mkdir /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["https://dbzucv6w.mirror.aliyuncs.com"],
    "insecure-registries": ["${K8S_Storage_IP}"],
    "exec-opts": ["native.cgroupdriver=systemd"],
    "data-root": "/data/docker/data",
    "exec-root": "/data/docker/exec",
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
  ]
}
EOF
# 注意，由于国内拉取镜像较慢，配置文件最后增加了registry-mirrors
mkdir -p /etc/systemd/system/docker.service.d
# 重启docker服务
systemctl daemon-reload
systemctl enable --now docker
