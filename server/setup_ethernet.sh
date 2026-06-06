# Bootstrap ethernet at the Mac mini's console.

nmcli device status
iface=$(nmcli device status | awk '/disconnected/ {print $1; exit}')
echo "iface=$iface"   # if wrong, set manually: iface=enp1s0f0

sudo nmcli connection modify $iface ipv4.method auto
sudo nmcli connection modify $iface connection.autoconnect yes
sudo nmcli connection up $iface

# Then from your laptop: make setup
