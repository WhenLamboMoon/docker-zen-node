# Ansible Installer

The ansible installer will allow you to configure multiple nodes simultaneously.

Configure the hosts files with your list of nodes eg.

```
[zen-nodes]
node1.com fqdn=test stakeaddr=test email=test rpcpassword=testtest region=sea
node2.com fqdn=test2 stakeaddr=test2 email=test rpcpassword=testtest region=sea
```

Now run the installer with:

```
ansible-playbook -i hosts main.yml
```

When the installation completes, you can check the output of all your
installed nodes will be stored in /tmp/zen-node-results

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

You may now send your 1 ZEN to this shield address.
