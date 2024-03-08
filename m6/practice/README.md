# Part 1: Load Balancing

## Linux Virtual Server

### Installation

First, some preparation:

#### Enable Routing between the 2 NICs

First, enable IP Forwarding 

```
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Enable masquerading

Option 1 (`iptables`):
```
sudo apt-get install -y iptables iptables-persistent
iptables -t nat -A POSTROUTING -o <internet-facing-interface> -j MASQUERADE
sudo iptables-save | sudo tee /etc/iptables/rules.v4 
```

Option 2 (`ufw`)
```
sudo apt-get install -y ufw
sudo systemctl enable --now ufw
sudo ufw route allow in on enp0s9 out on enp0s8
```

Add this to `/etc/ufw/before.rules`
```
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s <private-network.0/24> -o <public-interface> -j MASQUERADE
COMMIT
```

Reload the firewall
```
sudo ufw reload
```

Option 3 (`nftables`)

Install
```
sudo apt-get update
sudo apt-get install nftables
```

Add this to `/etc/nftables.conf`
```
table ip nat {
    chain PREROUTING {
        type nat hook prerouting priority filter; policy accept;
    }

    chain POSTROUTING {
        type nat hook postrouting priority srcnat; policy accept;
        oifname "<internet-facing-interface>" masquerade
    }
} 
```

Enable & start
```
sudo systemctl enable --now nftables
```


Install
```
sudo apt-get update
sudo apt-get install ipvsadm
```


#### LVS (A simple load balancing scenario with one load balancer and two backend servers)

[Lab environment (part1)](./part1/Vagrantfile)

Edit `/etc/default/ipvsadm`
```
# ipvsadm

# if you want to start ipvsadm on boot set this to true
AUTO="true"

# daemon method (none|master|backup)
DAEMON="master"

# use interface (eth0,eth1...)
IFACE="enp0s8" # external interface name

# syncid to use 
# (0 means no filtering of syncids happen, that is the default)
# SYNCID="0"
```

Start & enable the service
```
sudo systemctl enable --now ipvsadm
```

Check for existing rules
```
sudo ipvsadm -l
```

Clean all rules
```
sudo ipvsadm -C
```

Add a virtual service that will listen on port 80/tcp and will use the round-robin distribution method
```
sudo ipvsadm -A -t <ext-ip-of-machine-1>:80 -s rr

# backend servers
sudo ipvsadm -a -t <ext-ip-of-machine-1>:80 -r <ip-of-machine-2>:80 -m
sudo ipvsadm -a -t <ext-ip-of-machine-1>:80 -r <ip-of-machine-3>:80 -m
```

Check
```
sudo ipvsadm -l
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.56.5:http rr
  -> 192.168.200.101:http         Masq    1      0          0         
  -> 192.168.200.102:http         Masq    1      0          0         
```

To make the configuration persistant
```
sudo ipvsadm-save -n | sudo tee /etc/ipvsadm.rules
```


Setup apache on each of the backend servers
```
sudo apt-get update
sudo apt-get install -y apache2
echo '<h1>Hello from M<X></h1>' | sudo tee /var/www/html/index.html
```



#### LVS (LVS load balancing cluster + keepalived and two backend servers)

[Lab environment (part2)](./part2/Vagrantfile)


Install `keepalived` and `ipvsadm` on the load balancing machines
```
sudo apt-get update
sudo apt-get install -y keepalived ipvsadm
```

Setup apache on each of the backend servers
```
sudo apt-get update
sudo apt-get install -y apache2
echo '<h1>Hello from M<X></h1>' | sudo tee /var/www/html/index.html
```

Configure forwarding on each of the backend servers
```
sudo apt-get install iptables iptables-persistent
sudo iptables -t nat -A PREROUTING -d <ip-address-backend-server> -j REDIRECT
sudo iptables -t nat -A PREROUTING -d <vip-address> -j REDIRECT
```

##### keepalived
An example conf file can be found here `/usr/share/doc/keepalived/samples/keepalived.conf.sample`
[And here (master conf)](./part2/LSAA-M6-P1-KA1.txt)
[And here (backup conf)](./part2/LSAA-M6-P1-KA2.txt)

The conf file goes here `/etc/keepalived/keepalived.conf`

For the master
```
; Common Configuration Block
global_defs {
	notification_email {
		alert@lsaa.lab
	}
	notification_email_from lb1@lsaa.lab
	smtp_server mail.lsaa.lab
	smtp_connect_timeout 30
	router_id lb1.lsaa.lab
}
 
