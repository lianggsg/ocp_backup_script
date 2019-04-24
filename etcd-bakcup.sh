#!/bin/bash
set -eo pipefail
export ETCDCTL_API=3

export ETCD_POD_MANIFEST="/etc/origin/node/pods/etcd.yaml"
export ETCD_EP=$(grep https ${ETCD_POD_MANIFEST} | cut -d '/' -f3)

echo "ETCD_POD_MANIFEST = "$ETCD_POD_MANIFEST
echo "ETCD_EP = "$ETCD_EP

host_name=$HOSTNAME
dest_root_path=/backup/etcd-data-backup/$host_name/$(date '+%Y%m')/$(date '+%Y%m%d')

backup_data_dir=$dest_root_path/backup-etcd-data
backup_config_dir=$dest_root_path/backup-etcd-config
backup_log_file=$dest_root_path/etcd-backup.log


if [ ! -d "$backup_data_dir" ];then
  mkdir -p $backup_data_dir
fi

if [ ! -d "$backup_config_dir" ];then
  mkdir -p $backup_config_dir
fi

etcd_name=`oc get pod --all-namespaces -o wide | grep etcd-$host_name|awk '{print $2}'`
echo "-----------------------------------------" >> $backup_log_file
echo "$(date '+%F %T') [info]: backup ETCD start." >> $backup_log_file
if [ "$etcd_name" = "" ];then
  echo "$(date '+%F %T') [error]: etcd not running on the host $HOSTNAME" >> $backup_log_file
else
  echo "$(date '+%F %T') [info]: start to backup etcd config" >> $backup_log_file
  cp -R /etc/etcd/ $backup_config_dir
  echo "$(date '+%F %T') [info]:  backup etcd config end " >> $backup_log_file

  echo "$(date '+%F %T') [info]: start to backup etcd data" >> $backup_log_file
  oc login -u system:admin
  export ETCD_POD=$(oc get pods -n kube-system | grep -o -m 1 '\S*etcd\S*')
  echo "ETCD_POD = "$ETCD_POD
  oc project kube-system
  oc exec ${ETCD_POD} -- /bin/bash -c "ETCDCTL_API=3 etcdctl \
        --cert /etc/etcd/peer.crt \
        --key /etc/etcd/peer.key \
        --cacert /etc/etcd/ca.crt \
        --endpoints $ETCD_EP \
        snapshot save /tmp/snapshot.db "
    oc cp $ETCD_POD:/tmp/snapshot.db $backup_data_dir/

  echo "$(date '+%F %T') [info]:  backup etcd data end " >> $backup_log_file

fi

#delete backup older than 7 days
#retain_backup_days=7
#find $dest_root_path -name 'backup-etcd-*' -type d -mtime +$retain_backup_days |xargs rm -rf;
echo "$(date '+%F %T') [info]: backup ETCD end." >> $backup_log_file
echo "---------------------------------------" >> $backup_log_file
