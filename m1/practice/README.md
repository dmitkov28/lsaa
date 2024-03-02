Setup: a single Vagrant VM with 4 disks (5GB each)

```
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   32G  0 disk 
├─sda1   8:1    0   31G  0 part /
├─sda2   8:2    0    1K  0 part 
└─sda5   8:5    0  975M  0 part [SWAP]
sdb      8:16   0    5G  0 disk 
sdc      8:32   0    5G  0 disk 
sdd      8:48   0    5G  0 disk 
sde      8:64   0    5G  0 disk 
sr0     11:0    1 1024M  0 rom  
```

<br/>

# Software RAID

Create a partition with `sudo fdisk /dev/sdb` and then go trough the interactive steps.
Alternatively, use `parted`:

```

# install
sudo apt-get update && sudo apt-get install -y parted

sudo parted -s /dev/sdc -- mklabel msdos mkpart primary 2048s -0m set 1 raid on

```

Install `mdadm`

```

sudo apt-get install -y mdadm

```

## RAID 0 (Striping)

RAID 0 will split the data evenly across the disks without parity, redundancy or fault tolerance.

```

sudo mdadm --create /dev/md0 --level 0 --raid-devices 2 /dev/sd{b,c}1

```

Check with `cat /proc/mdstat` or `sudo mdadm --detail /dev/md0`

Erase the superblock with

```

# stop the device
sudo mdadm --stop /dev/md0

# zero the superblock
sudo mdadm --zero-superblock /dev/sd{b,c}1


```

## RAID 1 (Mirroring)

The data is copied on both disks

```

sudo mdadm --create /dev/md0 --level 0 --raid-devices 2 /dev/sd{b,c}1

```

## RAID 5

RAID 5 uses disk striping with parity

```
sudo mdadm --create /dev/md0 --level 5 --raid-devices 3 /dev/sd{b,c,d}1

```

## RAID 10

Striping + Mirroring

```

sudo mdadm --create /dev/md0 --level 10 --raid-devices 4 /dev/sd{b..e}1


```

To ensure that the array will re-assemble automatically after reboot:

```

sudo mdadm --detail --brief /dev/md0 | sudo tee -a /etc/mdadm.conf


```

## Clean up

```

# Unmount the array
sudo umount /dev/md0

# Stop the array 
sudo mdadm --stop /dev/md0

# Clean up the devices 
sudo mdadm --zero-superblock /dev/sd{b,c,d,e}1


# Remove the config file
sudo rm /etc/mdadm.conf


# Use wipefs to remove any remaining structures on the disks
sudo wipefs --all /dev/sd{b..e}

```

# LVM

![alt text](lvm.png)

Install

```

sudo apt-get update
sudo apt-get install -y lvm2

```

## Physical Volumes

First, create `physical volumes`:

```

sudo pvcreate /dev/sd{b..e} -v

# Check with
sudo pvdisplay /dev/sdb

# or
sudo pvs -v

```

## Volume Groups

```

# Create
sudo vgcreate vg_demo /dev/sdb


# Check
sudo vgs -v

# or
sudo vgidsplay vg_demo


```

## Logical Volumes

```
# Create
sudo lvcreate -L 1G -n lv_demo vg_demo

# Check
sudo lvs -v

```

Create a file system on the logical volume:

```

sudo mkfs.ext4 /dev/vg_demo/lv_demo

```

Mount it:

```

sudo mkfs.ext4 /dev/vg_demo/lv_demo

```

Additional commands:

Extend a Logical Volume:

```

# to a specific size
sudo lvextend -L10G /dev/vg_demo/lv_demo

# with a specific amount
sudo lvextend -L +5G /dev/vg_demo/lv_demo

# Extend the file system as well
sudo resize2fs /dev/vg_demo/lv_demo


```

## Snapshots

Create

```

sudo lvcreate -s -L 1G -n lv_demo_snap /dev/vg_demo/lv_demo

```


