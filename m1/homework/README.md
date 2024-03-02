# Tasks

- Create a RAID10-based pool in ZFS out of six devices each 5 GB in size. Do it in two different configurations – 3x2 and 2x3

    **Solution**

    - 3x2

    ```
    sudo zpool create zfs_raid10-3x2 mirror /dev/sd{b,c} mirror /dev/sd{d,e} mirror /dev/sd{f,g}

    ```

    - 2x3

    ```

    sudo zpool create zfs-raid10-2x3 mirror /dev/sd{b,c} mirror /dev/sd{d,e} mirror /dev/sd{f,g} 
    
    ```

<hr/>

- Create a RAID6-based pool in ZFS out of five devices each 5 GB in size

    **Solution**

    ```

     sudo zpool create zfs-raid6 raidz2 /dev/sd{b,c,d,e,f} 

    ```

<hr/>

- Research on how to use a key file to automount an encrypted volume on boot and demonstrate it for one drive

    **Solution**

    Create a key:
    ```
    sudo dd if=/dev/random of=/root/crypt.key bs=1024 count=2
    sudo chmod 0400 /root/crypt.key 
    ```

    Add the key:
    ```
    sudo cryptsetup luksAddKey  <encrypted-device> /root/crypt.key 
    ```

    Use the key:
    ```
    sudo cryptsetup luksOpen <encrypted-device> encr --key-file /root/crypt.key 
    ```

    Add this to `/etc/crypttab`:
    
    ```
    encr /dev/sdb1 /root/crypt.key luks 
    ```

    Add this to `/etc/fstab`:

    ```
    /dev/mapper/encr /secret xfs defaults 0 0 
    ```