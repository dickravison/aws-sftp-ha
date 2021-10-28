#!/bin/bash
#Get list of users
for i in `grep "sftp user" /etc/passwd|cut -d ':' -f 1`;
do
#Check if the uploads directory exists in their home dir, if not then break out of loop
  dir="/home/$i/uploads"
  if [ ! -d $dir ]; then
     continue
  fi
#Sync local dir with S3 storage bucket
  aws s3 sync $dir s3://${backend}/$i
done
