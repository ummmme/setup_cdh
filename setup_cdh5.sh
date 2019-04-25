#!/usr/bin/env bash
#Author: kenneth.fang@gaopeng.com
#Version: 1.1.0
#CDH集群离线安装脚本, 适用于Redhat/CentOS 7.x 64位版本

#集群机器名前缀, 可自定义
NODE_NAME_PREFIX="bigdata-cdh";

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

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";

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
    if [ "$(id -u)" != 0 ]; then
      exitError "Script must run as root. Try 'sudo sh $0'";
    fi

    #检查master
    if [ $(head -n 1 ip.list) != ${CURRENT_IP} ]; then
        exitError "Script must run on $(head -n 1 ip.list)";
    fi

    #检查是否为项目根目录
    echo "CHECK DIRECTORY...";
    if [ $(pwd | awk -F '/' '{print $NF}') != ${PROJECT_NAME} ]; then
        exitError "Script must run at ROOT directory";
    fi

    #检查ORACLE JDK, 如果有其他版本的JDK，则继续安装
    echo "CHECK Oracle JDK...";
    if [ ! -f ${PACKAGES_PATH}/${ORACLE_JDK_PACKAGE} ]; then
        if [ -f ${PACKAGES_PATH}/jdk-8u*.tar.gz ]; then
            ORACLE_JDK_PACKAGE=$(ls ${PACKAGES_PATH}/jdk-8u*.tar.gz | awk -F '/' '{print $NF}');
        else
            exitError "Oracle JDK NOT FOUND";
        fi
    fi

    #检查MySQL JDBC 安装包
    echo "CHECK MySQL Connector...";
    if [ ! -f ${PACKAGES_PATH}/${MYSQL_JDBC_DRIVER} ]; then
        exitError "MySQL Connector NOT FOUND";
    fi

    #检查cloudera manager rpm包
    echo "CHECK Cloudera Manager packages...";
    if [ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_DEAMON} ]; then
        exitError "Cloudera Manager Deamon RPM NOT FOUND";
    fi
    if [ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_SERVER} ]; then
        exitError "Cloudera Manager Server RPM NOT FOUND";
    fi
    if [ ! -f ${PACKAGES_PATH}/${CLOUDERA_MANAGER_AGENT} ]; then
        exitError "Cloudera Manager Agent RPM NOT FOUND";
    fi

    #检查CDH parcel包
    if [ ! -f ${PACKAGES_PATH}/${CDH_PARCEL} ]; then
        exitError "CDH Parcel FILE NOT FOUND";
    fi
    if [ ! -f ${PACKAGES_PATH}/${CDH_SHA} ]; then
        exitError "CDH SHA FILE NOT FOUND";
    fi
    if [ ! -f ${PACKAGES_PATH}/${CDH_MANIFEST_JSON} ]; then
        exitError "CDH manifest.json FILE NOT FOUND";
    fi

    #检查安装遗留
    echo "CHECK MySQL...";

}

#设置集群节点机器名
getHostnameList() {
    nodeIndex=0;
    for ip in `cat ${PROJECT_PATH}/ip.list`
    do
        nodeIndex=`expr ${nodeIndex} + 1`;
        echo "${ip}  ${NODE_NAME_PREFIX}${nodeIndex}";
    done
}


