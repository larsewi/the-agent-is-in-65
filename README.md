# The agent is in - Episode 65

## Step 1 -- Setup VMs

```
./cloud.sh
```

## Step 2 -- Ping hosts

```
ansible all -i ansible/inventory.ini -m ping
```

## Step 3 -- Install collection

```
ansible-galaxy collection install cfengine.cfengine
```

## Step 4 -- Run playbook

```
ansible-playbook -i ansible/inventory.ini ansible/playbook.yaml
```

## Step 5 -- Verify

```
ansible all -i ansible/inventory.ini -b -m command -a "cf-agent -V"
```

## Step 6 -- New setup code
```
sudo cf-hub --new-setup-code
```

## Step 7 -- Create a new Build project

Use master as version

## Step 8 -- Add install ansible variable

Configure by defining `data:install_ansible` on all hosts

## Step 9 -- Add Ansible playbook dispatcher

Input new file `playbook.yaml` with content:

```yaml
- hosts: all
  gather_facts: false
  tasks:
    - name: Create marker file
      ansible.builtin.file:
        path: /tmp/marker
        state: touch
```

## Step 11 -- Stop cf-execd

```
sudo systemctl stop cf-execd
```

## Step 12 -- Deploy Build project

```
sudo find /var/cfengine/masterfiles -name playbook.yaml
```

## Step 13 -- Run the agent

```
sudo cf-agent -KIf update.cf && sudo cf-agent -KI
```
