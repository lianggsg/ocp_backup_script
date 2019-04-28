# ocp_backup_script
以xxx:/backup 作为NFS用于存放备份数据为例，将备份NFS挂载到所有服务上(xxx 为NFS IP地址)。
在所有服务器上操作。创建备份目录
# mkdir /backup
添加自动挂载目录
# vi /etc/fstab
……
XXX:/backup:/ /backup  nfs defaults,_netdev 0 0
# mount -a
将备份脚本放入第一台服务器(XXX)的/backup目录中。(备份脚本见附录节点)
在第一台服务器上创建如下周期性任务：
# crontab -e
30 1 * * * timeout 5h bash /backup/backup-scripts/images-and-devops-backup.sh &> /dev/null

0 1 * * * timeout 20m ansible -m script -a "/backup/backup-scripts/ocp-backup.sh" nodes &> /dev/null
在第一台master(XXX)节点创建如下周期性任务：
# crontab -e
25 1 * * * timeout 5m bash /backup/backup-scripts/etcd-bakcup.sh &> /dev/null

备份脚本在生产中运行除了需要完成上述配置外，还需要修改如下两个参数：
	如果没有部署DevOps工具，需要将脚本images-and-devops-backup.sh中的参数devops_backup设置为false。
