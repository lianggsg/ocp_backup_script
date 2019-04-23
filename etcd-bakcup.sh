#!/bin/bash
set -eo pipefail
export ETCDCTL_API=3

dest_root_path=/backup/etcd-data-backup

backup_data_dir=$dest_root_path/backup-etcd-data-$(date '+%Y-%m-%d')
backup_config_dir=$dest_root_path/backup-etcd-config-$(date '+%Y-%m-%d')/
backup_log_file=$dest_root_path/etcd-backup.log

etcd_cert="--endpoints=https://10.1.31.20:2379 --cacert=/etc/origin/master/master.etcd-ca.crt --cert=/etc/origin/master/master.etcd-client.crt  --key=/etc/origin/master/master.etcd-client.key"

if [ ! -d "$backup_data_dir" ];then
  mkdir -p $backup_data_dir
fi

if [ ! -d "$backup_config_dir" ];then
  mkdir -p $backup_config_dir
fi

host_name=$HOSTNAME
check_etcd=`oc get pod --all-namespaces -o wide | grep etcd | grep $host_name`

echo "-----------------------------------------" >> $backup_log_file
echo "$(date '+%F %T') [info]: backup ETCD start." >> $backup_log_file
if [ "$check_etcd" = "" ];then
  echo "$(date '+%F %T') [error]: etcd not running on the host $HOSTNAME" >> $backup_log_file
else
  echo "$(date '+%F %T') [info]: start to backup etcd config" >> $backup_log_file
  cp -R /etc/etcd/ $backup_config_dir
  echo "$(date '+%F %T') [info]:  backup etcd config end " >> $backup_log_file
fi


#delete backup older than 7 days
#retain_backup_days=7
#find $dest_root_path -name 'backup-etcd-*' -type d -mtime +$retain_backup_days |xargs rm -rf;
echo "$(date '+%F %T') [info]: backup ETCD end." >> $backup_log_file
echo "---------------------------------------" >> $backup_log_file
