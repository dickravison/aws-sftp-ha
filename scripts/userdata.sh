#!/bin/bash -xe
yum install jq -y
yum update -y
groupadd sftp-users
echo "
Match Group sftp-users
   ChrootDirectory %h
   ForceCommand internal-sftp
   AllowTcpForwarding no
   X11Forwarding no
" >>  /etc/ssh/sshd_config
sed -i s/'PasswordAuthentication no'/'PasswordAuthentication yes'/g /etc/ssh/sshd_config
systemctl restart sshd
mkdir /tmp/scripts
aws s3 sync s3://${scripts_bucket} /tmp/scripts
chmod u+x /tmp/scripts/*.sh
cp -p /tmp/scripts/*.sh /usr/local/bin/
cp /tmp/scripts/crontab /etc/crontab
