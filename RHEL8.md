# Configure Local DVD Repository for RHEL 8.4
> This method to setup RHEL 8.4 as a server repository to collect some many or spesific packages from Ubuntu 20.04, RHEL 8.4, Centos Stream 9, and Centos Stream 8 repository.

1. I used RHEL 8.4 as a server repository. Firstly, access [this link](https://archive.org/download/rhel-8.4-x86_64-resources) and select **Red Hat Enterprise Linux 8.4 Binary DVD**

2. Then, create a VM or instance used RHEL 8.4 image. This setup will using graphical console client to display desktop of RHEL 8.4
   > ### Important
   > You must enable the ethernet connection in setup mode as it will connect your VM to internet and provide an ipv4 address.

3. Alright I think you completed setup a RHEL 8.4 VM. Next, inject the RHEL iso to the DVD media

4. Mount the RHEL binary DVD iso to a directory such as `/mnt/iso`
   ```bash
   sudo mkdir /mnt/iso
   ```
   ```bash
   lsblk

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
   sudo mount /dev/sr0 /mnt/iso
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
   sudo firewall-cmd --state; firewall-cmd --get-default-zone

   # List service in default zone, example public
   sudo firewall-cmd --list-all --zone=public 

   # Add service and port into zone
   sudo firewall-cmd --add-service={http,https} --zone=public --permanent; sudo firewall-cmd --add-port={80,443}/tcp --zone=public --permanent; sudo firewall-cmd --reload; sudo firewall-cmd --list-all --zone=public

   # Expected output 
   public (active)
     target: default
     icmp-block-inversion: no
     interfaces: enp1s0
     sources: 
     services: cockpit dhcpv6-client http https ssh
     ports: 22/tcp 443/tcp 8989/tcp
     protocols: 
     masquerade: no
     forward-ports: 
     source-ports: 
     icmp-blocks: 
     rich rules: 
   ```

7. Add port 80 and 443 into **http_port_t** object
   ```bash
   sudo semanage port -at http_port_t -p tcp 80; sudo semanage port -at http_port_t -p tcp 443; sudo semanage port -l | grep http_port_t
   ```

8. Then, add the **httpd_sys_content_t** object context for /var/www/html directory
   ```bash
   sudo semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"; restorecon -R -v /var/www/html; ls -Z /var/www/html
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
    ```repo
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
    ```

12. Copy content from RHEL 8.4 DVD ISO directory to `/var/www/html`
    ```bash
    cp -avr /mnt/iso/ /var/www/html/
    ``` 

13. Clear the cache and check whether you are able to get the packages from this DVD repository
    ```bash
    dnf clean all; dnf repolist

    # Output
    Updating Subscription Management repositories.
    repo id                                      repo name
    appstream                                    AppStream Packages
    baseos                                       BaseOS Packages
    ```

14. Verify with update, download package, or go to local repo site
    ```bash
    dnf update; dnf install <package-name>
    ```
    ```bash
    dnf info <package-name>

    # Output
    --- omitted ---

    From repo    : AppStream
    
    --- omitted ---
    ```
    ```bash
    curl -I <server repository ipv4>

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


# Reference
- https://access.redhat.com/solutions/6913101
- https://access.redhat.com/solutions/7019225
- https://access.redhat.com/solutions/3418871