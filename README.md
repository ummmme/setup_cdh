# Cloudera CDH集群离线安装脚本

## 更新记录
- [2018-10-10] 增加CDH5.15.1的支持 


## 快速开始
*关于其他语言版本的手册: [English](README-en.md), [简体中文](README.md).*

1. 准备数台全新安装的Linux Redhat7/CentOS7.x的服务器

2. 克隆本项目
    ```bash
    git clone https://github.com/abcfyk/setup_cdh.git
    ```
3. 分别下载两个安装文件并放置在本项目的packages目录下：
    ```bash
    wget -P setup_cdh/packages http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.15.1/RPMS/x86_64/cloudera-manager-daemons-5.15.1-1.cm5151.p0.3.el7.x86_64.rpm
    wget -P setup_cdh/packages http://archive.cloudera.com/cdh5/parcels/latest/CDH-5.15.1-1.cdh5.15.1.p0.4-el7.parcel 
    ```
4. 编辑根目录下的ip.list文件，填写集群节点的内网地址，每行一个
5. 上传本项目到集群任意一台服务器(建议在ip.list文件中的第一台服务器)，准备安装
6. 使用**ROOT**用户执行安装命令(安装过程中会要求输入集群其他服务器的root密码)
    ```bash
    sudo sh setup_cdh5.sh
    ```


## TODO
1. fix the /etc/profile repeat issue
2. fix the /etc/rc.local repeat issue
3. fix the /root/.ssh/authorized_keys repeat issue