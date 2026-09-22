#!/bin/bash

set -euo pipefail

# Spawn VMs
cf-remote spawn --platform ubuntu-26 --name hub --count 1 --role hub
cf-remote spawn --platform debian-13 --name cli --count 1 --role client

# Wait for VMs
sleep 30

HUB_INFO=$(cf-remote info -H hub)
HUB_UNAME=$(awk -F@ '/^[^ ]+@[^ ]+$/ {print $1; exit}' <<<"$HUB_INFO")
HUB_PUB_IP=$(awk -F@ '/^[^ ]+@[^ ]+$/ {print $2; exit}' <<<"$HUB_INFO")
HUB_PRIV_IP=$(awk '/^Private IP/ {print $NF; exit}' <<<"$HUB_INFO")

CLI_INFO=$(cf-remote info -H cli)
CLI_UNAME=$(awk -F@ '/^[^ ]+@[^ ]+$/ {print $1; exit}' <<<"$CLI_INFO")
CLI_PUB_IP=$(awk -F@ '/^[^ ]+@[^ ]+$/ {print $2; exit}' <<<"$CLI_INFO")
CLI_PRIV_IP=$(awk '/^Private IP/ {print $NF; exit}' <<<"$CLI_INFO")

# Generate keypair on hub
ssh "$HUB_UNAME@$HUB_PUB_IP" -o StrictHostKeyChecking=accept-new \
    "[ -f ~/.ssh/id_ed25519 ] \
    || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -q -C '$HUB_UNAME@$HUB_PRIV_IP'"

# Copy public key to client
scp -o StrictHostKeyChecking=accept-new "$HUB_UNAME@$HUB_PUB_IP:.ssh/id_ed25519.pub" "$CLI_UNAME@$CLI_PUB_IP:/tmp/"

# Append key to authorized keys
ssh "$CLI_UNAME@$CLI_PUB_IP" 'mkdir -p ~/.ssh && chmod 700 ~/.ssh \
    && cat /tmp/id_ed25519.pub >> ~/.ssh/authorized_keys \
    && chmod 600 ~/.ssh/authorized_keys && rm -f /tmp/id_ed25519.pub'

# Populate known hosts
ssh "$HUB_UNAME@$HUB_PUB_IP" "ssh '$CLI_UNAME@$CLI_PRIV_IP' -o StrictHostKeyChecking=accept-new 'echo OK'"

# Install ansible
ssh "$HUB_UNAME@$HUB_PUB_IP" 'sudo apt -y update && sudo apt -y install ansible'

# Create inventory
ssh "$HUB_UNAME@$HUB_PUB_IP" "mkdir -p ansible; cat << EOF > ansible/inventory.ini
[hub]
localhost ansible_connection=local

[clients]
$CLI_PRIV_IP ansible_user=$CLI_UNAME

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF"

# Create playbook
ssh "$HUB_UNAME@$HUB_PUB_IP" "cat << EOF > ansible/playbook.yaml
- name: Bootstrap the CFEngine hub
  hosts: hub
  become: true
  tasks:
    - name: Install and bootstrap the hub
      cfengine.cfengine.cfengine:
        policy_server: $HUB_PRIV_IP
        version: master

- name: Bootstrap the CFEngine clients
  hosts: clients
  become: true
  tasks:
    - name: Wait for cf-serverd on the hub
      ansible.builtin.wait_for:
        host: $HUB_PRIV_IP
        port: 5308
        timeout: 120

    - name: Install and bootstrap the clients
      cfengine.cfengine.cfengine:
        policy_server: $HUB_PRIV_IP
        version: master
EOF"

echo "$HUB_INFO"
echo "$CLI_INFO"

