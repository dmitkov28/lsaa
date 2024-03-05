# Apache

## Installation

Install
```
sudo apt-get update
sudo apt-get install apache2
```

Run 
```
sudo systemctl enable --now apache2
```


## Configuration

The main config file is in `/etc/apache2/apache2.conf`
The default virtual host config is in ` /etc/apache2/sites-available/000-default.conf`

To test the configuration, run
```
sudo apachectl configtest
```

### Virtual Hosts

Can be added to `/etc/apache2/sites-available/`

#### By Port

An example config for a virtual host listening on 8080 (`/etc/apache2/sites-available/001-vhost-port.conf`):

```
Listen 8080
<VirtualHost *:8080>
    DocumentRoot /var/www/vhost-port
    ServerName m1.lsaa.lab # optional
</VirtualHost>

```

Enable it with:
```
sudo a2ensite 001-vhost-port.conf
sudo systemctl reload apache2
```

#### By name

An example config for a named virtual host (`/etc/apache2/sites-available/002-vhost-name.conf`):

```
Listen 80
<VirtualHost *:80>
    DocumentRoot /var/www/vhost-name
    ServerName www.demo.lab # required (also, ensure some kind of name resolution)
</VirtualHost>

```

Enable it with:
```
sudo a2ensite 002-vhost-name.conf
sudo systemctl reload apache2
```

### TLS/SSL

#### Self-signed certificates

Install
```
sudo apt-get update
sudo apt-get install openssl
```
Generate the private key
```
openssl genrsa -out ca.key 2048
```

Create a certificate signing request (CSR)
```
openssl req -new -key ca.key -out ca.csr
```

Generate the self-signed certificate
```
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt
```

Check
```
openssl x509 -text -in ca.crt
```

Copy the files to the appropriate folders
```
sudo cp ca.crt /etc/ssl/certs/ca.crt
sudo cp ca.key /etc/ssl/private/ca.key
sudo cp ca.csr /etc/ssl/private/ca.csr
```

Enable ssl in apache & restart the service
```
sudo a2enmod ssl
sudo systemctl restart apache2
```

Create an SSL enabled virtual host (`sudo vi /etc/apache2/sites-available/000-default-ssl.conf`)
```
<IfModule mod_ssl.c>
        <VirtualHost _default_:443>
                ServerAdmin webmaster@localhost
                DocumentRoot /var/www/html
                ErrorLog ${APACHE_LOG_DIR}/error.log
                CustomLog ${APACHE_LOG_DIR}/access.log combined
                SSLEngine on
                SSLCertificateFile      /etc/ssl/certs/ca.crt
                SSLCertificateKeyFile /etc/ssl/private/ca.key
                <FilesMatch "\.(cgi|shtml|phtml|php)$">
                                SSLOptions +StdEnvVars
                </FilesMatch>
                <Directory /usr/lib/cgi-bin>
                                SSLOptions +StdEnvVars
                </Directory>
        </VirtualHost>
</IfModule>
```

Enable
```
sudo a2ensite 000-default-ssl.conf
```

#### Firewall

```
sudo ufw allow "Apache Secure"
```

To redirect http to https, add this to a virtual hosts's config file:
```
RewriteEngine on
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

And enable the module
```
sudo a2enmod rewrite
sudo systemctl restart apache2
```

### Reverse Proxy

*Prepare a second machine to act as the apache server (machine_2)*

Enable the proxy module
```
sudo a2enmod proxy
sudo a2enmod proxy_http
```

Create a configuration for the reverse proxy module (`/etc/apache2/conf-available/reverse-proxy.conf`)

```
<IfModule mod_proxy.c>
    ProxyRequests Off
    <Proxy *>
        Require all granted
    </Proxy>
    ProxyPass / 192.168.200.101
    ProxyPassReverse / 192.168.200.101
</IfModule>
```

Enable the conf
```
sudo a2enconf reverse-proxy
```

Restart apache
```
sudo systemctl restart apache2
```

### Load Balancer

*Ideally, use machine_2 & machine_3 to both act as backend servers*

Modify `/etc/apache2/conf-available/reverse-proxy.conf`:
```
<IfModule mod_proxy.c>
ProxyRequests Off
<Proxy *>
    Require all granted
</Proxy>
ProxyPass / balancer://demo/
ProxyPassReverse / balancer://demo/                                                                                                
<Proxy balancer://demo>
    BalancerMember http://192.168.200.101
    BalancerMember http://192.168.200.102
    ProxySet lbmethod=bytraffic
    </Proxy>
</IfModule>
```

Enable the modules
```
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_bytraffic
sudo systemctl restart apache2
```

# Nginx

## Installation

Install
```
sudo apt-get update
sudo apt-get install -y nginx
```



## Configuration

The config file is under `/etc/nginx/nginx.conf`
The default host config is under `/etc/nginx/sites-available/default`

Test with
```
nginx -t
```

### Virtual Hosts

#### By port

Create `/etc/nginx/sites-available/vhost-port.conf`
```
server {
  listen 8080;

  location / {
    root /var/www/vhost-port;
    index index.html;
  }
}
```

Enable
```
sudo ln -s /etc/nginx/sites-available/vhost-port.conf /etc/nginx/sites-enabled/
```

Restart nginx
```
sudo systemctl restart nginx
```

#### By name

Create ` /etc/nginx/sites-available/vhost-name.conf`
```
server {
  listen 80;
  server_name www.demo.lab;

  location / {
    root /var/www/vhost-name;
    index index.html;
  }
}
```

Enable
```
sudo ln -s /etc/nginx/sites-available/vhost-name.conf /etc/nginx/sites-enabled/
```

Restart nginx
```
sudo systemctl restart nginx
```



### TLS/SSL

Create a self-signed certificate [See above](#self-signed-certificates)

Distribute the files
```
sudo cp ca.crt /etc/nginx/ca.crt
sudo cp ca.key /etc/nginx/ca.key
sudo cp ca.csr /etc/nginx/ca.csr
```

Edit `/etc/nginx/sites-available/default` by uncommenting lines (27-28)

Add the location of the certs below:
```
ssl_certificate /etc/nginx/ca.crt; 
ssl_certificate_key /etc/nginx/ca.key;
```

#### Firewall
```
sudo ufw allow "Nginx HTTPS"
```

### Reverse Proxy

Edit `/etc/nginx/sites-enabled/default`

Right below `root /var/www/html`
```
proxy_redirect   off;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header Host $http_host;

```

Add this to the `location` block
```
proxy_pass http://192.168.200.101;
```


### Load Balancer

Change `/etc/nginx/sites-enabled/default`

Right below root (to allow the original ip to pass through)
```
set_real_ip_from    0.0.0.0/0;   # or a different subnet 192.168.81.0/24
real_ip_header      X-Forwarded-For;

```

Add the following to `/etc/nginx/sites-enabled/default` (before the first server section)
```
upstream backend {
    server 192.168.200.101;
    server 192.168.200.102;                                                          
}
```

Change the proxy_pass in the location (`/etc/nginx/sites-enabled/default`)
```
proxy_pass http://backend;

```
