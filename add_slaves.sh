#!/usr/bin/env bash
#Author: kenneth.fang@gaopeng.com
#Version: 1.1.0
#CDH集群追加计算节点脚本, 适用于Redhat/CentOS 7.x 64位版本，用于向已有集群追加节点
#执行方式： 填写要安装CDH的节点IP清单， 并在主节点上执行本脚本

#集群机器名前缀, 可自定义，必须与已存在的集群机器名前缀一致
NODE_NAME_PREFIX="cdh";

# 已存在的集群机器名清单，如果是使用setup_cdh脚本安装的，可不填，但必须确保/opt/setup_cdh_installer/hosts 文件中已经存在旧集群所有节点的host
ALREADY_EXIST_NODE_NAME_LIST=""

#要追加的节点IP， 以逗号分隔，将会被重命名为 前缀名 + 编号的形式
NODE_IP_LIST="192.168.0.6,192.168.0.7,192.168.0.8";

# 请勿修改以下内容：
# --------------------------------------------------------------------
ORACLE_JDK_PACKAGE="jdk-8u181-linux-x64.tar.gz";

MYSQL_JDBC_DRIVER="mysql-connector-java-5.1.47.tar.gz";

CLOUDERA_MANAGER_DEAMON="cloudera-manager-daemons-5.15.1-1.cm5151.p0.3.el7.x86_64.rpm";

CLOUDERA_MANAGER_SERVER="cloudera-manager-server-5.15.1-1.cm5151.p0.3.el7.x86_64.rpm";

CLOUDERA_MANAGER_AGENT="cloudera-manager-agent-5.15.1-1.cm5151.p0.3.el7.x86_64.rpm";

CDH_PARCEL="CDH-5.15.1-1.cdh5.15.1.p0.4-el7.parcel";

CDH_SHA="CDH-5.15.1-1.cdh5.15.1.p0.4-el7.parcel.sha";

CDH_MANIFEST_JSON="manifest.json";
#--------------------------------------------------------------------


CURRENT_IP=$(/sbin/ifconfig -a | grep inet | grep -v "127.0.0.1\|inet6\|0.0.0.0" | awk '{print $2}' | tr -d "addr:");
PROJECT_NAME="setup_cdh";
PROJECT_PATH=$(pwd);
PACKAGES_PATH="${PROJECT_PATH}/packages";
TMP_DIR="/opt/setup_cdh_installer";
CUR_DATE=$(date "+%Y%m%d")
mkdir -p ${TMP_DIR};

exitError() {
    echo "Error: $1, exit."; exit 1;
}

yumError() {
    exitError "'yum install' $1 failed.";
}

confBak() {
    /bin/cp -f "$1" "$1.bak.${CUR_DATE}" 2>/dev/null;
}

printr() {
    echo; echo "## $1"; echo;
}

#确认系统参数
ensureVariable() {
    #确认系统版本
    echo "CHECK SYSTEM Version...";
    if ! grep -qs -e "release 7" /etc/redhat-release; then
      exitError "Script only supports CentOS/RHEL 7.x";
    fi

    #确认用户为root
    echo "CHECK ROOT USER...";
    if [[ "$(id -u)" != 0 ]]; then
      exitError "Script must run as root. Try 'sudo sh $0'";
    fi

    #检查master
    if [[ $(head -n 1 ip.list) != ${CURRENT_IP} ]]; then
        exitError "Script must run on $(head -n 1 ip.list)";
    fi

    #检查是否为项目根目录
    echo "CHECK DIRECTORY...";
    if [[ $(pwd | awk -F '/' '{print $NF}') != ${PROJECT_NAME} ]]; then
        exitError "Script must run at ROOT directory";
    fi

    #检查ORACLE JDK, 如果有其他版本的JDK，则继续安装
    echo "CHECK Oracle JDK...";
    if [[ ! -f ${PACKAGES_PATH}/${ORACLE_JDK_PACKAGE} ]]; then
        if [[ -f ${PACKAGES_PATH}/jdk-8u*.tar.gz ]]; then
            ORACLE_JDK_PACKAGE=$(ls ${PACKAGES_PATH}/jdk-8u*.tar.gz | awk -F '/' '{print $NF}');
        else
            exitError "Oracle JDK NOT FOUND";
        fi
    fi

    #检查MySQL JDBC 安装包
    echo "CHECK MySQL Connector...";
    if [[ ! -f ${PACKAGES_PATH}/${MYSQL_JDBC_DRIVER} ]]; then
        exitError "MySQL Connector NOT FOUND";
    fi

    #检查cloudera manager rpm包
    echo "CHECK Cloudera Manager packages...";
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_DEAMON} ]]; then
        exitError "Cloudera Manager Deamon RPM NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_SERVER} ]]; then
        exitError "Cloudera Manager Server RPM NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_AGENT} ]]; then
        exitError "Cloudera Manager Agent RPM NOT FOUND";
    fi

    #检查CDH parcel包
    if [[ ! -f ${PACKAGES_PATH}/${CDH_PARCEL} ]]; then
        exitError "CDH Parcel FILE NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CDH_SHA} ]]; then
        exitError "CDH SHA FILE NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CDH_MANIFEST_JSON} ]]; then
        exitError "CDH manifest.json FILE NOT FOUND";
    fi

    #检查安装遗留
    echo "CHECK MySQL...";

}

