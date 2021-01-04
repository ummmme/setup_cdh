# CDH5集群离线安装手册

## 快速开始
1. 准备数台全新安装的Linux Redhat7/CentOS7.x的服务器
    
2. 克隆本项目
    ```bash
    git clone https://github.com/abcfyk/setup_cdh.git
    ```
3. 分别下载三个安装文件并放置在本项目的packages目录下(体积较大，可选择第三方下载工具)：
    ```bash
    https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.16.2/RPMS/x86_64/cloudera-manager-agent-5.16.2-1.cm5162.p0.7.el7.x86_64.rpm
    https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.16.2/RPMS/x86_64/cloudera-manager-daemons-5.16.2-1.cm5162.p0.7.el7.x86_64.rpm
    http://archive.cloudera.com/cdh5/parcels/5.16.2/CDH-5.16.2-1.cdh5.16.2.p0.8-el7.parcel 
    ```
4. 下载ORACLE JDK 1.8(只支持64bit版本，最低支持8u74，建议为8u181)
    ```bash
    wget -P setup_cdh/packages http://download.oracle.com/otn-pub/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-linux-x64.tar.gz
    ```
5. 编辑根目录下的ip.list文件，填写集群节点的内网地址，每行一个

6. 上传本项目到集群任意一台服务器(建议在ip.list文件中的第一台服务器)，准备安装

7. 使用**ROOT**用户执行安装命令(非全自动安装，安装过程中会要求配置MySQL和输入集群其他服务器的root密码)
   ```bash
   cd setup_cdh && sh setup_cdh5.sh
   ```
8. 完成安装，打开浏览器登录集群进行配置   
   
   
  
## 完整安装手册
略













