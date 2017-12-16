# Ansible Installer

The ansible installer will allow you to configure multiple nodes simultaneously.

If you have an existing node it will be easiest to run the installer from that node.

```
apt-get install ansible
git clone https://github.com/WhenLamboMoon/docker-zen-node/
cd docker-zen-node/ansible/
```

Configure the hosts files with your list of nodes, an example hosts file would look like this:

```
# Parameters passed to all hosts
[all:vars]
email=test@example.com
region=na

[zen-nodes]
node.example.com fqdn=node.example.com stakeaddr=test
node2.example.com fqdn=node3.example.com stakeaddr=test
node3.example.com fqdn=node2.example.com stakeaddr=test

[bootstrap-nodes]
node2.example.com
node3.example.com
```

If you are running this from an existing node, jump down to the [bootstrap node](https://github.com/WhenLamboMoon/docker-zen-node/tree/master/ansible#bootstraping-the-blockchain) section
to speed up node installation.

Now run the installer, this will install the securenodes on all of your listed hosts.

```
ansible-playbook -i hosts main.yml
```

When the installation completes, all your installed nodes details will be stored in /tmp/zen-node-results

```
cat /tmp/zen-node-results
```

It will list results similar to this:

```
localhost:

Shield Address:
zcNBdJxZnhTZMdiSQABYiW1wY2A8Swrq8TsauYLiyaShKD91GrZvn1dqAkhZ8USmAHoKNxhokeoYJZwJAtKjyeWN4BMNM6v

Balance:
  transparent: 0.00
  private: 0.00
  total: 0.00
```

You will now need to send the 1 ZEN to the shield addresses that have a balance of 0.0

### Bootstraping the blockchain

*Bootstrapping currently does not work.*

If you are running the installer on the same server as an existing zen-node,
you can bootstrap/seed the initial blockchain to your new nodes so they can sync faster.

Simply add the new nodes to your hosts inventory file as:

```
[bootstrap-nodes]
new-node1.example.com
new-node2.example.com
```

Now run the bootstrap playbook:

```
ansible-playbook -i hosts bootstrap.yml
```

This will copy the blockchain from your current node (running the installer) to your new nodes. After you run this, remove the nodes from the [bootstrap-nodes] group and run the full installer.

### Upgrading

The installer has a handy way to update all of your zen-nodes:

```
ansible-playbook -i hosts upgrade.yml
```

This will upgrade restart the required services. It is recommended you subscribe to
[announcement tracking](https://github.com/WhenLamboMoon/docker-zen-node/issues/28) to receive email notifications.

### Status

You may check the status of your nodes anytime with the command:

```
ansible-playbook -i hosts status.yml
```

This will report the node name, shield address, balance and current block.