# 开始远程安装节点
setUpSlave() {

printr "Slave setup start...";
#复制密钥
printr "copying rsa keys...";
scp -o StrictHostKeyChecking=no -r /root/.ssh root@$1:/root/

#创建slave上的临时目录
printr "creating temp dir in $1...";
ssh -t -o StrictHostKeyChecking=no root@$1 > /dev/null 2>&1 << EOF
mkdir -p ${TMP_DIR};
EOF

#复制hosts文件
printr "copying host file to temp dir in $1...";
scp -o StrictHostKeyChecking=no ${TMP_DIR}/hosts root@$1:${TMP_DIR}/hosts > /dev/null 2>&1

#复制rpm包 到slave的 临时目录
printr "copying rpm packages to temp dir in $1...";
scp -o StrictHostKeyChecking=no ${PACKAGES_PATH}/${CLOUDERA_MANAGER_DEAMON} root@$1:${TMP_DIR}/ > /dev/null 2>&1
scp -o StrictHostKeyChecking=no ${PACKAGES_PATH}/${CLOUDERA_MANAGER_AGENT} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制Java
printr "copying oracle jdk packages to temp dir in $1...";
scp -o StrictHostKeyChecking=no ${PACKAGES_PATH}/${ORACLE_JDK_PACKAGE} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制MySQL JDBC
printr "copying mysql jdbc drivers to temp dir in $1...";
scp -o StrictHostKeyChecking=no ${PACKAGES_PATH}/${MYSQL_JDBC_DRIVER} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制repo仓库
printr "copying repo files in $1...";
scp -o StrictHostKeyChecking=no /etc/yum.repos.d/cloudera-*.repo root@$1:${TMP_DIR}/

#生成远程执行脚本并复制到slave的临时目录
cd ${PROJECT_PATH} || exit 1;
cat > build_slave.sh << EOF
#Generated by setup_cdh_cluster.sh

#设置别名
cd ${TMP_DIR} || exit 1;
cat ${TMP_DIR}/hosts >> /etc/hosts;
echo $1 > /etc/hostname && hostname $1;
echo -e "\n#init from setup_cdh_cluster.sh ${CUR_DATE}. \ncat ${TMP_DIR}/hosts >> /etc/hosts" >> /etc/rc.local;

#关闭防火墙(所有节点)
echo -e "\n##Shutting down firewall...";
systemctl stop firewalld
systemctl disable firewalld

#设置源(所有节点)
echo -e "\n##Setting up cloudera repo...";
cp ${TMP_DIR}/cloudera-*.repo /etc/yum.repos.d/
rpm --import https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/RPM-GPG-KEY-cloudera
yum -y install htop iotop vim sysstat iftop screen
yum -y update

#安装Java(所有节点)
echo -e "\n##Installing ORACLE JDK...";
if rpm -qa | grep java; then
    rpm -qa | grep java | xargs rpm -e --nodeps
fi
if [ ! -d /usr/java ]; then
    mkdir -p /usr/java || exit 1;
fi

#解压
output=\$(tar zxvf ${TMP_DIR}/${ORACLE_JDK_PACKAGE} -C /usr/java/);
jdkFolder=\$(echo \$output | tail -n 1 | awk -F '/' '{print \$1}');
/bin/cp -f /etc/profile /etc/profile.old;

#删除旧版本JAVA HOME 变量
if grep -qe 'JAVA_HOME' /etc/profile; then
    sed -i '/JAVA_HOME/d' /etc/profile;
fi
if grep -qe 'JRE_HOME' /etc/profile; then
    sed -i '/JRE_HOME/d' /etc/profile;
fi

#设置Java环境变量(所有节点)
echo '' >> /etc/profile
echo '#FOR JAVA HOME' >> /etc/profile
echo "export JAVA_HOME=/usr/java/${jdkFolder}" >> /etc/profile
echo "export JRE_HOME=/usr/java/${jdkFolder}/jre" >> /etc/profile
echo 'export PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin' >> /etc/profile

rm -f /usr/bin/java;
ln -s /usr/java/\${jdkFolder}/bin/java /usr/bin/java

#设置开机自动启用环境变量
echo -e "source /etc/profile" >> /etc/rc.local
source /etc/profile;

#设置SELinux(所有节点)
echo -e "\n##Setting up SELinux...";
if grep -qe 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
fi
if grep -qe 'SELINUX=permissive' /etc/selinux/config; then
    sed -i "s/SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
fi

#CDH 配置(所有节点)
echo -e "\n##Setting up CDH configuration...";
echo '10' > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled

echo -e "
echo '10' > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled
" >> /etc/rc.local

#安装MySQL JDBC Driver(主要是SPARK2使用)
if [ ! -f /usr/share/java/mysql-connector-java.jar ]; then

echo -e "\n##Installing MySQL JDBC Driver...";
tar zxvf ${TMP_DIR}/${MYSQL_JDBC_DRIVER} -C ${TMP_DIR} > /dev/null 2>&1;
mkdir -p /usr/share/java || exit 1;
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar /usr/share/java/mysql-connector-java.jar
#注意此处的SPARK2位置与cloudera安装位置相关
if [ -d "/opt/cloudera/parcels/SPARK2/lib/spark2/jars" ]; then
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar /opt/cloudera/parcels/SPARK2/lib/spark2/jars/mysql-connector-java.jar
fi

else
echo -e "\n##MySQL JDBC Driver installed, jump to next step...";
fi

#安装rpm包
echo -e "\n##installing cloudera manager rpms...";
if ! rpm -qa | grep cloudera-manager-daemons; then
    yum -y install ${TMP_DIR}/${CLOUDERA_MANAGER_DEAMON} --nogpgcheck
else
    echo "cloudera-manager-daemons package installed.";
fi
if ! rpm -qa | grep cloudera-manager-agent; then
    yum -y install ${TMP_DIR}/${CLOUDERA_MANAGER_AGENT} --nogpgcheck
else
    echo "cloudera-manager-agent package installed.";
fi

#配置集群
echo -e "\n##configurating cloudera manager cluster...";
if [ -e /var/lib/cloudera-scm-agent/cm_guid ]; then
    rm -f /var/lib/cloudera-scm-agent/cm_guid;  #删除原集群的guid
fi
if grep -qe 'server_host=localhost' /etc/cloudera-scm-agent/config.ini; then
    sed -i "s/server_host=localhost/server_host=${NODE_NAME_PREFIX}1/g" /etc/cloudera-scm-agent/config.ini
fi

#启动cloudera manager agent
service cloudera-scm-agent start

exit 1;
EOF

printr "copying setup scripts to $1...";
chmod +x build_slave.sh
scp -o StrictHostKeyChecking=no build_slave.sh root@$1:${TMP_DIR}/ > /dev/null 2>&1

#开始配置Slave
printr "Start to configure slave: $1...";
ssh -t -o StrictHostKeyChecking=no root@$1 "${TMP_DIR}/build_slave.sh";

}

