# Cloudera CDH集群离线安装脚本

## 更新记录
- [2019-11-18] 增加CDH5.16.2的支持
- [2018-10-10] 增加CDH5.15.1的支持 
- [2019-04-25] 新增计算节点安装脚本


## 快速开始
*关于其他语言版本的手册: [English](README-en.md), [简体中文](README.md).*

1. 准备数台全新安装的Linux Redhat7/CentOS7.x的服务器

2. 克隆本项目
    ```bash
    git clone https://github.com/abcfyk/setup_cdh.git
    ```
3. 分别下载两个安装文件并放置在本项目的packages目录下(体积较大，可选择第三方下载工具)：
    ```bash
    wget -P setup_cdh/packages https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.16.2/RPMS/x86_64/cloudera-manager-daemons-5.16.2-1.cm5162.p0.7.el7.x86_64.rpm
    wget -P setup_cdh/packages http://archive.cloudera.com/cdh5/parcels/latest/CDH-5.16.2-1.cdh5.16.2.p0.8-el7.parcel 
    ```
4. 下载Cloudera 为CDH6.x 提供的ORACLE JDK1.8
    ```bash
    wget -P setup_cdh/packages https://archive.cloudera.com/cm6/6.3.1/redhat7/yum/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update181-1.x86_64.rpm
    ```
5. 编辑根目录下的ip.list文件，填写集群节点的内网地址，每行一个

6. 上传本项目到集群任意一台服务器(建议在ip.list文件中的第一台服务器)，准备安装

7. 使用**ROOT**用户执行安装命令(非全自动安装，安装过程中会要求配置MySQL和输入集群其他服务器的root密码)
   ```bash
   cd setup_cdh && sh setup_cdh5.sh
   ```

## 参考