## Thin Provisioning 
LVM thin provisioning is a feature of the Logical Volume Manager (LVM) that allows for the creation of logical volumes (LVs) that can be much larger than the available physical space. This is achieved by allocating physical space only as it is actually used, rather than pre-allocating the full size of the logical volume at the time of its creation.

Create a thinly provisioned volume: 

```

sudo lvcreate -L 1G --thinpool tp_demo vg_demo
sudo lvcreate -V 5G --thin -n tp_demo_lv vg_demo/tp_demo

WARNING: Sum of all thin volume sizes (5.00 GiB) exceeds the size of thin pool vg_demo/tp_demo and the size of whole volume group (<5.00 GiB).
WARNING: You have not turned on protection against thin pools running out of space.
WARNING: Set activation/thin_pool_autoextend_threshold below 100 to trigger automatic extension of thin pools before they get full.
Logical volume "tp_demo_lv" created.

```

# Advanced Filesystems

## BTRFS

Install with:

```

sudo apt-get update
sudo apt-get install btrfs-progs


```

To create a file system:

```
sudo mkfs.btrfs -d single /dev/sdb

# -d means the user data will not be duplicated

```

Mount with:

```

sudo mount /dev/sdb /data


```

Check usage with:

```

sudo btrfs device usage /data

/dev/sdb, ID: 1
   Device size:             5.00GiB
   Device slack:              0.00B
   Data,single:             8.00MiB
   Metadata,DUP:          512.00MiB
   System,DUP:             16.00MiB
   Unallocated:             4.48GiB

```

Add disks:

```
sudo btrfs device add /dev/sdc /dev/sdd /data

# alternatively 
sudo btrfs filesystem show /data

```

Rebalance the disks to improve performance:

```

sudo btrfs balance start -d -m /data

Done, had to relocate 3 out of 3 chunks

```

### RAID on BTRFS

Striping: 

```
sudo btrfs balance start -dconvert=raid1 -mconvert=raid1 /data         
Done, had to relocate 3 out of 3 chunks

# dconvert --> user data 
# mconvert --> metadata

```

RAID 10:

```
sudo btrfs balance start -dconvert=raid10 -mconvert=raid1 /data  

 sudo btrfs device usage /data
/dev/sdb, ID: 1
   Device size:             5.00GiB
   Device slack:              0.00B
   Data,RAID10/2:           2.00GiB
   Metadata,RAID1:        256.00MiB
   System,RAID1:           32.00MiB
   Unallocated:             2.72GiB

/dev/sdc, ID: 2
   Device size:             5.00GiB
   Device slack:              0.00B
   Data,RAID10/2:           2.00GiB
   Unallocated:             3.00GiB

/dev/sdd, ID: 3
   Device size:             5.00GiB
   Device slack:              0.00B
   Data,RAID10/2:           2.00GiB
   Metadata,RAID1:        256.00MiB
   System,RAID1:           32.00MiB
   Unallocated:             2.72GiB

```

Subvolumes:

```
sudo btrfs subvolume create /data/svol

# Create a mountpoint 
sudo mkdir -p /data/subvolume

# And mount it there
sudo mount -o subvolid=<ID> /dev/sdb /data/svol

```

## ZFS

Install

```

sudo apt-get install software-properties-common
sudo apt-add-repository contrib

sudo apt-get update
sudo apt-get install zfsutils-linux


```

### Striped pool

```
sudo zpool create zfs-stripe /dev/sdb /dev/sdc

# This will mount the pool in /zfs-stripe folder

# To mount at a custom mount point
sudo zpool create -m /data zfs-stripe /dev/sdb /dev/sdc


```

Status check:
```

sudo zpool status zfs-stripe

# or
sudo zfs list

```

### Mirrored pool

```

sudo zpool create -m /storage/zfsm zfs-mirror mirror /dev/sdd /dev/sde

```

To destroy them:

```
sudo zpool destroy zfs-mirror
sudo zpool destroy zfs-stripe

```

