#!/bin/bash

##############################################
# Create a local-zone block list for unbound #
##############################################

DNS_RETURN="static"
#DNS_RETURN="0.0.0.0"

INTERNAL_ALLOWLIST="localhost\|localhost.localdomain"

CWD="/opt/dns_blocklist/"
BLOCKLIST_GENERATOR=$CWD"generate-domains-blocklist.py"
BLOCKLIST="/var/cache/dns_blocklist/blocklist.txt"
UNBOUND_BLOCKLIST="/etc/unbound/zones/blocklist.conf"

UNBOUND_CONTROL="/usr/sbin/unbound-control"
CACHE="/var/cache/dns_blocklist/cache.dmp"

# Remove commenta and newlines
clean_list() {
    grep -v '^\s*$\|^\s*\#' "$BLOCKLIST" | grep -v $INTERNAL_ALLOWLIST | sort -u
}

print_record() {
    if [[ "$DNS_RETURN" == "deny" || "$DNS_RETURN" == "refuse" || "$DNS_RETURN" == "static" || "$DNS_RETURN" == "transparent" || "$DNS_RETURN" == "always_transparent" || "$DNS_RETURN" == "always_refuse" || "$DNS_RETURN" == "always_nxdomain" ]]; then
        awk -v rtn=$DNS_RETURN '{printf "local-zone: \"%s\" %s\n", $1, rtn}'
    else
        awk -v ip=$DNS_RETURN '{printf "local-zone: \"%s\" redirect\nlocal-data: \"%s A %s\"\n", $1, $1, ip}'
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

    echo "Blocklist updated, $(wc -l < $UNBOUND_BLOCKLIST) blocked, unbound reloaded"
else
    echo "No changes, blocklist not updated"
fi

exit 0
