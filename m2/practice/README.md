# Kernel Parameters

To investigate the system:
```
ls -l /proc
```

The proc file system acts as an interface to internal data structures in the kernel. It can be used to obtain information about the system and to change certain kernel parameters at runtime (sysctl).


To get a list of all kernel parameters and their values:
```
sudo sysctl -a
```

Two ways of changing a parameter:

```
echo "lsaa" | sudo tee /proc/sys/kernel/domainname
sudo sysctl -w kernel.domainname='demo'
```

To make changes permanent, create a conf file in `/etc/sysctl.d/<conf-file-name>.conf`
```
echo kernel.domainname=lsaa | sudo tee /etc/sysctl.d/50-kernel-domainname.conf
```

Apply the change with one of these:
```
sudo sysctl -p /etc/sysctl.d/50-kernel-domainname.conf

# or
sudo sysctl --system
```

For example, to turn off ping:

Check the available parameters:
```
sudo sysctl -ar icmp

```

0 = deactivated
1 = active

Activate it with: 
```
sudo sysctl -w net.ipv4.icmp_echo_ignore_all=1
```

`ping -4 localhost` will not return a response now


# Resource Limits

The `pam_limits` module sets limits on the system resources that can
be obtained in a user-session. Similar to [storage quotas](../../m1/practice/README.md#quotas).

Explore with 
```
ulimit --help
```

In order to make changes persistent, edit `/etc/security/limits.conf` file or add a file to `/etc/security/limits.d/`



# Access Control Lists

ACLs allow us to apply a more specific set of permissions to a file or directory without (necessarily) changing the base ownership and permissions. They let us "tack on" access for other users or groups.

Install
```
sudo apt-get install acl
```

Experiment 
```
sudo mkdir -m 700 /secret

cd /secret
-bash: cd: /secret: Permission denied

sudo setfacl -m u:<user-name>:rwx /secret

getfacl /secret/
getfacl: Removing leading '/' from absolute path names
# file: secret/
# owner: root
# group: root
user::rwx
user:vagrant:rwx
group::---
mask::rwx
other::---

```


# Context Based Security

- Discretionary Access Control (DAC) - at the individual level (permissions, ACLs)
- Mandatory Access Control (MAC) - Additional layer  
    - Mandatory access control is based on a hierarchical model representing security levels. Users are assigned a clearance level, and resources are assigned a security label 
    - i.e. AppArmor, SELinux


## Security Enhanced Linux (SELinux)
SELinux is a set of kernel modifications and user-space tools that have been added to various Linux distributions. Its architecture strives to separate enforcement of security decisions from the security policy, and streamlines the amount of software involved with security policy enforcement.

## Application Armor (AppArmor)
AppArmor is a Linux kernel security module that allows the system administrator to restrict programs' capabilities with per-program profiles. Profiles can allow capabilities like network access, raw socket access, and the permission to read, write, or execute files on matching paths.

Check if AppArmor is enabled:
```
sudo aa-enabled
```

Check its status
```
sudo aa-status
```

Install additional tools:
```
sudo apt-get install apparmor-utils
```

Check profiles
```
ls -l /etc/apparmor.d/
total 40
drwxr-xr-x 2 root root 4096 Oct 12 19:39 abi
drwxr-xr-x 4 root root 4096 Oct 12 19:39 abstractions
drwxr-xr-x 2 root root 4096 Feb 14  2023 disable
drwxr-xr-x 2 root root 4096 Feb 14  2023 force-complain
drwxr-xr-x 2 root root 4096 Oct 12 19:54 local
-rw-r--r-- 1 root root 1379 Feb 14  2023 lsb_release
-rw-r--r-- 1 root root 1189 Feb 14  2023 nvidia_modprobe
-rw-r--r-- 1 root root 3461 Mar 30  2023 sbin.dhclient
drwxr-xr-x 5 root root 4096 Oct 12 19:39 tunables
-rw-r--r-- 1 root root 3448 Mar 13  2023 usr.bin.man
```

To add profiles, install:
```
sudo apt-get install apparmor-profiles-extra
```

To create a simple profile:
```
sudo aa-autodep ping

sudo cat /etc/apparmor.d/usr.bin.ping
# Last Modified: Sun Mar  3 09:55:26 2024
abi <abi/3.0>,

include <tunables/global>

/usr/bin/ping flags=(complain) {
  include <abstractions/base>

  /usr/bin/ping mr,

}
```

Enforce it:
```
sudo aa-enforce ping
```

Check the logs:

```
sudo aa-logprof

ERROR: Can't find system log "/var/log/syslog". Please check permissions.
```

On recent versions of Debian, you may see an error that is similar to `ERROR: Can't find system log "/var/log/syslog". Please check permissions.`
Install `auditd` with
```
sudo apt-get install auditd audispd-plugins
```

Try again and select the preferred configs:

```
sudo aa-complain ping
ping localhost
PING localhost(localhost (::1)) 56 data bytes
64 bytes from localhost (::1): icmp_seq=1 ttl=64 time=0.047 ms
64 bytes from localhost (::1): icmp_seq=2 ttl=64 time=0.063 ms
64 bytes from localhost (::1): icmp_seq=3 ttl=64 time=0.063 ms
```

```
sudo aa-logprof
Updating AppArmor profiles in /etc/apparmor.d.
Reading log entries from /var/log/audit/audit.log.
Enforce-mode changes:

Profile:        /usr/bin/ping
Network Family: inet
Socket Type:    dgram

 [1 - include <abstractions/nameservice>]
  2 - network inet dgram, 
(A)llow / [(D)eny] / (I)gnore / Audi(t) / Abo(r)t / (F)inish

...
```

# Auditing and Packet Filtering

- **Auditing**: who did what when

One way would be to check the journal

```
journalctl -xe
```

A more powerful way is to use `auditd`

Install and start
```
sudo apt-get install auditd audispd-plugins
sudo systemctl enable --now auditd
```

Check for added users:
```
sudo ausearch -m ADD_USER --start recent
----
time->Sun Mar  3 10:23:43 2024
type=ADD_USER msg=audit(1709454223.369:179): pid=2275 uid=0 auid=1000 ses=3 subj=unconfined msg='op=adding user id=1003 exe="/usr/sbin/useradd" hostname=machine-1 addr=? terminal=pts/1 res=success'
```

Check for logins:
```
sudo ausearch -m USER_LOGIN
<no matches>
```

... or unsuccessful login attempts:
```
sudo ausearch -m USER_LOGIN --success no
```

Example - watch reads of some file:

Create it
```
echo 'secret' | sudo tee /readme.txt
```

Create a rule
```
               #watch object  #read #key
sudo auditctl -w /readme.txt -p r -k super-secret

sudo auditctl -l
-w /readme.txt -p r -k super-secret
```

Check:
```
sudo ausearch -k super-secret
----
...

time->Sun Mar  3 10:35:07 2024
type=PROCTITLE msg=audit(1709454907.881:270): proctitle=636174002F726561646D652E747874
type=PATH msg=audit(1709454907.881:270): item=0 name="/readme.txt" inode=22 dev=08:01 mode=0100644 ouid=0 ogid=0 rdev=00:00 nametype=NORMAL cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0
type=CWD msg=audit(1709454907.881:270): cwd="/secret"
type=SYSCALL msg=audit(1709454907.881:270): arch=c000003e syscall=257 success=yes exit=3 a0=ffffff9c a1=7ffdf411f5f6 a2=0 a3=0 items=1 ppid=2349 pid=2352 auid=1000 uid=1003 gid=1003 euid=1003 suid=1003 fsuid=1003 egid=1003 sgid=1003 fsgid=1003 tty=pts0 ses=3 comm="cat" exe="/usr/bin/cat" subj=unconfined key="super-secret"
```




## Firewalls

### Firewalld

Check status
```
systemctl status firewalld 
```

Start & enable
```
sudo systemctl enable --now firewalld
```

Check which zone is set as the default zone
```
sudo firewall-cmd --get-default-zone
```

Check active zones
```
sudo firewall-cmd --get-active-zones
```

Check available zones
```
sudo firewall-cmd --get-zones
```

Check services
```
sudo firewall-cmd --list-services
```

Add service
```
sudo firewall-cmd --add-service http --permanent 
sudo firewall-cmd --reload 
```

Add a custom service:

Create a file `/etc/firewalld/services/demo.xml`:
```
<?xml version="1.0" encoding="utf-8"?>
<service>
<short>Demo</short>
<port protocol="tcp" port="8000" />
<port protocol="tcp" port="8080" />
</service>
```

The add it as with a built-in service:
```
sudo firewall-cmd --add-service demo --permanent 
sudo firewall-cmd --reload 
```



### ufw 

Install and start
```
sudo apt-get install ufw
sudo systemctl enable --now ufw
```

Check status
```
sudo ufw status
```

Enable
```
sudo ufw enable
```

Add rules
```
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
```

Check
```
sudo ufw status verbose
```

