#!/bin/bash
# Cache helper functions for MOTD scripts

MOTD_CACHE_DIR="${MOTD_CACHE_DIR:-$HOME/Projects/dynamic-motd/cache}"

# Read cached data if valid (not stale)
# Usage: read_cache "key" max_age_seconds
# Returns: 0 if valid cache exists (data on stdout), 1 if stale/missing
read_cache() {
    local key="$1"
    local max_age="${2:-300}"  # default 5 min
    local cache_file="$MOTD_CACHE_DIR/$key"
    
    [[ ! -f "$cache_file" ]] && return 1
    
    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
    if [[ $file_age -gt $max_age ]]; then
        return 1
    fi
    
    cat "$cache_file"
    return 0
}

# Write data to cache
# Usage: echo "data" | write_cache "key"
write_cache() {
    local key="$1"
    local cache_file="$MOTD_CACHE_DIR/$key"
    mkdir -p "$MOTD_CACHE_DIR"
    cat > "$cache_file"
}

# Check if cache is stale (for cron to decide whether to refresh)
# Usage: cache_stale "key" max_age_seconds
cache_stale() {
    local key="$1"
    local max_age="${2:-300}"
    local cache_file="$MOTD_CACHE_DIR/$key"
    
    [[ ! -f "$cache_file" ]] && return 0
    
    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
    [[ $file_age -gt $max_age ]]
}

# Get human-readable cache age string
# Usage: cache_age_str "key"
# Returns: string like "2 min ago", "1 hr ago", "3 hrs ago"
cache_age_str() {
    local key="$1"
    local cache_file="$MOTD_CACHE_DIR/$key"
    
    [[ ! -f "$cache_file" ]] && echo "no cache" && return
    
    local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
    
    if [[ $file_age -lt 60 ]]; then
        echo "${file_age}s ago"
    elif [[ $file_age -lt 3600 ]]; then
        local mins=$((file_age / 60))
        echo "${mins} min ago"
    elif [[ $file_age -lt 86400 ]]; then
        local hrs=$((file_age / 3600))
        if [[ $hrs -eq 1 ]]; then
            echo "1 hr ago"
        else
            echo "${hrs} hrs ago"
        fi
    else
        local days=$((file_age / 86400))
        if [[ $days -eq 1 ]]; then
            echo "1 day ago"
        else
            echo "${days} days ago"
        fi
    fi
}
