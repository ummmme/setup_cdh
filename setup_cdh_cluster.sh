#!/bin/bash

#Author: kenneth.fang@gaopeng.com
#Version: 1.0.0
#CDH集群自动化安装脚本
#要求：
#1. 同目录下要有集群ip清单文件
#2. 同目录下要有jdk包，并填写配置
#3. 同目录下有rpm包，parcel包

#集群参数设置
#--------------------------------------------------------------------
#集群机器名前缀
NODE_NAME_PREFIX="cdh";

#集群IP清单文件
CLUSTER_IP_LIST="cluster_list.txt";

#Oracle JDK 1.8
ORACLE_JDK_PACKAGE="jdk-8u172-linux-x64.tar.gz";

#MySQL JDBC Connector
MYSQL_JDBC_DRIVER="mysql-connector-java-5.1.41.tar.gz";

#Cloudera Manager Deamon
CLOUDERA_MANAGER_DEAMON="cloudera-manager-daemons-5.14.3-1.cm5143.p0.4.el7.x86_64.rpm";

#Cloudera Manager Server
CLOUDERA_MANAGER_SERVER="cloudera-manager-server-5.14.3-1.cm5143.p0.4.el7.x86_64.rpm";

#Cloudera Manager Agent
CLOUDERA_MANAGER_AGENT="cloudera-manager-agent-5.14.3-1.cm5143.p0.4.el7.x86_64.rpm";

#CDH 安装包
CDH_PARCEL="CDH-5.14.2-1.cdh5.14.2.p0.3-el7.parcel";

#CDH sha 文件
CDH_SHA="CDH-5.14.2-1.cdh5.14.2.p0.3-el7.parcel.sha1";

#CDH manifest.json
CDH_MANIFEST_JSON="manifest.json";

# DO NOT EDIT BELOW CONTENTS：
#--------------------------------------------------------------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CURRENT_DIR=$(pwd);
TMP_DIR="/opt/cdh_cluster_installer";
CUR_DATE=$(date "+%Y%m%d")
mkdir -p ${TMP_DIR};

exitError() {
    echo "Error: $1, exit."; exit 1;
}

yumError() {
    exitError "'yum install' $1 failed.";
}

confBak() {
    /bin/cp -f "$1" "$1.bak-${CUR_DATE}" 2>/dev/null;
}

printr() {
    echo; echo "## $1"; echo;
}

#确认系统参数
ensureVariable() {
    #确认系统版本
    echo "checking system...";
    if ! grep -qs -e "release 7" /etc/redhat-release; then
      exitError "This script only supports CentOS/RHEL 7.x";
    fi

    #确认master的IP为本机
    echo "checking ip...";
    masterIp=$(head -n 1 ${CLUSTER_IP_LIST});
    curIp=$(/sbin/ifconfig -a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | tr -d "addr:");

    if [ ${curIp} != ${masterIp} ]; then
      exitError "Script must be run in master machine. try run this script on ${masterIp}";
    fi

    #确认用户为root
    echo "checking user...";
    if [ "$(id -u)" != 0 ]; then
      exitError "Script must be run as root. Try 'sudo sh $0'";
    fi

    #检查Java 安装包
    echo "checking java...";
    if [ ! -f ${CURRENT_DIR}/${ORACLE_JDK_PACKAGE} ]; then
        exitError "Script can not found the jdk package. Try place it alongside the script";
    fi

    #检查MySQL JDBC 安装包
    echo "checking mysql jdbc...";
    if [ ! -f ${CURRENT_DIR}/${MYSQL_JDBC_DRIVER} ]; then
        exitError "Script can not find the MySQL JDBC Connector package. Try place it alongside the script";
    fi

    #检查CDH安装rmp包
    echo "checking rpms...";
    if [ ! -f ${CURRENT_DIR}/${CLOUDERA_MANAGER_DEAMON} ]; then
        exitError "Script can not found the Cloudera Manager Deamon package. Try place it alongside the script";
    fi
    if [ ! -f ${CURRENT_DIR}/${CLOUDERA_MANAGER_SERVER} ]; then
        exitError "Script can not found the Cloudera Manager Server package. Try place it alongside the script";
    fi
    if [ ! -f ${CURRENT_DIR}/${CLOUDERA_MANAGER_AGENT} ]; then
        exitError "Script can not found the Cloudera Manager Agent package. Try place it alongside the script";
    fi

    #检查CDH 安装parcel包
    if [ ! -f ${CURRENT_DIR}/${CDH_PARCEL} ]; then
        exitError "Script can not found the ${CDH_PARCEL} package. Try place it alongside the script";
    fi
    if [ ! -f ${CURRENT_DIR}/${CDH_SHA} ]; then
        exitError "Script can not found the ${CDH_SHA} package. Try place it alongside the script";
    fi
    if [ ! -f ${CURRENT_DIR}/${CDH_MANIFEST_JSON} ]; then
        exitError "Script can not found the ${CDH_MANIFEST_JSON} package. Try place it alongside the script";
    fi

    #检查安装遗留： TODO
    ##MySQL DB


}


