#!/bin/bash
source_root_path=/mnt
dest_root_path=/backup/images-and-devops-backup
backup_dir=backup-data-$(date '+%Y-%m-%d')
backup_data_dir=$dest_root_path/$backup_dir
devops_source_path=(jenkins-devops-tools nexus-data-devops-tools sonar-plugins-devops-tools gitlab-etc-devops-tools)
source_path=(externel-registry internel-registry)
retries=10
rsync_backup_status=0
gitlab_backup_status=0
sonar_backup_status=0
devops_backup=true
backup_log_file=$dest_root_path/backup.log

if [ ! -d "$backup_data_dir" ];then
  mkdir -p $backup_data_dir
fi

gitlab_backup() {
  devops_namespace=devops-tools
  oc login -u system:admin > /dev/null
  pod_name=`oc get pod -n $devops_namespace -o name| grep -E gitlab-ce-[0-9]+`
  gitlab_pod_name=${pod_name##*/}
  if [ ! -d "${source_root_path}/gitlab-data-devops-tools/gitlab-backups" ];then
     oc exec $gitlab_pod_name mkdir /gitlab-data/gitlab-backups
  fi
  while (( i++ < retries ))
  do
    echo "$(date '+%F %T') [info]: start backup gitlab" >> $backup_log_file
    oc exec $gitlab_pod_name -n $devops_namespace -- bash /gitlab-data/gitlab-backup.sh
    if [ "$?" = "0" ];then
       echo "$(date '+%F %T') [info]: gitlab backup completed normally." >> $backup_log_file
       break
    fi
    sleep 300
  done
  if (( i >= retries )); then
     echo "*******************************"
     echo "$(date '+%F %T') [error]: gitlab backup failure." >> $backup_log_file
     echo "*******************************"
     gitlab_backup_status=1
  fi
}

gitlab_conf_backup() {
  devops_namespace=devops-tools
  oc login -u system:admin > /dev/null
  oc get cm --export gitlab-ce-config -o yaml -n $devops_namespace > $backup_data_dir/gitlab-backups/gitlab-ce-config-cm.yaml
  echo "$(date '+%F %T') [info]: gitlab config backup completed normally." >> $backup_log_file
}

sonar_backup() {
  devops_namespace=devops-tools
  oc login -u system:admin > /dev/null
  pod_name=`oc get pod -n $devops_namespace -o name| grep -E sonarqube-postgresql-[0-9]+`
  sonarpg_pod_name=${pod_name##*/}
  if [ ! -d "${source_root_path}/sonar-postgresql-devops-tools/sonar-pg-backup" ];then
     oc exec $sonarpg_pod_name mkdir /var/lib/pgsql/data/sonar-pg-backup
  fi
  while (( j++ < retries ))
  do
    echo "$(date '+%F %T') [info]: start backup sonarqube postgresql" >> $backup_log_file
    oc exec $sonarpg_pod_name -n $devops_namespace -- bash /var/lib/pgsql/data/sonar-backup.sh 
    if [ "$?" = "0" ];then
       echo "$(date '+%F %T') [info]: sonarqube postgresql backup completed normally." >> $backup_log_file
       break
    fi
    sleep 300
  done
  if (( j >= retries )); then
     echo "*******************************"
     echo "$(date '+%F %T') [error]: sonarqube postgresql backup failure." >> $backup_log_file
     echo "*******************************"
     sonar_backup_status=1
  fi
}

rsync_file() {
  source=$1
  dest=$2

  while (( k++ < retries ))
  do
    echo "$(date '+%F %T') [info]: start rsync $source ..." >> $backup_log_file
    rsync --partial --append -aqz $source $dest
    if [ "$?" = "0" ];then
       echo "$(date '+%F %T') [info]: rsync backup $source completed normally." >> $backup_log_file
       break
    fi
    sleep 300
  done
  if (( k >= retries )); then
     echo "*******************************"
     echo "$(date '+%F %T') [error]: rsync $source failure." >> $backup_log_file
     echo "*******************************"
     rsync_backup_status=1
  fi
}

devops_backup() {
# make gitlab backup
gitlab_backup
if [ "$gitlab_backup_status" = "0" ];then
  rsync_file ${source_root_path}/gitlab-data-devops-tools/gitlab-backups $backup_data_dir
  rm -rf ${source_root_path}/gitlab-data-devops-tools/gitlab-backups/*.tar
  gitlab_conf_backup
fi

# make sonarqube postgresql backup
sonar_backup
if [ "$sonar_backup_status" = "0" ];then
  rsync_file ${source_root_path}/sonar-postgresql-devops-tools/sonar-pg-backup $backup_data_dir
  rm -rf ${source_root_path}/sonar-postgresql-devops-tools/sonar-pg-backup/*.sql
fi
}

echo "-------------------------------------" >> $backup_log_file
echo "$(date '+%F %T') [info]: backup start." >> $backup_log_file
if [ "$devops_backup" = "true" ];then
  devops_backup
  source_path=(`echo ${source_path[*]}` `echo ${devops_source_path[*]}`)
fi

for path in ${source_path[@]}
do
  s_nas=${source_root_path}/$path
  d_nas=$backup_data_dir
  rsync_file $s_nas $d_nas
done

if [ "$rsync_backup_status" = "0" -a "$gitlab_backup_status" = "0" -a "$sonar_backup_status" = "0" ];then
  cd $dest_root_path
  tar -zcf ${backup_dir}.tar.gz ${backup_dir}
  if [ "$?" = "0" ];then
    echo "$(date '+%F %T') [info]: compress backup data complate." >> $backup_log_file
    set -e
    rm -rf $backup_data_dir
  fi
fi

#delete backup older than 7 days
#retain_backup_days=7
#find $dest_root_path -name '*.tar.gz' -type f -mtime +$retain_backup_days |xargs rm -rf;

echo "$(date '+%F %T') [info]: backup end." >> $backup_log_file
echo "-----------------------------------" >> $backup_log_file
exit 0