; Master Configureation Block
vrrp_instance VI_1 {
	state MASTER
	interface enp0s8
	virtual_router_id 1
	priority 101
	nopreempt
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass foo
	}
	virtual_ipaddress {
		192.168.200.33/24 dev enp0s8
	}
}
 
; Virtual Server Configureation Block
virtual_server 192.168.200.33 80 {
	delay_loop 6
	lvs_sched rr
	lvs_method DR
	persistence_timeout 50
	protocol TCP
	sorry_server 192.168.200.254 80
	real_server 192.168.200.102 80 {
		weight 1
		inhibit_on_failure
		HTTP_GET {
			url {
				path /
				status_code 200
			}
			connect_timeout 3
			nb_get_retry 3
			delay_before_retry 3
		}
	}
	real_server 192.168.200.103 80 {
		weight 1
		inhibit_on_failure
		HTTP_GET {
			url {
				path /
				status_code 200
			}
			connect_timeout 3
			nb_get_retry 3
			delay_before_retry 3
		}
	}
}
```

For the backup
```
; Common Configuration Block
global_defs {
	notification_email {
		alert@lsaa.lab
	}
	notification_email_from lb2@lsaa.lab
	smtp_server mail.lsaa.lab
	smtp_connect_timeout 30
	router_id lb2.lsaa.lab
}
 
; Master Configureation Block
vrrp_instance VI_1 {
	state BACKUP
	interface enp0s8
	virtual_router_id 1
	priority 100
	nopreempt
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass foo
	}
	virtual_ipaddress {
		192.168.200.33/24 dev enp0s8
	}
}
 
; Virtual Server Configureation Block
virtual_server 192.168.200.33 80 {
	delay_loop 6
	lvs_sched rr
	lvs_method DR
	persistence_timeout 50
	protocol TCP
	sorry_server 192.168.200.254 80
	real_server 192.168.200.102 80 {
		weight 1
		inhibit_on_failure
		HTTP_GET {
			url {
				path /
				status_code 200
			}
			connect_timeout 3
			nb_get_retry 3
			delay_before_retry 3
		}
	}
	real_server 192.168.200.103 80 {
		weight 1
		inhibit_on_failure
		HTTP_GET {
			url {
				path /
				status_code 200
			}
			connect_timeout 3
			nb_get_retry 3
			delay_before_retry 3
		}
	}
}
```

Start `keepalived`
```
sudo systemctl enable --now keepalived
```

Tweak the following kernel parameters
```
sudo sysctl -w net.ipv4.conf.all.rp_filter=0
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p
```

Edit `/etc/default/ipvsadm`
```
# ipvsadm

# if you want to start ipvsadm on boot set this to true
AUTO="true"

# daemon method (none|master|backup)
DAEMON="master"

# use interface (eth0,eth1...)
IFACE="enp0s8" # external interface name

# syncid to use 
# (0 means no filtering of syncids happen, that is the default)
# SYNCID="0"
```

Start & enable the service
```
sudo systemctl enable --now ipvsadm
```

Check if the rules appeared (they will be applied automatically by keepalived)
```
sudo ipvsadm -Ln
```

To disable persistence, remove the following line from the `keepalived` configuration on both LVS cluster servers
```
persistence_timeout 50
```

## HAProxy

[Lab environment (part2)](./part2/Vagrantfile)

To prevent getting the LB IP Address in the logs, replace (line 213) in `/etc/apache2/apache2.conf` with

```
LogFormat "\"%{X-Forwarded-For}i\" %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
```

Restart apache
```
sudo systemctl restart apache2
```

### HAProxy Installation & Configuration

Install
```
sudo apt-get update
sudo apt-get install haproxy
```

Adjust the configuration file `/etc/haproxy/haproxy.cfg`

Add this to the end of the file
```
frontend http-in
    bind *:80
    default_backend   web_servers
    option   forwardfor

