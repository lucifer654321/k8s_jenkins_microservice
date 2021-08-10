#!/bin/bash

Gitlab_Ver=13.9.7
Gitlab_Conf="/etc/gitlab/gitlab.rb"
Gitlab_Host="http://192.168.49.33"
Gitlab_Port=8888

# Setting YUM for gitlab
cat >/etc/yum.repos.d/gitlab-ce.repo<<EOF
[gitlab-ce]
name=Gitlab CE Repository
baseurl=https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el\$releasever/
gpgcheck=0
enabled=1
EOF

# Install base packages
yum -y install curl policycoreutils openssh-server openssh-clients postfix cronie git wget patch

# Install gitlab with defind version
yum install gitlab-ce-${Gitlab_Ver} -y

# Setting the Config for gitlab
sed -ri "s#(external_url )(.*)#\1'${Gitlab_Host}:${Gitlab_Port}'#" ${Gitlab_Conf}
sed -ri "s/(.*)(grafana\['enable'\] = )(.*)/\2false/;s/(.*)(prometheus\['enable'\] = )(.*)/\2false/;s/(.*)(gitlab_exporter\['enable'\] = )(.*)/\2false/" ${Gitlab_Conf}

# start gitlab
gitlab-ctl reconfigure
