# CDH5集成Spark2.4.0手册

## Quick Start

1. 准备安装文件（下文以CDH5.16.2 集成 Spark2.4.0版本为例）

- 下载csd文件（注意下载对应版本的文件）： [下载地址](http://archive.cloudera.com/spark2/csd/)
- 下载parcel包, sha文件和manifest.json文件（注意下载对应版本的文件）：[下载地址](http://archive.cloudera.com/spark2/parcels/2.4.0.cloudera2/)

```bash
wget  http://archive.cloudera.com/spark2/csd/SPARK2_ON_YARN-2.4.0.cloudera2.jar
wget http://archive.cloudera.com/spark2/parcels/2.4.0.cloudera2/SPARK2-2.4.0.cloudera2-1.cdh5.13.3.p0.1041012-el7.parcel
wget -O SPARK2-2.4.0.cloudera2-1.cdh5.13.3.p0.1041012-el7.parcel.sha http://archive.cloudera.com/spark2/parcels/2.4.0.cloudera2/SPARK2-2.4.0.cloudera2-1.cdh5.13.3.p0.1041012-el7.parcel.sha1
wget http://archive.cloudera.com/spark2/parcels/2.4.0.cloudera2/manifest.json
```

2. 上传到CDH所在服务器（master）的对应目录

```bash
scp SPARK* cdh1:/tmp/
scp manifest.json cdh1:/tmp/
```

3. 备份并复制到安装目录

```bash
cd /tmp
cp /opt/cloudera/parcel-repo/manifest.json /opt/cloudera/parcel-repo/manifest.json.bak
cp manifest.json /opt/cloudera/parcel-repo/
cp SPARK*.parcel* /opt/cloudera/parcel-repo/
cp SPARK*.jar /opt/cloudera/csd/
```

4. 修改文件权限和所有者

```bash
chown cloudera-scm:cloudera-scm /opt/cloudera/csd/*
chown cloudera-scm:cloudera-scm /opt/cloudera/parcel-repo/*
```

5. 在Cloudera Manager中分配安装包并激活

- 打开Cloudera的控制面板， 点击“主机” -> "Parcel" -> "检查新Parcel"
- 然后可以看到“SPARK2” 已经出现在列表内， 状态为“已下载”， 点击“分配”按钮开始分配，
- 分配完成后点击“激活”，并等待提示激活完成
- <font color=red>激活完成后，重启Master 上的 Cloudera Manage Service（必须）</font>

```bash
service cloudera-scm-server restart
service cloudera-scm-agent restart
```

-  回到首页，点击“Cluster1” -> "添加服务"， 将SPARK2 添加到集群

6. 分配角色

- HistoryServer 部署到有公网IP的节点
- 分配Gateway 到 所有节点
- 在Master节点重启scm-server

```bash
service cloudera-scm-server restart
```

7. 安装scala<font color=red>（所有节点）</font>：

- 下载并解压
```bash
cd /usr/local
wget -c -O /opt/scala-2.13.0-M4.tgz https://downloads.lightbend.com/scala/2.13.0-M4/scala-2.13.0-M4.tgz   
tar zxvf /opt/scala-2.13.0-M4.tgz -C /usr/local/
ln -s /usr/local/scala-2.13.0-M4 /usr/local/scala
```

- 向/etc/profile文件添加环境变量：
```bash
cat >> /etc/profile << EOF
#ADD FOR SCALA ENV
export SCALA_HOME=/usr/local/scala
export PATH=\$PATH:\$SCALA_HOME/bin
EOF
source /etc/profile
```

- 测试：
```bash
scala -version
```

8. （建议）脚本方式安装scala
- 将以下内容保存为`/tmp/install_scala.sh`：
```bash
cd /usr/local
wget -c -O /opt/scala-2.13.0-M4.tgz https://downloads.lightbend.com/scala/2.13.0-M4/scala-2.13.0-M4.tgz   
tar zxvf /opt/scala-2.13.0-M4.tgz -C /usr/local/
ln -s /usr/local/scala-2.13.0-M4 /usr/local/scala

cat >> /etc/profile <<PROFILE
#ADD FOR SCALA ENV
export SCALA_HOME=/usr/local/scala
export PATH=\$PATH:\$SCALA_HOME/bin
PROFILE

source /etc/profile
scala -version
```

- 赋执行权限并执行脚本
```bash
chmod +x /tmp/install_scala.sh && sh /tmp/install_scala.sh
```

- 依次复制所有节点执行（假设4节点）
```bash
for i in `seq 1 4`; do
    scp /tmp/install_scala.sh cdh-test${i}:/tmp/
    ssh -t -o StrictHostKeyChecking=no root@cdh-test${i} "/tmp/install_scala.sh";
done
```
