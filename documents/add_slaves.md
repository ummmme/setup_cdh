#CDH5.16.2集群追加节点手册

## 快速开始
### 1. 准备工作
- 确保已经使用本项目成功安装CDH5集群
- 检查本项目所在的服务器已经可以免密登录要追加到集群的节点（以下简称新节点），
如果尚未处理SSH免密登录的问题，请参考使用以下命令
```bash
sudo ssh-copy-id -i /root/.ssh/id_rsa.pub root@xxx.xxx.xxx.xxx
```
或者手动将本项目所在的服务器的公钥内容 追加到新节点的`/root/.ssh/authorized_keys`中
- 检查`/opt/setup_cdh_installer`目录下是否存在`hosts`文件，并且hosts文件已包含当前集群的所有节点

### 2. 开始追加节点
- 编辑本项目的add_slaves.sh文件，将要追加的节点IP， 以逗号分隔填入NODE_IP_LIST变量中
- 使用**ROOT**用户执行安装命令（全自动安装，无需值守）
```bash
sh add_slaves.sh
```
- 完成安装，打开浏览器登录集群，在【主机】选项卡下，点击【向群集添加新主机】进行后续操作

### 3. 已知bug
- 新节点的IP与hostname 不会追加到集群旧节点上，需要手动新增，待修复   