#设置集群节点机器名
getHostnameList() {
    echo -e "\n#init from setup_cdh_cluster.sh ${CUR_DATE}"
    nodeIndex=0;
    cat ${CURRENT_DIR}/${CLUSTER_IP_LIST} | \
    while
        read serverIp;
    do
        nodeIndex=`expr ${nodeIndex} + 1`;
        echo "${serverIp}  ${NODE_NAME_PREFIX}${nodeIndex}";
    done
}


#设置master
setUpMaster() {

#设置别名
printr "Setting up hostname...";
cat ${TMP_DIR}/hosts >> /etc/hosts;
echo "$1" > /etc/hostname && hostname "$1";

#设置开机重新source profile
echo -e "cat ${TMP_DIR}/hosts >> /etc/hosts" >> /etc/rc.local;

#生成密钥
printr "Gennerating ssh rsa key...";
if [ -f /root/.ssh/id_rsa ]; then
            rm -f /root/.ssh/id_rsa;
        fi
if [ -f /root/.ssh/id_rsa.pub ]; then
    rm -f /root/.ssh/id_rsa.pub;
fi

ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa;
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys;
chmod 600 /root/.ssh/authorized_keys;

#关闭防火墙(所有节点)
printr "Shutting down firewall...";
#systemctl stop firewalld
#systemctl disable firewalld

#设置源(所有节点)
printr "Setting up yum repo...";
curl -o /etc/yum.repos.d/cloudera-manager.repo https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/cloudera-manager.repo
curl -o /etc/yum.repos.d/cloudera-cdh5.repo https://archive.cloudera.com/cdh5/redhat/7/x86_64/cdh/cloudera-cdh5.repo

#安装Java(所有节点)
printr "Installing ORACLE JDK...";
if ! rpm -qa | grep java; then
    rpm -qa | grep java | rpm -e --nodeps
fi

if [ ! -d /usr/java ]; then
    mkdir -p /usr/java || exitError "create java folder fail";
fi
jdkFolder=$(tar zxvf ${CURRENT_DIR}/${ORACLE_JDK_PACKAGE} -C /usr/java | tail -n 1 | awk -F '/' '{print $1}')
confBak "/etc/profile"

#删除旧版本JAVA HOME 变量
if grep -qe 'JAVA_HOME' /etc/profile; then
    sed -i '/\$JAVA_HOME/d' /etc/profile;
    sed -i '/JAVA_HOME/d' /etc/profile;
fi
if grep -qe 'JRE_HOME' /etc/profile; then
    sed -i '/JRE_HOME/d' /etc/profile;
fi

#设置Java环境变量(所有节点)
echo -e "
export JAVA_HOME=/usr/java/${jdkFolder}
export JRE_HOME=/usr/java/${jdkFolder}/jre
export PATH=\$PATH:\$JAVA_HOME/bin:\$JRE_HOME/bin
" >> /etc/profile

if [ -e /usr/bin/java ]; then
    rm /usr/bin/java;
fi
ln -s /usr/java/${jdkFolder}/bin/java /usr/bin/java

#设置开机自动启用环境变量
echo -e "\n#init from setup_cdh_cluster.sh ${CUR_DATE}. \nsource /etc/profile" >> /etc/rc.local
source /etc/profile;

#设置SELinux(所有节点)
printr "Setting up SELinux...";
if grep -qe 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
fi
if grep -qe 'SELINUX=permissive' /etc/selinux/config; then
    sed -i "s/SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
fi

#CDH 配置(所有节点)
printr "Setting up CDH configuration...";
echo 10 > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled

#安装Mysql(仅master)
if ! rpm -qa | grep mysql; then
    printr "Service mysqld NOT FOUND, prepare installing...";
    cd ${TMP_DIR} || exit 1;
    wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
    yum -y update  || yumError "mysql";
    yum -y install mysql-server
    service mysqld start
else
    printr "Service mysqld FOUNDED. jump to next step...";
fi

cat <<'EOF'
In case the script hangs here for more than a few minutes,
press Ctrl-C to abort. Then re-run it.
EOF

#配置MySQL(Master)
printr "Configurating MySQL...";
rm -f /var/lib/mysql/ib_logfile0
rm -f /var/lib/mysql/ib_logfile1

confBak "/etc/my.cnf"

cat > /etc/my.cnf <<EOF

[mysqld]
transaction-isolation = READ-COMMITTED
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links = 0
key_buffer_size = 32M
max_allowed_packet = 32M
thread_stack = 256K
thread_cache_size = 64
query_cache_limit = 8M
query_cache_size = 64M
query_cache_type = 1
max_connections = 550
#expire_logs_days = 10
#max_binlog_size = 100M
#log_bin should be on a disk with enough free space. Replace '/var/lib/mysql/mysql_binary_log' with an appropriate path for your system
#and chown the specified folder to the mysql user.
log_bin=/var/lib/mysql/mysql_binary_log
# For MySQL version 5.1.8 or later. For older versions, reference MySQL documentation for configuration help.
binlog_format = mixed
read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M
# InnoDB settings
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit  = 2
innodb_log_buffer_size = 64M
innodb_buffer_pool_size = 4G
innodb_thread_concurrency = 8
innodb_flush_method = O_DIRECT
innodb_log_file_size = 512M
[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
sql_mode=STRICT_ALL_TABLES
EOF

#安装MySQL JDBC Driver(全部节点)
if [ ! -f /usr/share/java/mysql-connector-java.jar ]; then

printr "Installing MySQL JDBC Driver...";
tar zxvf ${CURRENT_DIR}/${MYSQL_JDBC_DRIVER} -C ${TMP_DIR}/
mkdir -p /usr/share/java || exit 1;
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar \
/usr/share/java/mysql-connector-java.jar

else
printr "MySQL JDBC Driver installed, jump to next step...";
fi

#创建CDH数据库(仅master)
printr "Creating CDH require Components' DBs..."

cat > /opt/cdh_cluster_installer/create_cdh_mysql_db.sql << EOF
DROP DATABASE IF EXISTS scm;
DROP DATABASE IF EXISTS amon;
DROP DATABASE IF EXISTS rman;
DROP DATABASE IF EXISTS hive;
DROP DATABASE IF EXISTS sentry;
DROP DATABASE IF EXISTS nav;
DROP DATABASE IF EXISTS navms;
DROP DATABASE IF EXISTS oozie;
DROP DATABASE IF EXISTS hue;

CREATE DATABASE scm DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON scm.* TO 'scm'@'%' IDENTIFIED BY 'scm_password';

CREATE DATABASE amon DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON amon.* TO 'amon'@'%' IDENTIFIED BY 'amon_password';

CREATE DATABASE rman DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON rman.* TO 'rman'@'%' IDENTIFIED BY 'rman_password';

CREATE DATABASE hive DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON hive.* TO 'hive'@'%' IDENTIFIED BY 'hive_password';

CREATE DATABASE sentry DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON sentry.* TO 'sentry'@'%' IDENTIFIED BY 'sentry_password';

CREATE DATABASE nav DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON nav.* TO 'nav'@'%' IDENTIFIED BY 'nav_password';

CREATE DATABASE navms DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON navms.* TO 'navms'@'%' IDENTIFIED BY 'navms_password';

CREATE DATABASE oozie DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON oozie.* TO 'oozie'@'%' IDENTIFIED BY 'oozie_password';

CREATE DATABASE hue DEFAULT CHARACTER SET utf8;
GRANT ALL PRIVILEGES ON hue.* TO 'hue'@'%' IDENTIFIED BY 'hue_password';

FLUSH PRIVILEGES;
EOF

#开启root 密码
printr "Enabling MySQL root user, please reset the root user password...";
echo -e "
-----------------------------------------------------------------
Please SET OPTIONS LIKE BELOW！ and remember your root password:

Set root password? [Y/n] y
Remove anonymous users? [Y/n] y
Disallow root login remotely? [Y/n] n
Remove test database and access to it? [Y/n] y
Reload privilege tables now? [Y/n] y

Press ENTER to continue while you are ready...
-----------------------------------------------------------------
";

read input

/usr/bin/mysql_secure_installation

#初始化CDH数据库
printr "ENTER THE ROOT PASSWORD to Creating cdh databases, ...";
mysql -u root -e "source /opt/cdh_cluster_installer/create_cdh_mysql_db.sql" -p

#开始安装Cloudera Manager Deamon/Server/Agent RPM 包
printr "Installing Cloudera Manager Deamon/Server/Agent...";
cd ${CURRENT_DIR} || exit 1;

if ! rpm -qa | grep cloudera-manager-daemons; then
    yum -y install ${CLOUDERA_MANAGER_DEAMON} --nogpgcheck
else
    echo "cloudera-manager-daemons package installed.";
fi
if ! rpm -qa | grep cloudera-manager-server; then
    yum -y install ${CLOUDERA_MANAGER_SERVER} --nogpgcheck
else
    echo "cloudera-manager-server package installed.";
fi
if ! rpm -qa | grep cloudera-manager-agent; then
    yum -y install ${CLOUDERA_MANAGER_AGENT} --nogpgcheck
else
    echo "cloudera-manager-agent package installed.";
fi

#初始化Cloudera Manager 数据库
printr "Initing Cloudera Manager Database...";
/usr/share/cmf/schema/scm_prepare_database.sh mysql scm scm scm_password

#复制parcel包和sha1, manifest.json 文件到parcel文件夹
printr "Preparing parcels for CDH installer...";
cp ${CURRENT_DIR}/${CDH_PARCEL} /opt/cloudera/parcel-repo/
cp ${CURRENT_DIR}/${CDH_SHA} /opt/cloudera/parcel-repo/${CDH_SHA%%1}    #非常重要：将.sha1重命名为.sha文件
cp ${CURRENT_DIR}/${CDH_MANIFEST_JSON} /opt/cloudera/parcel-repo/

cd /opt/cloudera/parcel-repo || exit 1;
chown cloudera-scm:cloudera-scm ./*

printr "congratulations: Master setup finished";

#启动
printr "Starting Cloudera, please wait...";
service cloudera-scm-server start
service cloudera-scm-agent start
}


#配置从服务器: $hostName, $serverIp
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
printr "copying host file to temp dir...";
scp -o StrictHostKeyChecking=no ${TMP_DIR}/hosts root@$1:${TMP_DIR}/hosts > /dev/null 2>&1

#复制rpm包 到slave的 临时目录
printr "copying rpm packages to temp dir...";
#scp -o StrictHostKeyChecking=no ${CURRENT_DIR}/${CLOUDERA_MANAGER_DEAMON} root@$1:${TMP_DIR}/ > /dev/null 2>&1
#scp -o StrictHostKeyChecking=no ${CURRENT_DIR}/${CLOUDERA_MANAGER_AGENT} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制Java
printr "copying oracle jdk packages to temp dir...";
scp -o StrictHostKeyChecking=no ${CURRENT_DIR}/${ORACLE_JDK_PACKAGE} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制MySQL JDBC
printr "copying mysql jdbc drivers to temp dir...";
scp -o StrictHostKeyChecking=no ${CURRENT_DIR}/${MYSQL_JDBC_DRIVER} root@$1:${TMP_DIR}/ > /dev/null 2>&1

#复制repo仓库
printr "copying repo files...";
scp -o StrictHostKeyChecking=no /etc/yum.repos.d/cloudera-*.repo root@$1:${TMP_DIR}/

#生成远程执行脚本并复制到slave的临时目录
cd ${CURRENT_DIR} || exit 1;
cat > build_slave.sh << EOF

#设置别名
cd ${TMP_DIR} || exit 1;
cat ${TMP_DIR}/hosts >> /etc/hosts;
echo $1 > /etc/hostname && hostname $1;
echo -e "cat ${TMP_DIR}/hosts >> /etc/hosts" >> /etc/rc.local;

#关闭防火墙(所有节点)
echo -e "\n##Shutting down firewall...";
#systemctl stop firewalld
#systemctl disable firewalld

#设置源(所有节点)
echo -e "\n##Setting up yum repo...";
cp ${TMP_DIR}/cloudera-*.repo /etc/yum.repos.d/

#安装Java(所有节点)
echo -e "\n##Installing ORACLE JDK...";
if ! rpm -qa | grep java; then
    rpm -qa | grep java | xargs rpm -e --nodeps
fi
if [ ! -d /usr/java ]; then
    mkdir -p /usr/java || exit 1;
fi
#解压
tar zxvf ${TMP_DIR}/${ORACLE_JDK_PACKAGE} -C /usr/java
jdkFolder=$(tar zxvf ${ORACLE_JDK_PACKAGE} -C /tmp | tail -n 1 | awk -F '/' '{print $1}');
confBak "/etc/profile"  #TODO： 没有confBak函数

#删除旧版本JAVA HOME 变量
if grep -qe 'JAVA_HOME' /etc/profile; then
    sed -i '/\$JAVA_HOME/d' /etc/profile;
    sed -i '/JAVA_HOME/d' /etc/profile;
fi
if grep -qe 'JRE_HOME' /etc/profile; then
    sed -i '/JRE_HOME/d' /etc/profile;
fi

#设置Java环境变量(所有节点)
echo -e "
export JAVA_HOME=/usr/java/\${jdkFolder}
export JRE_HOME=/usr/java/\${jdkFolder}/jre
export PATH=\$PATH:\$JAVA_HOME/bin:\$JRE_HOME/bin
" >> /etc/profile

if [ -e /usr/bin/java ]; then
    rm /usr/bin/java;
fi
ln -s /usr/java/\${jdkFolder}/bin/java /usr/bin/java

#设置开机自动启用环境变量
echo -e "\n#init from setup_cdh_cluster.sh ${CUR_DATE}. \nsource /etc/profile" >> /etc/rc.local
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
echo 10 > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled

#安装MySQL JDBC Driver(所有节点)
if [ ! -f /usr/share/java/mysql-connector-java.jar ]; then

echo -e "\n##Installing MySQL JDBC Driver...";
tar zxvf ${TMP_DIR}/${MYSQL_JDBC_DRIVER} -C ${TMP_DIR}/
mkdir -p /usr/share/java || exit 1;
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar \
/usr/share/java/mysql-connector-java.jar

else
echo -e "\n##MySQL JDBC Driver installed, jump to next step...";
fi

#安装rpm包
echo -e "\n##installing rpms...";

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

#配置Master的机器名
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

#--------------------------------------------------------------------
#检查环境
ensureVariable;

#生成集群机器名映射清单
getHostnameList > ${TMP_DIR}/hosts;

#开始配置
nodeIndex=0;
for serverIp in `cat ${CURRENT_DIR}/${CLUSTER_IP_LIST}`
do
    nodeIndex=`expr ${nodeIndex} + 1`;
    hostName="${NODE_NAME_PREFIX}${nodeIndex}";
    printr "server: ${serverIp} initing. hostname is ${hostName}";

    if [ $(ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:") == ${serverIp} ];
    then
        setUpMaster ${hostName};
    else
        setUpSlave ${hostName} ${serverIp};
    fi
done

printr "All Steps finished. open the master's ip:7180 to continue...";

exit 1;




























