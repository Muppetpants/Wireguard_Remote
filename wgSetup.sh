#!/bin/bash

#Description: Run script on a pi to create a VPS (deb/ubuntu) callback through wireguard
#Usuage: Run as root, include full path to wireguard conf as first argument (sudo ./WG-callback.sh)

#Check root
if [ "${EUID}" -ne 0 ]; then
	echo "You need to run this script as root"
	exit 1
fi

#Gather vars
read -p "What adapter will the Pi access the Internet? " WG_ADAP
read -p "What is full path to Wireguard conf file? " WG_CONF
echo ""

#Confirm vars
echo "Pi accesses Internet with following adapter: $WG_ADAP"
echo "Path to Wireguard conf file: $WG_CONF"
echo ""

read -n 1 -r -s -p $'Press enter to continue if the values above are correct. Otherwise "Ctrl + c" to reenter...\n'


#Install and copy client conf
apt update
apt install wireguard resolvconf -y

cp ${WG_CONF} /etc/wireguard/wg0.conf
rm ${WG_CONF}
  


#Configure NAT
mkdir /etc/nftables.d

sudo tee -a /etc/nftables.d/nat.conf << EOF
#nat.conf
table ip nat {
        chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
        }

        chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                oifname "${WG_ADAP}" masquerade
        }
}
EOF


mv /etc/nftables.conf /etc/nftables.conf.bak
sudo tee -a /etc/nftables.conf << EOF 
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
        chain input {
                type filter hook input priority 0;
        }
        chain forward {
                type filter hook forward priority 0;
        }
        chain output {
                type filter hook output priority 0;
        }
}

include "/etc/nftables.d/*.conf"
EOF


echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-sysctl.conf

# Enable and restart services
systemctl start wg-quick@wg0.service
systemctl enable wg-quick@wg0.service
systemctl enable nftables


#Reboot
reboot
