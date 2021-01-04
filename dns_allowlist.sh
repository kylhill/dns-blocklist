#!/bin/bash

##############################################
# Create a local-zone allow list for unbound #
##############################################

DNS_RETURN="always_transparent"

ALLOWLIST="/opt/dns_blocklist/domains-allowlist.txt"
UNBOUND_ALLOWLIST="/etc/unbound/zones/allowlist.conf"

UNBOUND_CONTROL="/usr/sbin/unbound-control"
CACHE="/var/cache/dns_blocklist/cache.dmp"

# Remove newlines, comments, duplicates and subdomains masked by higher-level domains
clean_list() {
    grep -v '^\s*$\|^\s*\#' "$ALLOWLIST" | rev | sort -u | awk 'NR!=1&&substr($0,0,length(p))==p{next}{p=$0".";print}' | rev | sort
}

print_record() {
    awk -v rtn="$DNS_RETURN" '{printf "local-zone: \"%s\" %s\n", $1, rtn}'
}

set -e

# Backup any existing allowlist
SHA_PRE=""
if [ -f "$UNBOUND_ALLOWLIST" ]; then
    SHA_PRE=$(shasum "$UNBOUND_ALLOWLIST" | cut -d' ' -f1)
    mv -f $UNBOUND_ALLOWLIST $UNBOUND_ALLOWLIST.bak
fi

# Write the file
: > "$UNBOUND_ALLOWLIST"
clean_list | print_record >> "$UNBOUND_ALLOWLIST"

# Reload unbound, if needed
SHA_POST=$(shasum "$UNBOUND_ALLOWLIST" | cut -d' ' -f1)
if [ "$SHA_PRE" != "$SHA_POST" ]; then
    $UNBOUND_CONTROL dump_cache > $CACHE
    $UNBOUND_CONTROL -q reload
    $UNBOUND_CONTROL -q load_cache < $CACHE
    rm -rf $CACHE

    echo "Allowlist updated, $(wc -l < $UNBOUND_ALLOWLIST) allowed, unbound reloaded"
else
  echo "No changes, allowlist not updated"
fi

exit 0
