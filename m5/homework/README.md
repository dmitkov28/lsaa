# Tasks

- Research and create your own LXC template (a distribution of your choice with web server)
    **Solution**

    Inspired by: [https://linuxcontainers.org/distrobuilder/docs/latest/tutorials/use/](https://linuxcontainers.org/distrobuilder/docs/latest/tutorials/use/)

    Install `distrobuilder` [taken from here](https://linuxcontainers.org/distrobuilder/docs/latest/howto/install)
    *distrobuilder requires Golang 1.20 or higher*

    ```
    sudo apt-get install -y golang-go debootstrap rsync gpg squashfs-tools git make
    mkdir -p $HOME/go/src/github.com/lxc/
    cd $HOME/go/src/github.com/lxc/
    git clone https://github.com/lxc/distrobuilder
    cd ./distrobuilder
    sudo make
    ```

    Using the official example from the repo [https://github.com/lxc/distrobuilder/blob/main/doc/examples/ubuntu.yaml](https://github.com/lxc/distrobuilder/blob/main/doc/examples/ubuntu.yaml), the only change needed is to add apache to the list of packages to install. 
    
    For example on line 172:

    ```
    packages:
    manager: apt
    update: true
    cleanup: true
    sets:
    - packages:
        - fuse
        - language-pack-en
        - openssh-client
        - vim
        - apache2
        action: install
    ```

    To build the image, run
    ```
    sudo $HOME/go/bin/distrobuilder build-lxc ubuntu.yaml
    ```

    Create a container
    ```
    sudo lxc-create -n ubuntu -t local -- --metadata meta.tar.xz --fstree rootfs.tar.xz
    ```

    Start the container
    ```
    sudo lxc-start -n ubuntu
    ``` 
<hr/>

-  Create your own Docker image based on CentOS or openSUSE that includes Apache web server and custom index page with some text (for example your SoftUni username) and a picture (of a cat, a dog, or whatever you like) 
    **Solution**

    Dockerfile
    ```
    FROM opensuse/leap:15
    RUN zypper ref && zypper install --no-confirm  apache2
    COPY index.html /srv/www/htdocs/index.html
    EXPOSE 80
    ENTRYPOINT ["apachectl", "-D", "FOREGROUND"]
    ```

    index.html
    ```
    <h1 style="text-align: center">dmitkov</h1>
    <img style="margin: auto"
    src="https://images.unsplash.com/photo-1615789591457-74a63395c990?w=900&auto=format&fit=crop&q=60&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8ZG9tZXN0aWMlMjBjYXR8ZW58MHx8MHx8fDA%3D" />
    ```

    Build the image & run the container
    ```
    docker build -t lsaahw .
    docker run -d -p 8080:80 lsaahw
    ```

<hr/>