backend web_servers
   balance   roundrobin
   server    m2 <ip-address-m2>:80 check
   server    m3 <ip-address-m3>:80 check

```

Configure the `rsyslog` daemon to capture the logs from `haproxy`
*Install rsyslog if not present*

In  `/etc/rsyslog.conf`
Uncomment the lines (16 and 17) about imudp
And add
```
$AllowedSender UDP, 127.0.0.1
```

Restart `rsyslog`  & `haproxy`
```
sudo systemctl restart rsyslog
sudo systemctl restart haproxy
```

# Failover Clusters

## Basic Scenario 

[Lab environment (part4)](./part4/Vagrantfile)

- **Pacemaker** - a high-availability cluster resource manager [link](https://clusterlabs.org/pacemaker/)
- **Corosync** - a cluster membership layer (i.e. manages membership & communication within the cluster)

Create an apache server status endpoint `/etc/apache2/sites-available/server-status.conf` (on both machines)
```
<Location /server-status>
    SetHandler server-status
    Require local
</Location>
```

Enable the configuration
```
sudo a2ensite server-status.conf
```

Reload the Apache service 
```
sudo systemctl reload apache2
```

Install the Pacemaker packages
```
sudo apt-get install pacemaker pcs
```

Check if the `hacluster` user has been created
```
grep hacluster /etc/passwd
```

Set its password to use it
```
sudo passwd hacluster
```

Remove the file 
```
sudo rm /etc/corosync/corosync.conf
```

Authenticate the node(s) using the `hacluster` user & password
```
Authorize among the nodes
sudo pcs host auth 192.168.200.100 192.168.200.101
```

Once the authorization is successful, generate the cluster configuration
```
sudo pcs cluster setup demo 192.168.200.100 192.168.200.101 --force 
```

Start the cluster
```
sudo pcs cluster start --all
```

Enable cluster auto-start
```
sudo pcs cluster enable --all
```

Check the status of the cluster
```
sudo pcs cluster status

Cluster Status:
 Status of pacemakerd: 'Pacemaker is running' (last updated 2024-03-07 14:15:39 +02:00)
 Cluster Summary:
   * Stack: corosync
   * Current DC: 192.168.200.100 (version 2.1.5-a3f44794f94) - partition with quorum
   * Last updated: Thu Mar  7 14:15:39 2024
   * Last change:  Thu Mar  7 14:15:29 2024 by hacluster via crmd on 192.168.200.100
   * 2 nodes configured
   * 0 resource instances configured
 Node List:
   * Online: [ 192.168.200.100 192.168.200.101 ]

PCSD Status:
  192.168.200.100: Online
  192.168.200.101: Online
```

Check the properties of the cluster
```
sudo pcs property list --all
```
Get list of the available resource providers
```
sudo pcs resource providers
```

Retrieve the list of all resource agents
```
sudo pcs resource agents
```

Narrow down the agents to a particular provider
```
sudo pcs resource agents ocf:heartbeat
```

Disable stonith (just for this scenario)
```
sudo pcs property set stonith-enabled=false
```


Define a resource (a virtual IP to serve as the endpoint for external clients)
```
sudo pcs resource create clha_ip ocf:heartbeat:IPaddr2 ip=<virtual-ip-address> cidr_netmask=24 op monitor interval=30s
```


Another resource to manage the apache service
```
sudo pcs resource create clha_web ocf:heartbeat:apache configfile=/etc/apache2/apache2.conf statusurl="http://localhost/server-status" op monitor interval=1min
```

Check the status
```
sudo pcs status
```

The resources might be started on different nodes, which isn't what we want

Define constraint to guarantee that both resource will be moved around together
```
sudo pcs constraint colocation add clha_web with clha_ip INFINITY
```

Try and stop one of the nodes to test the failover
```
sudo pcs cluster stop 192.168.200.100
```

## Pacemaker + LVM

## Pacemaker + LVM + NFS:ex

