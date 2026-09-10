# Linux Cheatsheet (Fedora / systemd)

These are standard across Fedora, Debian, Ubuntu, Arch, SUSE.
systemd won. These tools are the same everywhere now.

## Network

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| Show IP addresses       | `ifconfig`                   | `ip a`                             |
| Show one interface      | `ifconfig eth0`              | `ip a show enp1s0f0`              |
| Bring interface up      | `ifup eth0`                  | `nmcli con up enp1s0f0`           |
| Wifi networks           |                              | `nmcli device wifi list`           |
| Connection status       |                              | `nmcli device status`              |
| DNS lookup              | `nslookup`                   | `dig` or `resolvectl query`        |
| Listening ports         | `netstat -tlnp`              | `ss -tlnp`                         |
| Open connections        | `netstat -tnp`               | `ss -tnp`                          |
| All sockets             | `netstat -a`                 | `ss -a`                            |
| Wifi radio on/off       |                              | `nmcli radio wifi off`             |
| Radio status            |                              | `rfkill list`                      |
| Block radio             |                              | `rfkill block wifi` / `bluetooth`  |

### Linux vs Mac

| Task                    | Old                  | New                  | Mac                                |
|-------------------------|----------------------|----------------------|------------------------------------|
| Interface info          | `ifconfig eth0`      | `ip a show enp1s0f0` | `ifconfig en0`                     |
| Just the IP             |                      | `hostname -I`        | `ipconfig getifaddr en0`           |
| Listening ports         | `netstat -tlnp`      | `ss -tlnp`           | `lsof -iTCP -sTCP:LISTEN -nP`      |
| Open connections        | `netstat -tnp`       | `ss -tnp`            | `lsof -iTCP -nP`                   |
| DNS lookup              | `nslookup`           | `dig`                | `dig [@dns] hostname [A] [+short]` |

## Services (systemd)

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| Start a service         | `service httpd start`        | `systemctl start httpd`            |
| Stop a service          | `service httpd stop`         | `systemctl stop httpd`             |
| Service status          | `service httpd status`       | `systemctl status httpd`           |
| Enable at boot          | `chkconfig httpd on`         | `systemctl enable httpd`           |
| Enable and start now    |                              | `systemctl enable --now httpd`     |
| Disable at boot         | `chkconfig httpd off`        | `systemctl disable httpd`          |
| All running services    | `chkconfig --list`           | `systemctl list-units -t service`  |
| What failed?            |                              | `systemctl --failed`               |
| Unit stuck "start-limit-hit"    |                      | `systemctl reset-failed <unit>`    |

## Logs (journalctl)

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| Read service logs       | `tail /var/log/messages`     | `journalctl -u httpd`              |
| Follow logs live        | `tail -f /var/log/messages`  | `journalctl -fu httpd`             |
| Logs since boot         |                              | `journalctl -b`                    |
| Logs since 1 hour ago   |                              | `journalctl --since "1 hour ago"`  |
| Kernel messages         | `dmesg`                      | `journalctl -k` (dmesg still works)|

## Firewall (firewalld)

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| List rules              | `iptables -L`                | `firewall-cmd --list-all`          |
| Open a service          |                              | `firewall-cmd --permanent --add-service=http` |
| Open a port             |                              | `firewall-cmd --permanent --add-port=8123/tcp` |
| Apply changes           |                              | `firewall-cmd --reload`            |
| Active zones            |                              | `firewall-cmd --get-active-zones`  |

## Packages (dnf5, Fedora 41+)

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| Search for package      | `yum search foo`             | `dnf search foo`                   |
| Install                 | `yum install foo`            | `dnf install foo`                  |
| Remove                  | `rpm -e foo`                 | `dnf remove foo`                   |
| List installed          | `rpm -qa \| grep foo`        | `dnf list --installed 'foo*'`      |
| What owns a file?       | `rpm -qf /usr/bin/foo`       | `rpm -qf /usr/bin/foo` (unchanged) |
| Update all              | `yum update`                 | `dnf update`                       |
| List available updates  |                              | `dnf check-update`                 |
| Package info            | `rpm -qi foo`                | `dnf info foo`                     |

Note: `rpm -qa | grep foo` still works fine. dnf5 changed `list installed`
to `list --installed` and patterns go as arguments, not through grep.

## Misc

| Task                    | Old                          | New                                |
|-------------------------|------------------------------|------------------------------------|
| Current kernel          |                              | `uname -r`                         |
| Installed kernels       |                              | `rpm -qa kernel-core`              |
| Kernel update check     |                              | `rpm -q kernel`                    |
| Third-party kmods       |                              | `rpm -qa \| grep akmod`            |
| Reboot                  | `shutdown -r now`            | `systemctl reboot`                 |
| Shutdown                | `shutdown -h now`            | `systemctl poweroff`               |
| Disk usage              | `df -h`                      | `df -h` (unchanged)               |
| Block devices           |                              | `lsblk`                           |
| USB devices             |                              | `lsusb`                           |
| PCI devices (hardware)  |                              | `lspci -nnk`                      |