### RAID5-like pool

```

sudo zpool create -m /storage/zfsr zfs-raidz raidz /dev/sdb /dev/sdc /dev/sdd

```



# Quotas

Prepare a  partition and a file system


```
# Create the mountpoints

sudo mkdir -p /storage/{ext4,xfs}

```

```
# Ext4
sudo parted -s /dev/sdb -- mklabel msdos mkpart primary 2048s -0m set 1
sudo mkfs.ext4 /dev/sdb1

# XFS
sudo apt-get install -y xfsprogs
sudo parted -s /dev/sdc -- mklabel msdos mkpart primary 2048s -0m set 1
sudo mkfs.xfs -f /dev/sdc1

```

Add them to `/etc/fstab`

```

/dev/sdb1       /storage/ext4   ext4    defaults        0 0
/dev/sdc1       /storage/xfs    xfs     defaults        0 0

sudo mount -av

```

## Ext4 quotas

Install

```
sudo apt-get update
sudo apt-get install quota

```

Edit `/etc/fstab`

```

/dev/sdb1       /storage/ext4   ext4    usrquota        0 0

```

Unmount and mount again:

```
sudo umount /storage/ext4
sudo mount -av

```

Check the existing quotas:

```

sudo quotacheck -mu /dev/sdb1


```

Enable the quota:
```
sudo quotaon /dev/sdb1

```

Inspect:

```
sudo repquota -uv /dev/sdb1
*** Report for user quotas on device /dev/sdb1
Block grace time: 7days; Inode grace time: 7days
                        Block limits                File limits
User            used    soft    hard  grace    used  soft  hard  grace
----------------------------------------------------------------------
root      --      20       0       0              2     0     0       

Statistics:
Total blocks: 6
Data blocks: 1
Entries: 1
Used average: 1.000000
```


Add a user to test the quotas on:

```
sudo useradd -m demo
sudo passwd demo

```

Set a quota

```

sudo setquota -u demo 20000 25000 0 0 /dev/sdb1

```

Test:

```
sudo chmod 777 /storage/ext4/

su demo

# Do something stupid:
dd if=/dev/zero of=/storage/ext4/fill.dat

```

## XFS quotas


Edit `/etc/fstab`

```

/dev/sdb1       /storage/ext4   ext4   usrquota,uqnoenforce       0 0

```

Unmount and mount again:

```
sudo umount /storage/xfs
sudo mount -av

```

Set a quota:

```
sudo xfs_quota -xc 'limit -u bsoft=20m bhard=25m demo' /dev/sdc1

```

Test:

```
sudo chmod 777 /storage/xfs/

su demo

# Do something stupid:
dd if=/dev/zero of=/storage/ext4/fill.dat

```

## Encryption

Check for the DM_CRYPT module:

```
grep -i DM_CRYPT /boot/config-$(uname -r)
```

Check if the module is loaded:

```
sudo lsmod | grep dm_crypt
```

Load it with:

```
sudo modprobe dm_crypt
```

Install:

```
sudo apt-get install cryptsetup
```

Create a partition for encryption:

```
sudo parted -s /dev/sdd -- mklabel msdos mkpart primary 2048s 1024m set 1
```

### Encrypt a partition

```
sudo cryptsetup -y luksFormat /dev/sdd1

```

Answer `YES` and create a passphrase.

Create a file system:

```
sudo mkfs.xfs /dev/mapper/encr

```

Create a mountpoint and mount it:

```
sudo mkdir -p /secret
sudo mount /dev/mapper/encr /secret
```

Create a secret file:

```
echo "Super secret file" | sudo tee /secret/secret.txt

```


Unmount and close the encrypted device:

```
sudo umount /secret
sudo cryptsetup luksClose encr
```

To use the device again:

```
# Open
sudo cryptsetup luksOpen /dev/sdd1 encr

# Mount 
sudo mount /dev/mapper/encr /secret/

```