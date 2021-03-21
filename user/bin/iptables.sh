# Basic iptables rules
# 
# Keep in mind that the order of rules is important.
# 
# Apply rules temporarily with:
# $ iptables-restore < name-of-rules-file
# 
# For an introduction to iptables, cf.:
# https://opensource.com/article/18/9/linux-iptables-firewalld
# https://www.cyberciti.biz/tips/linux-iptables-4-block-all-incoming-traffic-but-allow-ssh.html
# https://blacksaildivision.com/secure-iptables-rules-centos
# https://upcloud.com/community/tutorials/configure-iptables-ubuntu/
# 
# For more in-depth information, cf.:
# https://www.linode.com/docs/guides/control-network-traffic-with-iptables/
# 
# Basic iptables options:
# 
# -A --append               Add one or more rules to the end of the selected chain.
# -C --check                Check for a rule matching the specifications in the selected chain.
# -D --delete               Delete one or more rules from the selected chain.
# -F --flush                Delete all the rules one-by-one.
# -I --insert               Insert one or more rules into the selected chain as the given rule number.
# -L --list                 Display the rules in the selected chain.
# -n --numeric              Display the IP address or hostname and post number in numeric format.
# -N --new-chain <name>     Create a new user-defined chain.
# -v --verbose              Provide more information when used with the list option.
# -X --delete-chain <name>  Delete the user-defined chain.
# 
# Basic parameters:
# 
# -p, --protocol        The protocol, such as TCP, UDP, etc.
# -s, --source          Can be an address, network name, hostname, etc.
# -d, --destination     An address, hostname, network name, etc.
# -j, --jump            Specifies the target of the rule; i.e. what to do if the packet matches.
# -g, --goto chain      Specifies that the processing will continue in a user-specified chain.
# -i, --in-interface    Names the interface from where packets are received.
# -o, --out-interface   Name of the interface by which a packet is being sent.

*filter

# Flush all rules and delete all chains for a clean startup

-F
-X 

# Zero out all counters

-Z

# Allow loopback interface (lo0) and drop all traffic to 127/8 that doesn't use lo0

-A INPUT  -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT
-A INPUT  -d 127.0.0.0/8 -j REJECT
-A OUTPUT -d 127.0.0.0/8 -j REJECT

# Keep all established connections

-A INPUT  -m state --state RELATED,ESTABLISHED -j ACCEPT
-A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Accept all traffic coming from & going to an IP within the 
# private address range (= local IP).
# 
# Cf.:
# https://www.auvik.com/franklyit/blog/special-ip-address-ranges/

-A INPUT -s 10.0.0.0/8     -j ACCEPT
-A INPUT -s 172.16.0.0/12  -j ACCEPT
-A INPUT -s 192.168.0.0/16 -j ACCEPT

# Allow connections from this host to 192.168.2.10

-A OUTPUT -d 10.0.0.0/8     -j ACCEPT
-A OUTPUT -d 172.16.0.0/12  -j ACCEPT
-A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Enable DNS
# 
# dport: destination port = target port of the packet being send
# sport: source port      = port of origin of the received packet
# 
# For clarification, cf.:
# https://serverfault.com/questions/441986/in-iptables-whats-the-difference-between-these-two-rules#comment477675_441988

-A INPUT  -p udp --sport 53 -j ACCEPT
-A OUTPUT -p udp --dport 53 -j ACCEPT

-A INPUT  -p udp --sport 53 -j ACCEPT
-A OUTPUT -p udp --dport 53 -j ACCEPT

-A OUTPUT -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
-A INPUT  -p udp --sport 53 -m state --state ESTABLISHED     -j ACCEPT
-A OUTPUT -p tcp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
-A INPUT  -p tcp --sport 53 -m state --state ESTABLISHED     -j ACCEPT

# Enable NTP
# 
# https://tools.ietf.org/html/rfc5905 

-A INPUT  -p udp --sport 123 -j ACCEPT
-A OUTPUT -p udp --dport 123 -j ACCEPT

# Allow outgoing ICMP traffic
# 
# https://www.cloudflare.com/learning/ddos/glossary/internet-control-message-protocol-icmp/
# https://tools.ietf.org/html/rfc792

-A OUTPUT -p icmp -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
-A INPUT  -p icmp -m state --state ESTABLISHED,RELATED     -j ACCEPT

# -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT
# -A INPUT  -p icmp --icmp-type echo-reply   -j ACCEPT
# -A INPUT  -p icmp --icmp-type echo-request -j ACCEPT
# -A OUTPUT -p icmp --icmp-type echo-reply   -j ACCEPT

# SSH

# # Incoming

# -A INPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
# -A OUTPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# # Outgoing

# -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
# -A OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

# Drop everything else

-A INPUT   -j DROP
-A FORWARD -j DROP
-A OUTPUT  -j DROP

COMMIT

# -P INPUT ACCEPT
# -P FORWARD ACCEPT
# -P OUTPUT ACCEPT
# -A INPUT -i lo -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 25 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 8025 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
# -A INPUT -p tcp -m tcp --dport 35729 -j ACCEPT
# -A INPUT -p icmp -j ACCEPT
# -A INPUT -p udp -m udp --sport 123 -j ACCEPT
# -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# -A INPUT -j DROP
# -A OUTPUT -p udp -m udp --dport 123 -j ACCEPT

# # Flushing all rules
# iptables -F
# iptables -X

# # Setting default filter policy
# iptables -P INPUT DROP
# iptables -P OUTPUT DROP
# iptables -P FORWARD DROP

# # Allow unlimited traffic on loopback
# iptables -A INPUT -i lo -j ACCEPT
# iptables -A OUTPUT -o lo -j ACCEPT

# # Allow unlimited traffic on loopback
# iptables -A INPUT -i lo -j ACCEPT
# iptables -A OUTPUT -o lo -j ACCEPT


# iptables -A INPUT -p tcp -m iprange --src-range 10.0.0.0-10.255.255.255 --dport 22 -j ACCEPT
# iptables -A INPUT -p tcp -m iprange --src-range 192.168.0.0-192.168.255.255 --dport 22 -j ACCEPT

# iptables -A INPUT -p tcp -s 10.0.3.1 --dport 22 -j ACCEPT

# iptables -A INPUT -p tcp -s 0.0.0.0/0 --dport 22 -j ACCEPT