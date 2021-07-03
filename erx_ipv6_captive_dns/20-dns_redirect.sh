#!/bin/vbash
#
# Configures ip6tables on EdgeRouter X to redirect IPv6 DNS queries to desired server.
# Place in /config/scripts/post-config.d/20-dns_redirect.sh
#
# See https://community.ui.com/questions/Intercepting-and-Re-Directing-DNS-Queries/cd0a248d-ca54-4d16-84c6-a5ade3dc3272
#

# Flush old PREROUTING and POSTROUTING chains
ip6tables -t nat -F PREROUTING
ip6tables -t nat -F POSTROUTING

# Destroy old ipset
ipset destroy NoDNSRedirectv6

# Create a mac hash ipset to exempt hosts from IPv6 DNS redirect
ipset -N NoDNSRedirectv6 machash
# gateway
ipset -A NoDNSRedirectv6 74:83:c2:6f:df:10
# rog-g15
ipset -A NoDNSRedirectv6 f8:e4:e3:d6:6b:81
# syntax
ipset -A NoDNSRedirectv6 a8:a1:59:1e:a3:56

# Captive DNS for IPv6
ip6tables -t nat -A PREROUTING -i switch0   -m set ! --match-set NoDNSRedirectv6 src -p tcp --dport 53 -j DNAT --to-destination fd06:4f9a:934d:a848::30
ip6tables -t nat -A PREROUTING -i switch0   -m set ! --match-set NoDNSRedirectv6 src -p udp --dport 53 -j DNAT --to-destination fd06:4f9a:934d:a848::30

ip6tables -t nat -A PREROUTING -i switch0.7 -m set ! --match-set NoDNSRedirectv6 src -p tcp --dport 53 -j DNAT --to-destination fd06:4f9a:934d:a848::30
ip6tables -t nat -A PREROUTING -i switch0.7 -m set ! --match-set NoDNSRedirectv6 src -p udp --dport 53 -j DNAT --to-destination fd06:4f9a:934d:a848::30

# Set up masquerades for DNS redirects
ip6tables -t nat -A POSTROUTING -o switch0   -d fd06:4f9a:934d:a848::30 -p tcp --dport 53 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -o switch0   -d fd06:4f9a:934d:a848::30 -p udp --dport 53 -j MASQUERADE

ip6tables -t nat -A POSTROUTING -o switch0.7 -d fd06:4f9a:934d:a848::30 -p tcp --dport 53 -j MASQUERADE
ip6tables -t nat -A POSTROUTING -o switch0.7 -d fd06:4f9a:934d:a848::30 -p udp --dport 53 -j MASQUERADE

exit 0
