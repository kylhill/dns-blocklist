#!/bin/bash

##############################################
# Create a local-zone allow list for unbound #
##############################################

DNS_RETURN="always_transparent"

ALLOWLIST="/opt/dns_blocklist/domains-allowlist.txt"

TMP_FILE="/var/cache/dns_blocklist/allowlist.tmp"
UNBOUND_ALLOWLIST="/etc/unbound/zones/allowlist.conf"

set -e

# Clean up any old temporary files
if [ -f "$TMP_FILE" ]; then
  rm -f $TMP_FILE
fi

# Strip comments and newlines, sort and remove duplicates
grep -v '^\s*$\|^\s*\#' "$ALLOWLIST" | sort -u > $TMP_FILE

# Backup any existing allowlist
SHA_PRE=""
if [ -f "$UNBOUND_ALLOWLIST" ]; then
    SHA_PRE=$(shasum "$UNBOUND_ALLOWLIST" | cut -d' ' -f1)
    mv -f $UNBOUND_ALLOWLIST $UNBOUND_ALLOWLIST.bak
fi

# Write the file
echo "############################################################" >  "$UNBOUND_ALLOWLIST"
echo "# Allow list, generated from dns_allowlist.sh              #" >> "$UNBOUND_ALLOWLIST"
echo "#                                                          #" >> "$UNBOUND_ALLOWLIST"
echo "# DO NOT EDIT MANUALLY!                                    #" >> "$UNBOUND_ALLOWLIST"
echo "############################################################" >> "$UNBOUND_ALLOWLIST"
echo "" >> "$UNBOUND_ALLOWLIST"

awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s.\" %s\n", $1, rtn}' < $TMP_FILE >> "$UNBOUND_ALLOWLIST"

# Change permissions on final file
chmod 644 "$UNBOUND_ALLOWLIST"

# Cleanup
ALLOWED_COUNT=$(wc -l < $TMP_FILE)
if [ -f "$TMP_FILE" ]; then
  rm -f $TMP_FILE
fi

# Reload unbound, if needed
SHA_POST=$(shasum "$UNBOUND_ALLOWLIST" | cut -d' ' -f1)

if [ "$SHA_PRE" != "$SHA_POST" ]; then
  systemctl force-reload unbound.service

  echo "Allowlist updated, $ALLOWED_COUNT allowed, unbound reloaded"
else
  echo "Allowlist not updated"
fi

