#!/bin/bash
# Cache refresh script - run via cron to pre-compute expensive MOTD data
# Runs each refresh in parallel for speed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/cache-helpers.sh"

# Package updates (expensive - run every 6 hours)
refresh_package_updates() {
    local total=$(apt list --upgradable 2>/dev/null | grep -v "^Listing" | wc -l)
    local security=$(apt list --upgradable 2>/dev/null | grep -iE "security" | wc -l)
    echo "$total:$security" | write_cache "package-updates"
}

# Docker status (run every 5 minutes)
refresh_docker_status() {
    if ! command -v docker &>/dev/null; then
        echo "none" | write_cache "docker-status"
        return
    fi
    if ! docker info &>/dev/null 2>&1; then
        echo "daemon-down" | write_cache "docker-status"
        return
    fi
    local running=$(docker ps -q 2>/dev/null | wc -l)
    local total=$(docker ps -a -q 2>/dev/null | wc -l)
    echo "$running:$total" | write_cache "docker-status"
}

# Git repos status (run every 10 minutes)
refresh_git_repos() {
    local output=""
    declare -A seen_repos  # Track repos to avoid duplicates
    local check_dirs=(/home/pi/Projects /home/pi/Scripts /opt /home/pi)
    
    for base_dir in "${check_dirs[@]}"; do
        [[ ! -d "$base_dir" ]] && continue
        while IFS= read -r -d '' git_dir; do
            repo_dir=$(dirname "$git_dir")
            repo_name=$(basename "$repo_dir")
            
            # Skip if already processed or in Trash
            [[ "$repo_dir" == *"Trash"* ]] && continue
            [[ -n "${seen_repos[$repo_dir]}" ]] && continue
            seen_repos[$repo_dir]=1
            
            cd "$repo_dir" 2>/dev/null || continue
            
            # Check uncommitted
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                output+="$repo_name:uncommitted\n"
                continue
            fi
            
            # Check unpushed
            if git rev-parse --abbrev-ref @'{u}' &>/dev/null 2>&1; then
                unpushed=$(git log @'{u}'.. --oneline 2>/dev/null | wc -l)
                if [[ $unpushed -gt 0 ]]; then
                    output+="$repo_name:unpushed:$unpushed\n"
                fi
            fi
        done < <(find "$base_dir" -maxdepth 3 -name .git -type d -print0 2>/dev/null)
    done
    
    echo -e "$output" | write_cache "git-repos"
}

# Certificate expiry (run every 6 hours)
refresh_cert_expiry() {
    local output=""
    local cert_paths=("/etc/ssl/certs" "/home/pi/.ssh" "/etc/letsencrypt/live")
    
    for cert_path in "${cert_paths[@]}"; do
        [[ ! -d "$cert_path" ]] && continue
        while IFS= read -r cert_file; do
            expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
            [[ -z "$expiry" ]] && continue
            
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
            now_epoch=$(date +%s)
            days_until=$((($expiry_epoch - $now_epoch) / 86400))
            
            if [[ $days_until -lt 30 ]]; then
                output+="$(basename "$cert_file"):$days_until\n"
            fi
        done < <(find "$cert_path" -maxdepth 2 -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.cert" \) 2>/dev/null)
    done
    
    echo -e "$output" | write_cache "cert-expiry"
}

# Run all refreshes in parallel
case "${1:-all}" in
    packages) refresh_package_updates ;;
    docker)   refresh_docker_status ;;
    git)      refresh_git_repos ;;
    certs)    refresh_cert_expiry ;;
    all)
        refresh_package_updates &
        refresh_docker_status &
        refresh_git_repos &
        refresh_cert_expiry &
        wait
        ;;
esac
