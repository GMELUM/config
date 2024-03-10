#!/bin/sh

USER_NAME="server"
USER_HOMEDIR="/home/server"
USER_SHELL="/bin/bash"
USER_SSH_KEY="$1"

echo "Running the node setup script..."

echo "Updating packages..."
apt update
apt upgrade -y

echo "Created user..."
useradd -m -d $USER_HOMEDIR -s $USER_SHELL -p "" $USER_NAME

echo "Configure user..."
mkdir -p $USER_HOMEDIR/.ssh
echo $USER_SSH_KEY >>$USER_HOMEDIR/.ssh/authorized_keys
chmod 700 $USER_HOMEDIR/.ssh
chmod 600 $USER_HOMEDIR/.ssh/authorized_keys
chown -R $USER_NAME:$USER_NAME $USER_HOMEDIR/.ssh

echo "Configuring SSH..."
sed -i 's/^PermitRootLogin.*/PermitRootLogin without-password/g' /etc/ssh/sshd_config
sed -i 's/#? *PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#? *UsePAM .*/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/#? *PrintLastLog .*/PrintLastLog no/' /etc/ssh/sshd_config

systemctl restart sshd