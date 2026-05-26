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
   mkdir /mnt/iso
   ```
   ```bash
   lsblk
   ```

   ```bash
   # Output
   NAME          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT                                                                                                                
   sr0            11:0    1  9.4G  0 rom
   vda           252:0    0   25G  0 disk 
   ├─vda1        252:1    0    1G  0 part /boot
   └─vda2        252:2    0   24G  0 part 
     ├─rhel-root 253:0    0 21.5G  0 lvm  /
     └─rhel-swap 253:1    0  2.5G  0 lvm  [SWAP]
   ```
   ```bash
   mount /dev/sr0 /mnt/iso
   ```
   > ### Note
   > The Warning mount: /mnt/iso: WARNING: source write-protected, mounted read-only. is expected.

5. Make sure you've installed the HTTP web server package, either httpd or nginx. I used nginx btw
   ```bash
   dnf list --installed | grep nginx
   ```
   ```bash
   systemctl status nginx
   ```

6. Configure to firewall to allow service https and http and also port 80 and 443
   ```bash
   # Check state and default zone
   firewall-cmd --state; firewall-cmd --get-default-zone
   ```
   ```bash
   # List service in default zone, example public
   firewall-cmd --list-all --zone=public 
   ```
   ```bash
   # Add service and port into zone
   firewall-cmd --add-service={http,https} --zone=public --permanent; firewall-cmd --add-port={80,443}/tcp --zone=public --permanent; firewall-cmd --reload; firewall-cmd --list-all --zone=public
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

7. Add port 80 and 443 into **http_port_t** object
   ```bash
   semanage port -at http_port_t -p tcp 80; semanage port -at http_port_t -p tcp 443; semanage port -l | grep http_port_t
   ```

8. Then, add the **httpd_sys_content_t** object context for /var/www/html directory
   ```bash
   semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"; restorecon -R -v /var/www/html; ls -Z /var/www/html
   ```

9.  Make sure the port and directory for displaying the repository packages are correct, such as the nginx configuration inside `/etc/nginx/nginx.conf`.
    ```conf
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

10. And also check state of nginx service
    ```bash
    systemctl status nginx
    ```
    > ### Note
    > Nginx service must active and enabled.

11. Create the repository file with the correct path where the DVD or ISO is mounted. But, I will using `/var/www/html` as a local repository root path.
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

12. Copy content from RHEL 8.4 DVD ISO directory to `/var/www/html`
    ```bash
    cp -avr /mnt/iso/ /var/www/html/
    ``` 

13. Clear the cache and check whether you are able to get the packages from this DVD repository
    ```bash
    dnf clean all; dnf repolist
    ```
    ```bash
    # Output
    Updating Subscription Management repositories.
    repo id                           repo name
    appstream                         AppStream Packages
    baseos                            BaseOS Packages
    ```

14. Verify with update, download package, or go to local repo site
    ```bash
    dnf update; dnf install <package-name>
    ```
    ```bash
    dnf info <package-name>
    ```
    ```bash
    # Output
    --- omitted ---
    From repo    : AppStream
    ```
    ```bash
    curl -I <server repository ipv4>
    ```
    ```bash
    # Output
    HTTP/1.1 200 OK
    Server: nginx/1.14.1
    Date: Sat, 16 May 2026 06:34:34 GMT
    Content-Type: text/html
    Connection: keep-alive
    ```
    ```bash
    # Check hit access server repo
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

2. For example, I wanna provide **httpd** package for CentOS stream 9. Create repo file for CentOS stream 9 and disable main repository temporarily
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
   ```bash
   mv /etc/yum.repos.d/local.repo /etc/yum.repos.d/local.repo.backup
   ```
   ```bash
   dnf clean all; dnf repolist; mkdir -p /var/www/html/centos9/package; cd /var/www/html/centos9/package
   ```
   > ### Notes
   > Make sure only repo id **centos9-baseos** and **centos9-appstream** loaded
   ```bash
   dnf download --resolve --alldeps httpd
   ```
   > ### Notes
   > You also can download **docker** packages :v
   ```bash
   dnf download --resolve --alldeps docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```

3. Run command `createrepo` to creates a repomd (xml-based rpm metadata) repository from a set of rpms
   ```bash
   createrepo /var/www/html/centos9/package
   ```
   > ### Notes
   > If you add some package, run this command again and add `--update` option

4. Verifying **httpd** package and the dependencies downloaded. The result are several **.rpm** file

5. Activate main repository and now disable centos9 repository
   ```bash
   mv /etc/yum.repos.d/local.repo.backup /etc/yum.repos.d/local.repo; mv /etc/yum.repos.d/centos9.repo /etc/yum.repos.d/centos9.repo.backup
   ```

6. Add multiple line configuration for the CentOS stream 9 inside main repository
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

7. Make sure if new repo for CentOS stream 9 ready to use
   ```bash
   dnf clean all; dnf repolist
   ```
   ```bash
   curl -I <server repository ipv4>
   ```
   ```bash
   # Output
   HTTP/1.1 200 OK
   Server: nginx/1.14.1
   Date: Sat, 16 May 2026 06:34:34 GMT
   Content-Type: text/html
   Connection: keep-alive
   ```

# Setup CentOS stream 9 as a Client Repository
1. Change to superuser and configure new file repository
   ```bash
   sudo -i
   ```
   ```bash
   mv /etc/yum.repos.d/centos-addons.repo /etc/yum.repos.d/centos-addons.repo.backup; mv /etc/yum.repos.d/centos.repo /etc/yum.repos.d/centos.repo.backup
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
   dnf clean all; dnf repolist
   ```
   ```bash
   # Expected result
   repo id                          repo name
   local-repo                       local repo rhel8
   ```
   ```bash
   dnf update; dnf info <package_name>
   ```
   ```bash
   # Expected result
   --- omitted ---
   From repo    : local-repo
   ```
   ```bash
   dnf install <package_name> -y
   ```

# Reference
- https://access.redhat.com/solutions/6913101
- https://access.redhat.com/solutions/7019225
- https://access.redhat.com/solutions/3418871