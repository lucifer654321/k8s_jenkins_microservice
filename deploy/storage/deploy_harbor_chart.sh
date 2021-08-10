#!/bin/bash

Bin_Path="/usr/local/bin"
Docker_Compose_Ver="1.25.0"
Docker_Compose_Url="https://github.com/docker/compose/releases/download/${Docker_Compose_Ver}/docker-compose-`uname -s`-`uname -m`"
Docker_Compose_Bin="${Bin_Path}/docker-compose"

Harbor_Ver="v2.3.1"
Harbor_Host="192.168.49.33"
Harbor_Conf="harbor.yml"
Base_Dir="/opt"
Harbor_Base_Dir="${Base_Dir}/harbor"
Harbor_Data_Dir="/data/harbor"
Harbor_tar="harbor-offline-installer-${Harbor_Ver}.tgz"
Harbor_Url="https://github.com/goharbor/harbor/releases/download/${Harbor_Ver}/${Harbor_tar}"

# Download docker-compose
${Docker_Compose_Bin} --version &> /dev/null
if [ $? != 0 ];then
	for i in `seq 1 3`
	do
		if [ ! -f ${Docker_Compose_Bin} ];then
			curl -L ${Docker_Compose_Url} -o ${Docker_Compose_Bin}
			[ $? == 0 ] && break
			[ $i == 3 ] && \
      echo -e "\033[31m ########################################## \033[0m" && \
      echo -e "\033[31m \tDocker-compose Can't Download! \n \tPlease Download it with manual! \033[0m" && \
      echo -e "\033[31m ########################################## \033[0m" && \
 			exit
		else
			 break
		fi
	done
	chmod +x ${Docker_Compose_Bin}
fi

# Download harbor-offline package
yum install -y wget git
count=0
while [ $count -lt 3 ]
do
	let count++
	if [ ! -f ${Harbor_tar} ];then
		wget -c ${Harbor_Url}
		[ $? == 0 ] && break
		[ $count -eq 3 ] && \
    echo -e "\033[31m ########################################## \033[0m" && \
    echo -e "\033[31m Error for Download Harbor-offline package! \n \tPlease Download it with manual! \033[0m" && \
    echo -e "\033[31m ########################################## \033[0m" && \
 	  exit
	else
		break
	fi
done

[ -d ${Harbor_Base_Dir} ] || mkdir -p ${Harbor_Base_Dir}
[ -d ${Harbor_Data_Dir} ] || mkdir -p ${Harbor_Data_Dir}
tar zxvf ${Harbor_tar} -C ${Base_Dir}

# Config for harbor
cd ${Harbor_Base_Dir}
[ -f ${Harbor_Conf} ] || cp ${Harbor_Conf}.tmpl ${Harbor_Conf}
sed -ri "s/(hostname: )(.*)/\1${Harbor_Host}/;s#(data_volume: )(.*)#\1${Harbor_Data_Dir}#" ${Harbor_Conf}
sed -ri '/^https:/,/private_key: /s/^/#/' ${Harbor_Conf}

# Install and Start
./prepare
./install.sh --with-chartmuseum

# Check the processes for Harbor
${Docker_Compose_Bin} ps
