#!/bin/bash

/opt/gitlab/bin/gitlab-rake gitlab:backup:create
if [ "$?" = "0" ];then
  mv /var/opt/gitlab/backups/*.tar /gitlab-data/gitlab-backups/
fi
