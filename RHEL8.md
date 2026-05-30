# List of contents
- [List of contents](#list-of-contents)
- [Configure Local DVD Repository for RHEL 8.4](#configure-local-dvd-repository-for-rhel-84)
- [Configure RHEL 8.4 as a Server Repository](#configure-rhel-84-as-a-server-repository)
  - [Provide CentOS stream 9 packages](#provide-centos-stream-9-packages)
  - [Provide Ubuntu 20.04 LTS packages](#provide-ubuntu-2004-lts-packages)
- [Setup CentOS stream 9 as a Client Repository](#setup-centos-stream-9-as-a-client-repository)
- [Setup Ubuntu 20.04 LTS as a Client Repository](#setup-ubuntu-2004-lts-as-a-client-repository)
- [Reference](#reference)

# Configure Local DVD Repository for RHEL 8.4
> This method to setup RHEL 8.4 as a server repository to collect some many or spesific packages from Ubuntu 20.04, RHEL 8.4, Centos Stream 9, and Centos Stream 8 repository.
> ### Notes
> Change to superuser
> ```bash
> sudo -i
> ```

1. I used RHEL 8.4 as a server repository. Firstly, access [this link](https://archive.org/download/rhel-8.4-x86_64-resources) and select **Red Hat Enterprise Linux 8.4 Binary DVD**

2. Then, create a VM or instance used RHEL 8.4 image. This setup will using graphical console client to display desktop of RHEL 8.4
   > ### Important
   > You must enable the ethernet connection in setup mode as it will connect your VM to internet and provide an ipv4 address.

3. Alright I think you completed setup a RHEL 8.4 VM. Next, inject the RHEL iso to the DVD media

4. Mount the RHEL binary DVD iso to a directory such as `/mnt/iso`
   ```bash
   bash << EOF
   mkdir /mnt/iso
   lsblk
   mount /dev/sr0 /mnt/iso
   EOF
   ```
   > ### Note
   > The Warning mount: /mnt/iso: WARNING: source write-protected, mounted read-only. is expected.

5. Make sure you've installed the HTTP web server, either httpd or nginx. I used nginx btw
   ```bash
   bash << EOF
   dnf list --installed | grep nginx
   systemctl enable --now nginx
   systemctl status nginx
   EOF
   ```

6. Configure firewall to allow service **https** and **http** also port **80** and **443**
   ```bash
   # Check state of default zone, list current service, and add service and port into zone
   bash << EOF
   firewall-cmd --state
   firewall-cmd --get-default-zone
   firewall-cmd --list-all --zone=public
   firewall-cmd --add-service={http,https} --zone=public --permanent
   firewall-cmd --add-port={80,443}/tcp --zone=public --permanent
   firewall-cmd --reload
   firewall-cmd --list-all --zone=public
   EOF
   ```
   ```bash
   # Expected output 
   public (active)
     target: default
     icmp-block-inversion: no
     interfaces: enp1s0
     sources: 
     services: cockpit dhcpv6-client http https ssh
     ports: 22/tcp 443/tcp 80/tcp
     protocols: 
     masquerade: no
     forward-ports: 
     source-ports: 
     icmp-blocks: 
     rich rules: 
   ```

7. Add port 80 and 443 into **http_port_t** object selinux
   ```bash
   bash << EOF
   semanage port -l | grep -w http_port_t
   semanage port -at http_port_t -p tcp 80
   semanage port -at http_port_t -p tcp 443
   semanage port -l | grep -w http_port_t
   EOF
   ```

8. Then, add the **httpd_sys_content_t** object context for `/var/www/html` directory
   ```bash
   bash << EOF
   semanage fcontext -l | grep -w httpd_sys_content_t | grep "www/html"
   semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"
   restorecon -Rv /var/www/html
   ls -Z /var/www/html
   EOF
   ```

9.  Make sure the port and directory for displaying the repository packages are correct, verify the nginx configuration inside `/etc/nginx/nginx.conf`.
    ```bash
    # Go to this line
        server {
            listen       80 default_server;
            listen       [::]:80 default_server;

            server_name  _;
            root         /var/www/html;

            # Load configuration files for the default server block.
            include /etc/nginx/default.d/*.conf;

            location / {
                    autoindex on;
                    autoindex_exact_size off;
                    autoindex_localtime on;
            }

            error_page 404 /404.html;
                location = /40x.html {
            }

            error_page 500 502 503 504 /50x.html;
                location = /50x.html {
            }
    ```

10. Check state of nginx service
    ```bash
    systemctl status nginx
    ```
    > ### Note
    > Nginx service must active and enabled.

11. Create the repository config file and pointing to the path of repository on web server. I using `/var/www/html` path as a local repository root path.
    > ### Note
    > Configure on your RHEL 8.4 VM
    ```bash
    cat << EOF > /etc/yum.repos.d/local.repo
    [baseos]
    name=BaseOS Packages
    metadata_expire=-1
    gpgcheck=1
    enabled=1
    baseurl=file:///var/www/html/BaseOS/
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
    
    [appstream]
    name=AppStream Packages
    metadata_expire=-1
    gpgcheck=1
    enabled=1
    baseurl=file:///var/www/html/AppStream/
    gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
    EOF
    ```

12. Copy local packages from RHEL 8.4 DVD ISO directory to `/var/www/html`
    ```bash
    cp -avr /mnt/iso/ /var/www/html/
    ``` 

13. Clear the cache and check whether you are able to get the packages from this DVD repository
    ```bash
    bash << EOF
    dnf clean all
    dnf repolist
    EOF
    ```
    ```bash
    # Expected output
    Updating Subscription Management repositories.

    repo id                           repo name
    appstream                         AppStream Packages
    baseos                            BaseOS Packages
    ```

14. Verify with update, download package, or go to local repo site
    ```bash
    bash << EOF
    dnf update
    dnf install <package-name>
    dnf info <package-name>
    EOF
    ```
    ```bash
    # Expected output

    --- omitted ---
    From repo    : <your repo_id or repo_name>
    ```
    ```bash
    curl -I <server repository ipv4>
    ```
    ```bash
    # Expected output

    HTTP/1.1 200 OK
    Server: nginx/1.14.1
    Date: Sat, 16 May 2026 06:34:34 GMT
    Content-Type: text/html
    Connection: keep-alive
    ```
    ```bash
    # Check the hit access to server repo
    tail -f /var/log/nginx/access.log
    ```

# Configure RHEL 8.4 as a Server Repository
> ### Notes
> Change to superuser
> ```bash
> sudo -i
> ```

1. The first step to collecting and synchronizing multiple packages from multiple OS distros is to register your RHEL subscription
   ```bash
   subscription-manager register --username rhel84 --password s3rv3rR3p0s1t0ry
   ```

## Provide CentOS stream 9 packages
1. For example, I wanna serving **httpd** package for CentOS stream 9. Create repo file for CentOS stream 9 and disable main repository temporarily
   ```bash
   cat << EOF > /etc/yum.repos.d/centos9.repo
   name=CentOS 9 BaseOS
   baseurl=https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/
   enabled=1
   gpgcheck=0
   
   [centos9-appstream]
   name=CentOS 9 AppStream
   baseurl=https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/
   enabled=1
   gpgcheck=0
   
   [centos9-docker]
   name=CentOS 9 Docker
   baseurl=https://download.docker.com/linux/centos/9/x86_64/stable/
   enabled=1
   gpgcheck=0
   EOF
   ```
   > ### Notes
   > Make sure only repo id **centos9-baseos** and **centos9-appstream** loaded

   ```bash
   bash << EOF
   mv /etc/yum.repos.d/local.repo /etc/yum.repos.d/local.repo.backup
   dnf clean all
   dnf repolist
   mkdir -p /var/www/html/centos9/package
   cd /var/www/html/centos9/package
   dnf download --resolve --alldeps httpd
   EOF
   ```

   > ### Notes
   > You can also download **docker** packages :v
   ```bash
   dnf download --resolve --alldeps docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

2. Run command `createrepo` to creates a repomd (xml-based rpm metadata) repository from a set of rpms
   ```bash
   createrepo /var/www/html/centos9/package
   ```
   > ### Notes
   > If you add some package, run this command again and add `--update` option

3. Verifying **httpd** package and the dependencies downloaded. The result are several **.rpm** file

4. Activate main repository and now disable centos9 repository
   ```bash
   bash << EOF
   mv /etc/yum.repos.d/local.repo.backup /etc/yum.repos.d/local.repo
   mv /etc/yum.repos.d/centos9.repo /etc/yum.repos.d/centos9.repo.backup
   EOF
   ```

5. Add multiple line configuration for the CentOS stream 9 inside main repository
   ```bash
   cat << EOF >> /etc/yum.repos.d/local.repo

   # Centos Stream 9 Repo
   [centos9-package]
   name=CentOS 9 package
   metadata_expire=-1
   baseurl=file:///var/www/html/centos9/package/
   enabled=1
   gpgcheck=0
   EOF
   ```

6. Make sure if new repo for CentOS stream 9 ready to use
   ```bash
   bash << EOF
   dnf clean all
   dnf repolist
   EOF
   ```
   ```bash
   curl -I <server repository ipv4>
   ```
   ```bash
   # Expected result

   HTTP/1.1 200 OK
   Server: nginx/1.14.1
   Date: Sat, 16 May 2026 06:34:34 GMT
   Content-Type: text/html
   Connection: keep-alive
   ```

## Provide Ubuntu 20.04 LTS packages
1. There are different ways to serve Ubuntu packages into RHEL 8.4 server repository. Create pool and dists directory
   > ### Notes
   > pool: to store **.deb** packages
   >
   > dists: to store index metadata of packages
   ```bash
   bash << EOF
   cd /var/www/html/
   mkdir -p ubuntu/pool/main/
   mkdir -p ubuntu/dists/focal/main/binary-amd64/
   EOF
   ```

2. Run the **installer.sh** script to download index metadata files and **.deb** packages
   ```bash
   bash << EOF
   chmod +x installer.sh
   ./installer.sh
   EOF
   ```

3. After that, generate below script to recreate index metadata for downloaded packages
   ```bash
   bash << EOF
   chmod +x index_gen.sh
   ./index_gen.sh
   EOF
   ```

4. Update your local repo file
   ```bash
   cat << EOF >> /etc/yum.repos.d/local.repo

   # Ubuntu Focal Repo
   [focal-package]
   name=Focal package
   metadata_expire=-1
   baseurl=file:///var/www/html/ubuntu/focal/package/
   enabled=1
   gpgcheck=0
   EOF
   ```
   ```bash
   dnf repolist 
   ```
   ```bash
   # Expected result

   Updating Subscription Management
   --- omitted ---
   repo id                       repo name
   focal-package                 Focal package
   ```

# Setup CentOS stream 9 as a Client Repository
1. Change to superuser and configure new file repository
   ```bash
   sudo -i
   ```
   ```bash
   bash << EOF
   mv /etc/yum.repos.d/centos-addons.repo /etc/yum.repos.d/centos-addons.repo.backup
   mv /etc/yum.repos.d/centos.repo /etc/yum.repos.d/centos.repo.backup
   EOF
   ```
   ```bash
   cat << EOF > /etc/yum.repos.d/local.repo
   [local-repo]
   name=local repo rhel8
   metadata_expire=-1
   gpgcheck=0
   enabled=1
   baseurl=http://<server repo ipv4>/centos9/package/
   EOF
   ```
   ```bash
   bash << EOF
   dnf clean all
   dnf repolist
   EOF
   ```
   ```bash
   # Expected result

   repo id                          repo name
   local-repo                       local repo rhel8
   ```
   ```bash
   bash << EOF
   dnf update -y
   dnf info <package_name>
   EOF
   ```
   ```bash
   # Expected result

   --- omitted ---
   From repo    : local-repo
   ```
   ```bash
   dnf install <package_name> -y
   ```

# Setup Ubuntu 20.04 LTS as a Client Repository
1. Change to superuser and configure new file repository
   ```bash
   sudo -i
   ```
   ```bash
   cp /etc/apt/sources.list /etc/apt/sources.list.bck
   cat << EOF > /etc/apt/sources.list
   # local repo
   deb [trusted=yes arch=amd64] http://<server repo ipv4>/ubuntu/ focal main
   EOF
   ```
   ```bash
   bash << EOF
   apt clean
   rm -rf /var/lib/apt/lists/*
   apt update -y
   apt info <package_name>
   EOF
   ```
   ```bash
   # Expected result

   --- omitted ---
   APT-Sources: http://<server repo ipv4>/ubuntu focal/main amd64 Packages
   ```
   ```bash
   apt install <package_name> -y
   ```
   ```bash
   # Expected result
   apt list --installed | grep <package_name>
   
   WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
   
   library/unknown,now 1.18.0-0ubuntu1.7 amd64 [installed,automatic]
   <package_name>-common/unknown,now 1.18.0-0ubuntu1.7 all [installed,automatic]
   <package_name>/unknown,now 1.18.0-0ubuntu1.7 all [installed]
   ```

# Reference
- https://access.redhat.com/solutions/6913101
- https://access.redhat.com/solutions/7019225
- https://access.redhat.com/solutions/3418871
- https://cloud.centos.org/centos/
- https://vault.centos.org/
- https://mirror.stream.centos.org/
- https://unix.stackexchange.com/questions/780724/cant-install-rpm-packages-from-offline-mirror-no-available-modular-metadata
- https://archive.ubuntu.com/ubuntu/pool/
- https://archive.ubuntu.com/ubuntu/dists/