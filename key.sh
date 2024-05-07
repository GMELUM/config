#!/bin/sh

USERNAME=${1:-"root"}
SSH_KEY=${2:-"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGT2AHuhMZoVmJ0AxqLnG6/sAnzfGNRzDyc5Z8GvXUe master"}

mkdir -p $USERNAME/.ssh
echo $SSH_KEY >>$USERNAME/.ssh/authorized_keys
chmod 700 $USERNAME/.ssh
chmod 600 $USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME $USERNAME/.ssh

systemctl restart sshd
