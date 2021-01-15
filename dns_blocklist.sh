#!/bin/bash

##############################################
# Create a local-zone block list for unbound #
##############################################

#DNS_RETURN="always_nxdomain"
DNS_RETURN="0.0.0.0"

CWD="/opt/dns_blocklist/"
BLOCKLIST_GENERATOR=$CWD"generate-domains-blocklist.py"
BLOCKLIST="/var/cache/dns_blocklist/blocklist.txt"
UNBOUND_BLOCKLIST="/etc/unbound/zones/blocklist.conf"

UNBOUND_CONTROL="/usr/sbin/unbound-control"
CACHE="/var/cache/dns_blocklist/cache.dmp"

# Remove comments, newlines and duplicates
clean_list() {
    grep -v '^\s*$\|^\s*\#' "$BLOCKLIST" | sort -u
}

print_record() {
    if [[ "$DNS_RETURN" == "deny" || "$DNS_RETURN" == "refuse" || "$DNS_RETURN" == "static" || "$DNS_RETURN" == "always_refuse" || "$DNS_RETURN" == "always_nxdomain" ]]; then
        awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s.\" %s\n", $1, rtn}'
    else
        awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s.\" redirect\nlocal-data: \"%s. 3600 IN A %s\"\n", $1, $1, rtn}'
    fi
}

set -e

# Clean up any old files
if [ -f "$BLOCKLIST" ]; then
  rm -f $BLOCKLIST
fi

# Generate blocklist
cd $CWD
$BLOCKLIST_GENERATOR -o $BLOCKLIST

# Backup any existing blocklist
SHA_PRE=""
if [ -f "$UNBOUND_BLOCKLIST" ]; then
    SHA_PRE=$(shasum "$UNBOUND_BLOCKLIST" | cut -d' ' -f1)
    mv -f $UNBOUND_BLOCKLIST $UNBOUND_BLOCKLIST.bak
fi

# Write the file
: > "$UNBOUND_BLOCKLIST"
clean_list | print_record >> "$UNBOUND_BLOCKLIST"

# Cleanup
if [ -f "$BLOCKLIST" ]; then
    rm -f $BLOCKLIST
fi

# Reload unbound, if needed
SHA_POST=$(shasum "$UNBOUND_BLOCKLIST" | cut -d' ' -f1)
if [ "$SHA_PRE" != "$SHA_POST" ]; then
    $UNBOUND_CONTROL dump_cache > $CACHE
    $UNBOUND_CONTROL -q reload
    $UNBOUND_CONTROL -q load_cache < $CACHE
    rm -rf $CACHE

    echo "Blocklist updated, unbound reloaded"
else
    echo "No changes, blocklist not updated"
fi

exit 0