#设置master
setUpMaster() {

#设置机器名
printr "Setting up hostname...";
cat ${TMP_DIR}/hosts >> /etc/hosts;
echo "$1" > /etc/hostname && hostname "$1";

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
systemctl stop firewalld
systemctl disable firewalld

#设置源(所有节点)
printr "Setting up Cloudera Manager Repository...";
cp ${PACKAGES_PATH}/cloudera-manager.repo /etc/yum.repos.d/
cp ${PACKAGES_PATH}/cloudera-cdh5.repo /etc/yum.repos.d/
rpm --import https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/RPM-GPG-KEY-cloudera
yum -y install htop iotop vim sysstat iftop screen
yum -y update


#安装Java(所有节点)
printr "Installing ORACLE JDK...";
if rpm -qa | grep java; then
    rpm -qa | grep java | rpm -e --nodeps
fi

if [ ! -d /usr/java ]; then
    mkdir -p /usr/java || exitError "create java folder fail";
fi
jdkFolder=$(tar zxvf ${PACKAGES_PATH}/${ORACLE_JDK_PACKAGE} -C /usr/java | tail -n 1 | awk -F '/' '{print $1}')
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
    confBak /usr/bin/java /usr/bin/java.bak-${CUR_DATE};
fi
ln -s /usr/java/${jdkFolder}/bin/java /usr/bin/java

#设置开机自动启用环境变量
echo -e "source /etc/profile" >> /etc/rc.local
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

echo -e "
echo 10 > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled
" >> /etc/rc.local

#安装Mysql(仅master)
if ! rpm -qa | grep mysql; then
    printr "Service mysqld NOT FOUND, prepare installing...";
    wget -P ${TMP_DIR}/ http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
    sudo rpm -ivh ${TMP_DIR}/mysql-community-release-el7-5.noarch.rpm
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

printr "Restarting MySQL Server...";
service mysqld restart > /dev/null 2>&1

#安装MySQL JDBC Driver(全部节点) TODO
if [ ! -f /usr/share/java/mysql-connector-java.jar ]; then

printr "Installing MySQL JDBC Driver...";
tar zxvf "${PACKAGES_PATH}/${MYSQL_JDBC_DRIVER}" -C "${TMP_DIR}/"
mkdir -p /usr/share/java || exitError "CREATE MySQL FOLDER FAILED";
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar /usr/share/java/mysql-connector-java.jar

else
printr "MySQL JDBC Driver installed, jump to next step...";
fi

#创建CDH数据库(仅master)
printr "Creating CDH require Components' DBs..."

cat > ${TMP_DIR}/create_cdh_mysql_db.sql << EOF
DROP DATABASE IF EXISTS scm;
DROP DATABASE IF EXISTS amon;
DROP DATABASE IF EXISTS rman;
DROP DATABASE IF EXISTS hive;
DROP DATABASE IF EXISTS sentry;
DROP DATABASE IF EXISTS nav;
DROP DATABASE IF EXISTS navms;
DROP DATABASE IF EXISTS oozie;
DROP DATABASE IF EXISTS hue;

CREATE DATABASE scm DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON scm.* TO 'scm'@'%' IDENTIFIED BY 'scm_password';

CREATE DATABASE amon DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON amon.* TO 'amon'@'%' IDENTIFIED BY 'amon_password';

CREATE DATABASE rman DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON rman.* TO 'rman'@'%' IDENTIFIED BY 'rman_password';

CREATE DATABASE hive DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON hive.* TO 'hive'@'%' IDENTIFIED BY 'hive_password';

CREATE DATABASE sentry DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON sentry.* TO 'sentry'@'%' IDENTIFIED BY 'sentry_password';

CREATE DATABASE nav DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON nav.* TO 'nav'@'%' IDENTIFIED BY 'nav_password';

CREATE DATABASE navms DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON navms.* TO 'navms'@'%' IDENTIFIED BY 'navms_password';

CREATE DATABASE oozie DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON oozie.* TO 'oozie'@'%' IDENTIFIED BY 'oozie_password';

CREATE DATABASE hue DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON hue.* TO 'hue'@'%' IDENTIFIED BY 'hue_password';

FLUSH PRIVILEGES;
EOF

#开启MySQL root 密码
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
printr "ENTER THE ROOT PASSWORD YOU JUST SET UP to create the cdh databases, ...";
mysql -u root -e "source ${TMP_DIR}/create_cdh_mysql_db.sql" -p

#开始安装Cloudera Manager Deamon/Server/Agent RPM 包
printr "Installing Cloudera Manager Deamon/Server/Agent...";

if ! rpm -qa | grep cloudera-manager-daemons; then
    yum -y install ${PACKAGES_PATH}/${CLOUDERA_MANAGER_DEAMON} --nogpgcheck
else
    echo "cloudera-manager-daemons package installed.";
fi
if ! rpm -qa | grep cloudera-manager-server; then
    yum -y install ${PACKAGES_PATH}/${CLOUDERA_MANAGER_SERVER} --nogpgcheck
else
    echo "cloudera-manager-server package installed.";
fi
if ! rpm -qa | grep cloudera-manager-agent; then
    yum -y install ${PACKAGES_PATH}/${CLOUDERA_MANAGER_AGENT} --nogpgcheck
else
    echo "cloudera-manager-agent package installed.";
fi

#初始化Cloudera Manager 数据库
printr "Initing Cloudera Manager Database...";
/usr/share/cmf/schema/scm_prepare_database.sh mysql scm scm scm_password

#复制parcel包和sha, manifest.json 文件到parcel文件夹
printr "Preparing parcels for CDH installer...";
cp ${PACKAGES_PATH}/${CDH_PARCEL} /opt/cloudera/parcel-repo/
cp ${PACKAGES_PATH}/${CDH_SHA} /opt/cloudera/parcel-repo/    #非常重要：将.sha1重命名为.sha文件
cp ${PACKAGES_PATH}/${CDH_MANIFEST_JSON} /opt/cloudera/parcel-repo/
chown -R cloudera-scm:cloudera-scm /opt/cloudera/parcel-repo/*

#删除原集群的guid
if [ -e /var/lib/cloudera-scm-agent/cm_guid ]; then
    rm -f /var/lib/cloudera-scm-agent/cm_guid;
fi
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
jdkFolder=\$(echo \$output | tail -n 1 | awk -F '/' '{print $1}');
/bin/cp -f /etc/profile /etc/profile.old;

#删除旧版本JAVA HOME 变量
if grep -qe 'JAVA_HOME' /etc/profile; then
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
echo 10 > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled

echo -e "
echo 10 > /proc/sys/vm/swappiness
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo never > /sys/kernel/mm/transparent_hugepage/enabled
" >> /etc/rc.local

#安装MySQL JDBC Driver(所有节点)
if [ ! -f /usr/share/java/mysql-connector-java.jar ]; then

echo -e "\n##Installing MySQL JDBC Driver...";
tar zxvf ${TMP_DIR}/${MYSQL_JDBC_DRIVER} -C ${TMP_DIR} > /dev/null 2>&1;
mkdir -p /usr/share/java || exit 1;
cp ${TMP_DIR}/mysql-connector-java-*/mysql-connector-java-*-bin.jar \
/usr/share/java/mysql-connector-java.jar

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

#--------------------------------------------------------------------
#检查环境 OK
ensureVariable;

#生成集群机器名映射清单
getHostnameList > ${TMP_DIR}/hosts;

#开始安装
nodeIndex=0;
for serverIp in `cat ${PROJECT_PATH}/ip.list`
do
    printr "deploying ${serverIp}...";
    nodeIndex=`expr ${nodeIndex} + 1`;
    hostName="${NODE_NAME_PREFIX}${nodeIndex}";

    if [ ${CURRENT_IP} == ${serverIp} ];
    then
        setUpMaster ${hostName};
    else
        setUpSlave ${hostName};
    fi
done

printr "Congratulations! INSTALL FINISHED. open the http://${CURRENT_IP}:7180 to continue...";
exit 1;
