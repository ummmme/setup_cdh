# Cloudera CDH集群自动安装脚本

## 快速开始
*关于其他语言版本的手册: [English](README.md), [简体中文](README-zh.md).*

1. 准备数台全新安装的Linux Redhat7/CentOS7.x的服务器
2. 下载好必要的驱动包
    - Cloudera Manager: [点击此处下载](http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.15.0/RPMS/x86_64/)
    - CDH: [点击此处下载](http://archive.cloudera.com/cdh5/parcels/latest/)
    - ORACLE JDK:
    - MySQL JDCB Driver: 
3. 准备好集群服务器的ip清单，放置在此脚本同目录
4. 打开setup_cdh_cluster.sh, 编辑*集群参数设置*的内容
5. 执行命令(安装过程中会要求输入集群其他服务器的root密码): 
```bash
sudo sh setup_cdh_cluster.sh
```

## 离线安装包所需清单
1. ORACLE JDK： 
2. MySQL JDBC Driver
3. Cloudera Manager的rpm包
4. CDH的安装包 


## Todo
1. fix the /etc/profile repeat issue
2. fix the /etc/rc.local repeat issue
3. fix the /root/.ssh/authorized_keys repeat issue