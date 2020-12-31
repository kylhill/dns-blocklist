#!/bin/bash

##############################################
# Create a local-zone block list for unbound #
##############################################

DNS_RETURN="always_nxdomain"
#DNS_RETURN="0.0.0.0"

BLOCKLIST_GENERATOR="/opt/dns_blocklist/generate-domains-blocklist.py"
BLOCKLIST="/var/cache/dns_blocklist/blocklist.txt"

INTERNAL_ALLOWLIST="localhost\|localhost.localdomain"

TMP_FILE="/var/cache/dns_blocklist/blocklist.tmp"
UNBOUND_BLOCKLIST="/etc/unbound/zones/blocklist.conf"

set -e

cd /opt/dns_blocklist

# Clean up any old temporary files
if [ -f "$TMP_FILE" ]; then
  rm -f $TMP_FILE
fi
if [ -f "$BLOCKLIST" ]; then
  rm -f $BLOCKLIST
fi

# Generate blocklist
$BLOCKLIST_GENERATOR -o $BLOCKLIST

# Strip comments and newlines, remove hosts from internal allowlist, sort and remove duplicates
grep -v '^\s*$\|^\s*\#' "$BLOCKLIST" | grep -v $INTERNAL_ALLOWLIST | sort -u > $TMP_FILE

# Backup any existing blocklist
SHA_PRE=""
if [ -f "$UNBOUND_BLOCKLIST" ]; then
    SHA_PRE=$(shasum "$UNBOUND_BLOCKLIST" | cut -d' ' -f1)
    mv -f $UNBOUND_BLOCKLIST $UNBOUND_BLOCKLIST.bak
fi

# Write the file
echo "############################################################" >  "$UNBOUND_BLOCKLIST"
echo "# Ad and malware blocking, generated from dns_blocklist.sh #" >> "$UNBOUND_BLOCKLIST"
echo "#                                                          #" >> "$UNBOUND_BLOCKLIST"
echo "# DO NOT EDIT MANUALLY!                                    #" >> "$UNBOUND_BLOCKLIST"
echo "############################################################" >> "$UNBOUND_BLOCKLIST"
echo "" >> "$UNBOUND_BLOCKLIST"

if [[ "$DNS_RETURN" == "refuse" || "$DNS_RETURN" == "static" || "$DNS_RETURN" == "always_refuse" || "$DNS_RETURN" == "always_nxdomain" || "$DNS_RETURN" == "transparent" || "$DNS_RETURN" == "always_transparent" ]]; then
  awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s.\" %s\n", $1, rtn}' < $TMP_FILE >> "$UNBOUND_BLOCKLIST"
else
  awk -v ip=$DNS_RETURN '{printf "local-zone: \"%s.\" redirect\nlocal-data: \"%s. 600 IN A %s\"\n", $1, $1, ip}' < $TMP_FILE >> "$UNBOUND_BLOCKLIST"
fi

# Change permissions on final file
chmod 644 "$UNBOUND_BLOCKLIST"

# Cleanup
BLOCKED_COUNT=$(wc -l < $TMP_FILE)
if [ -f "$TMP_FILE" ]; then
  rm -f $TMP_FILE
fi
if [ -f "$BLOCKLIST" ]; then
  rm -f $BLOCKLIST
fi

# Reload unbound, if needed
SHA_POST=$(shasum "$UNBOUND_BLOCKLIST" | cut -d' ' -f1)

if [ "$SHA_PRE" != "$SHA_POST" ]; then
  systemctl force-reload unbound.service

  echo "Blocklist updated, $BLOCKED_COUNT blocked, unbound reloaded"
else
  echo "Blocklist not updated"
fi

