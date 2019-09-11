#!/usr/bin/env bash
#Author: kenneth.fang@gaopeng.com
#Version: 1.0.0
#CDH集群ClouderaManager组件迁移脚本, 适用于 旧节点资源不足，需要迁移ClouderaManager 服务到新节点的场景
#执行方式： 填写新节点的内网IP， 并在主节点上执行本脚本( 注意：目标服务器上不可安装过CDH，否则无法迁移)

#新节点的IP
MIGRATE_TO_IP="10.0.12.21"
MIGRATE_TO_HOSTNAME="bigdata-cdh12"

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
    echo "[ERROR]: $1, exit"; exit 1;
}

yumError() {
    exitError "[ERROR]: 'yum install' $1 failed. exit";
}

confBak() {
    /bin/cp -f "$1" "$1.bak.${CUR_DATE}" 2>/dev/null;
}

printr() {
    echo;
    echo "##------------------------------------------------------------------------------------------------------- "
    echo "##$1";
    echo "##------------------------------------------------------------------------------------------------------- "
}

#确认系统版本
checkSystem() {
    printr "CHECK SYSTEM Version...";
    if ! grep -qs -e "release 7" /etc/redhat-release; then
      exitError "Script only supports CentOS/RHEL 7.x";
    fi
}

#确认用户为root
checkUser()   {
    printr "CHECK ROOT USER...";
    if [[ "$(id -u)" != 0 ]]; then
      exitError "Script must run as root. Try 'sudo sh $0'";
    fi
}

#检查是否为项目根目录
checkPath() {
    printr "CHECK DIRECTORY...";
    if [[ $(pwd | awk -F '/' '{print $NF}') != ${PROJECT_NAME} ]]; then
        exitError "Script must run at ROOT directory";
    fi
}

#检查ORACLE JDK, 如果有其他版本的JDK，则继续安装
checkJdk() {
    printr "CHECK Oracle JDK...";
    if [[ ! -f ${PACKAGES_PATH}/${ORACLE_JDK_PACKAGE} ]]; then
        if [[ -f ${PACKAGES_PATH}/jdk-8u*.tar.gz ]]; then
            ORACLE_JDK_PACKAGE=$(ls ${PACKAGES_PATH}/jdk-8u*.tar.gz | awk -F '/' '{print $NF}');
        else
            exitError "Oracle JDK NOT FOUND";
        fi
    fi
}

#检查MySQL JDBC 安装包
checkJdbc() {
    printr "CHECK MySQL Connector...";
    if [[ ! -f ${PACKAGES_PATH}/${MYSQL_JDBC_DRIVER} ]]; then
        exitError "MySQL Connector NOT FOUND";
    fi
}

#检查cloudera manager rpm包
checkClouderaRpm() {
    printr "CHECK Cloudera Manager packages...";
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_DEAMON} ]]; then
        exitError "Cloudera Manager Deamon RPM NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_SERVER} ]]; then
        exitError "Cloudera Manager Server RPM NOT FOUND";
    fi
    if [[ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_AGENT} ]]; then
        exitError "Cloudera Manager Agent RPM NOT FOUND";
    fi
}

#确认环境变量
checkVariables() {
    checkSystem;

    checkUser;

    checkPath;

    checkJdk;

    checkJdbc;

    checkClouderaRpm;

}

#复制密钥
copyKeys() {
printr "copying rsa keys...";
scp -o StrictHostKeyChecking=no -r /root/.ssh root@${MIGRATE_TO_IP}:/root/
}

#创建slave上的临时目录
copyTmpDir() {
printr "creating temp dir in $1...";
ssh -t -o StrictHostKeyChecking=no root@${MIGRATE_TO_IP} > /dev/null 2>&1 << EOF
mkdir -p ${TMP_DIR};
EOF
}


#配置 新节点上的 环境变量
setupEnv()  {

    copyKeys;

    copyTmpDir;

    #复制hosts文件
printr "copying host file to temp dir in $1...";
scp -o StrictHostKeyChecking=no ${TMP_DIR}/hosts root@$1:${TMP_DIR}/hosts > /dev/null 2>&1

}




run() {
    #1.
    checkVariables;

    #2.配置新节点上的系统环境
    setupEnv;

}

run;