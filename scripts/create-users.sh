#!/bin/bash
for i in `aws --region eu-west-1 dynamodb scan --table-name ${table} | jq -r '.Items[] | with_entries( .key |= ascii_downcase ) | @base64'`;
do
    #Populate local vars with user creds
    USERNAME=$(echo $i | base64 -d | jq -r .username.S)
    PASSWORD=$(echo $i | base64 -d | jq -r .password.S)
    KEYFILE=$(echo $i | base64 -d | jq -r .keyfile.S)
    USEREXISTS=""
    CREATEUSER=""
    #Check user field isn't null, shouldn't be possible but if it is, exit loop. Otherwise create the user, add it to the sftp-users group and create the required dirs
    if [ $USERNAME == "null" ]; then
        CREATEUSER="no"
    elif [ $(cut -d ':' -f 1 /etc/passwd | grep -wc $USERNAME) -gt 0 ]; then
	USEREXISTS="yes"
    else 
	CREATEUSER="yes"
        useradd -g sftp-users -c "sftp user" -s /bin/false -m -d /home/$USERNAME $USERNAME
        chown root: /home/$USERNAME
        chmod 755 /home/$USERNAME
        mkdir /home/$USERNAME/{uploads,.ssh}
        chmod 755 /home/$USERNAME/{uploads,.ssh}
        chown $USERNAME:sftp-users /home/$USERNAME/{uploads,.ssh}
    fi
    #Set password for user if the field isn't null or update password for existing user
    if [[ $CREATEUSER == "yes" || $USEREXISTS == "yes" ]] && [ "$PASSWORD" != "null" ]; then
        echo -e $PASSWORD | passwd $USERNAME --stdin
    fi
    #Add keyfile to users authorized_keys if the field isn't null or replace key for existing user
    if [[ $CREATEUSER == "yes" || $USEREXISTS == "yes" ]] && [ "$KEYFILE" != "null" ]; then
        echo $KEYFILE > /home/$USERNAME/.ssh/authorized_keys
        chmod 600 /home/$USERNAME/.ssh/authorized_keys
        chown $USERNAME /home/$USERNAME/.ssh/authorized_keys
        echo $KEYFILE
    fi
done
