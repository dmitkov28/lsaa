# Tasks

- Create a Samba group share (one folder, two users, one group, accessible only by the group)
    **Solution**
    Create the user & group
    ```
    sudo groupadd mygroup   
    sudo useradd -G mygroup user1
    sudo useradd -G mygroup user2
    ```
    Create the share
    ```
    sudo mkdir -p /samba/sharedfolder
    sudo chmod 775 /samba/sharedfolder
    sudo chown :mygroup /samba/sharedfolder
    ```

    Add the stanza to `/etc/samba/smb.conf`
    ```
    [sharedfolder]
        comment = My group share
        path = /samba/sharedfolder
        browseable = yes
        writable = yes
        valid users = @mygroup
        create mask = 0770
        directory mask = 0770 
    ```

    Create the samba users
    ```
    sudo smbpasswd -a user1
    sudo smbpasswd -a user2
    ```

    Test & reload the service
    ```
    sudo testparm
    sudo systemctl reload smb nmb
    ```

<hr/>

- Create an NFS share with different access (read-write and read-only) for two stations 
    **Solution**
    Create the export
    ```
    sudo mkdir /nfs
    sudo chmod 777 -R /nfs/
    ```

    Add the following line to /etc/exports:
    ```
    /nfs	192.168.200.101(rw,sync,no_subtree_check) 192.168.200.102(ro,sync,no_subtree_check)
    ```
    
    Apply
    ```
    sudo exportfs -rav
    ```
<hr/>

- Create an iSCSI disk-based target
    **Solution**
    [See here](../practice/README.md#block)

<hr/>

- Create a GlusterFS dispersed volume
    **Solution**
    Install GlusterFS [on the servers](../practice/README.md#installation-servers) and [on the client](../practice/README.md#installation-client)
    
    Prepare the bricks (on machine_1, machine_2, machine_3 respectively)
    ```
    sudo mkdir /storage/glusterfs/brick<X>
    ```
    
    Probe
    ```
    sudo gluster peer probe 192.168.200.101
    sudo gluster peer probe 192.168.200.102
    ```

    Create the volume
    ```
    sudo gluster volume create vol01 disperse 3 transport tcp 192.168.200.100:/storage/glusterfs/brick1 192.168.200.101:/storage/glusterfs/brick2 192.168.200.102:/storage/glusterfs/brick3
    ```

    Start the volume
    ``` 
    sudo gluster volume start vol01
    ```
<hr/>

