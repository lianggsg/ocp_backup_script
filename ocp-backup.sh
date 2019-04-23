#!/bin/bash
set -eo pipefail

dest_root_path=/backup/ocp-backup
backup_dir=backup-ocp-$(date '+%Y-%m-%d')
backup_data_dir=$dest_root_path/$backup_dir/${HOSTNAME}
backup_log_file=$dest_root_path/${HOSTNAME}-backup.log

if [ ! -d "$backup_data_dir" ];then
  mkdir -p $backup_data_dir
fi

ocpfiles(){
  mkdir -p ${backup_data_dir}/etc/sysconfig
  mkdir -p ${backup_data_dir}/etc/pki/ca-trust/source/anchors

  echo "$(date '+%F %T') [info]: backup OCP config files" >> $backup_log_file
  cp -aR /etc/origin ${backup_data_dir}/etc
  cp -aR /etc/sysconfig/atomic-* ${backup_data_dir}/etc/sysconfig

  if [ -f /etc/ansible/hosts ];then
    echo "$(date '+%F %T') [info]: backup ansible install hosts" >> $backup_log_file
    mkdir -p ${backup_data_dir}/etc/ansible
    cp -a /etc/ansible/hosts ${backup_data_dir}/etc/ansible
  fi
  
  if [ -f /etc/sysconfig/flanneld ]
  then
    echo "$(date '+%F %T') [info]: backup flannel configfile" >> $backup_log_file
    cp -a /etc/sysconfig/flanneld ${backup_data_dir}/etc/sysconfig/
  fi

  echo "$(date '+%F %T') [info]: backup iptable&docker configfile" >> $backup_log_file
  cp -aR /etc/sysconfig/{iptables,docker-*} ${backup_data_dir}/etc/sysconfig/

  if [ -d /etc/cni ]
  then
    echo "$(date '+%F %T') [info]: backup cni plugin config" >> $backup_log_file
    cp -aR /etc/cni ${backup_data_dir}/etc/
  fi

  echo "$(date '+%F %T') [info]: backup dnsmasq configfile" >> $backup_log_file
  cp -aR /etc/dnsmasq* ${backup_data_dir}/etc/

  echo "$(date '+%F %T') [info]: backup ca cert" >> $backup_log_file
  cp -aR /etc/pki/ca-trust/source/anchors/* ${backup_data_dir}/etc/pki/ca-trust/source/anchors/
}

packagelist(){
  echo "$(date '+%F %T') [info]: backup package list" >> $backup_log_file
  rpm -qa | sort > ${backup_data_dir}/packages.txt
}

etcdconfig() {
  if [ -d /etc/etcd ];then
     echo "$(date '+%F %T') [info]: backup etcd config file" >> $backup_log_file
     cp -R /etc/etcd ${backup_data_dir}/etc/
  fi
}

#compress(){
#  cd $dest_root_path
#  tar -zcf ${backup_dir}.tar.gz ${backup_dir}
#  if [ "$?" = "0" ];then
#    echo "$(date '+%F %T') [info]: compress backup data complate." >> $backup_log_file
#    set -e
#    rm -rf $dest_root_path/$backup_dir
#  fi
#}

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then
  usage
  exit 0
fi

echo "-----------------------------------------" >> $backup_log_file
echo "$(date '+%F %T') [info]: backup OCP start." >> $backup_log_file
ocpfiles
packagelist
etcdconfig
#delete backup older than 7 days
#retain_backup_days=7
#find $dest_root_path -name 'backup-ocp-*' -type d -mtime +$retain_backup_days |xargs rm -rf;
echo "$(date '+%F %T') [info]: backup OCP end." >> $backup_log_file
echo "---------------------------------------" >> $backup_log_file
exit 0