#开始安装
if [[ -z ${ALREADY_EXIST_NODE_NAME_LIST} ]]; then

    if [[ ! -r ${TMP_DIR}/hosts ]]; then
        exitError  "${TMP_DIR}/hosts file NOT FOUND.";
    fi

    #1. 生成新节点的追加host文件
    printr "creating new host file...";
    tmpHostFile="/tmp/hosts_tmp";
    rm -f ${tmpHostFile};

    #获取已存在的主机数量
    existNodeCount=$(cat ${TMP_DIR}/hosts | grep -v '^$' | wc -l);
    #命名新增节点
    nodeList=(${NODE_IP_LIST//,/ });
    for nodeIp in ${nodeList[@]} ; do
        ((existNodeCount++));
        hostName="${NODE_NAME_PREFIX}${existNodeCount}";
        echo  "${nodeIp}  ${hostName}" >> ${tmpHostFile};
    done

    #2. 追加新增的hosts到已有节点
    printr "adding new hosts to exist hosts...";
    cat ${TMP_DIR}/hosts | while read line
    do
        existNode=`echo ${line} | awk '{print $2}'`
        scp -t -o StrictHostKeyChecking=no ${tmpHostFile} root@${existNode}:${tmpHostFile} > /dev/null 2>&1
        ssh -t -o StrictHostKeyChecking=no root@${existNode} "cat ${tmpHostFile} >> /etc/hosts";
    done

    #3. #追加hosts到已有hosts文件，复制到新节点，开始安装
    existNodeCount=$(cat ${TMP_DIR}/hosts | grep -v '^$' | wc -l);
    cat ${tmpHostFile} >> ${TMP_DIR}/hosts && rm -f ${tmpHostFile};
    for nodeIp in ${nodeList[@]} ; do
        ((existNodeCount++));
        printr "deploying ${nodeIp}...";
        setUpSlave "${NODE_NAME_PREFIX}${existNodeCount}";
    done

fi

printr "Congratulations! INSTALL FINISHED. open the http://${CURRENT_IP}:7180 to continue...";
exit 0;



