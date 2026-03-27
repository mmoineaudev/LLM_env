#!/bin/bash

# ==============================================================================
# llm-monitoring.sh
# ==============================================================================
# A terminal monitoring dashboard for LLM development projects.
# Displays VRAM usage, RAM usage, and git statistics in a clean ASCII layout.
# 
# Features:
# - VRAM usage via nvidia-smi (compact format)
# - RAM usage percentage
# - Git metrics: uncommitted lines, commit count, time since last commit
# - Simplified commit list with timestamps
# - Auto-refresh every 5 seconds
# - Color-coded thresholds
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Threshold colors
get_color() {
    local value=$1
    local threshold=$2
    if [[ $value -ge $threshold ]]; then
        echo -e "${RED}"
    elif [[ $value -ge $((threshold - 20)) ]]; then
        echo -e "${YELLOW}"
    else
        echo -e "${GREEN}"
    fi
}

# ASCII Art Header
print_header() {
    echo -e "${CYAN}"
    cat << 'EOF'
  _    _                      ____  _             _    
 | |  | |                    |  _ \| |           | |   
 | |__| | ___  __ _ _ __ ___  | |_) | | __ _ _ __ | |_  
 |  __  |/ _ \/ _` | '__/ _ \ |  _ <| |/ _` | '_ \| __| 
 | |  | |  __/ (_| | | |  __/ | |_) | | (_| | | | | |_  
 |_|  |_|\___|\__,_|_|  \___| |____/|_|\__,_|_| |_|\__| 
                                                       
EOF
    echo -e "${NC}"
}

# Get VRAM usage from nvidia-smi
get_vram_usage() {
    if command -v nvidia-smi &> /dev/null; then
        # Get memory usage in compact format
        local vram_info=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$vram_info" ]]; then
            local used=$(echo "$vram_info" | cut -d',' -f1 | tr -d ' ')
            local total=$(echo "$vram_info" | cut -d',' -f2 | tr -d ' ')
            if [[ -n "$used" && -n "$total" && "$total" -gt 0 ]]; then
                local percent=$((used * 100 / total))
                echo "$percent"
                return
            fi
        fi
    fi
    echo "N/A"
}

# Get RAM usage percentage
get_ram_usage() {
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    if [[ -n "$total" && -n "$used" && "$total" -gt 0 ]]; then
        local percent=$((used * 100 / total))
        echo "$percent"
    else
        echo "N/A"
    fi
}

# Get uncommitted lines
get_uncommitted_lines() {
    local repo_dir="$1"
    if [[ -d "$repo_dir/.git" ]]; then
        local uncommitted=$(cd "$repo_dir" && git diff --numstat 2>/dev/null | awk '{added+=$1; removed+=$2} END {print added+removed}')
        echo "${uncommitted:-0}"
    else
        echo "N/A"
    fi
}

# Get number of commits ahead/behind
get_commit_count() {
    local repo_dir="$1"
    if [[ -d "$repo_dir/.git" ]]; then
        local ahead=$(cd "$repo_dir" && git rev-list --count HEAD..origin/$(git branch --show-current 2>/dev/null) 2>/dev/null || echo "0")
        local behind=$(cd "$repo_dir" && git rev-list --count origin/$(git branch --show-current 2>/dev/null)..HEAD 2>/dev/null || echo "0")
        echo "Ahead: $ahead | Behind: $behind"
    else
        echo "N/A"
    fi
}

# Get time since last commit
get_time_since_last_commit() {
    local repo_dir="$1"
    if [[ -d "$repo_dir/.git" ]]; then
        local last_commit=$(cd "$repo_dir" && git log -1 --format=%ai 2>/dev/null)
        if [[ -n "$last_commit" ]]; then
            local last_epoch=$(date -d "$last_commit" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            local diff=$((current_epoch - last_epoch))
            
            local days=$((diff / 86400))
            local hours=$(((diff % 86400) / 3600))
            local mins=$(((diff % 3600) / 60))
            
            if [[ $days -gt 0 ]]; then
                echo "${days}d ${hours}h ${mins}m ago"
            elif [[ $hours -gt 0 ]]; then
                echo "${hours}h ${mins}m ago"
            else
                echo "${mins}m ago"
            fi
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

# Get simplified commit list (timestamp + message)
get_commit_list() {
    local repo_dir="$1"
    local limit="${2:-5}"
    if [[ -d "$repo_dir/.git" ]]; then
        cd "$repo_dir"
        git log -n "$limit" --format="%ai | %s" 2>/dev/null | tail -5
        cd - > /dev/null
    else
        echo "N/A"
    fi
}

# Get current branch
get_branch() {
    local repo_dir="$1"
    if [[ -d "$repo_dir/.git" ]]; then
        cd "$repo_dir"
        git branch --show-current 2>/dev/null
        cd - > /dev/null
    else
        echo "N/A"
    fi
}

# Get project name
get_project_name() {
    local repo_dir="$1"
    basename "$repo_dir"
}

# Main display function
display() {
    clear
    print_header
    
    # Get project info
    local project_dir="$1"
    local project_name=$(get_project_name "$project_dir")
    local branch=$(get_branch "$project_dir")
    
    # Header info
    echo -e "${WHITE}Project:${NC} ${CYAN}$project_name${NC}"
    echo -e "${WHITE}Branch:${NC} ${MAGENTA}$branch${NC}"
    echo -e "${WHITE}Path:${NC} ${BLUE}$project_dir${NC}"
    echo -e "$(printf '=%.0s' {1..60})"
    
    # Resource usage section
    echo ""
    echo -e "${WHITE}=== Resource Usage ===${NC}"
    echo ""
    
    local vram=$(get_vram_usage)
    if [[ "$vram" == "N/A" ]]; then
        echo -e "${WHITE}VRAM:${NC} ${YELLOW}GPU not detected${NC}"
    else
        local vram_color=$(get_color $vram 80)
        echo -e "${WHITE}VRAM:${NC} $vram_color${vram}%${NC}"
    fi
    
    local ram=$(get_ram_usage)
    if [[ "$ram" == "N/A" ]]; then
        echo -e "${WHITE}RAM:${NC} ${YELLOW}N/A${NC}"
    else
        local ram_color=$(get_color $ram 80)
        echo -e "${WHITE}RAM:${NC} $ram_color${ram}%${NC}"
    fi
    
    echo ""
    
    # Git section
    echo -e "${WHITE}=== Git Statistics ===${NC}"
    echo ""
    
    local uncommitted=$(get_uncommitted_lines "$project_dir")
    if [[ "$uncommitted" == "N/A" ]]; then
        echo -e "${WHITE}Uncommitted Lines:${NC} ${YELLOW}Not a git repo${NC}"
    else
        local uncommitted_color=$(get_color $uncommitted 500)
        echo -e "${WHITE}Uncommitted Lines:${NC} $uncommitted_color${uncommitted}${NC}"
    fi
    
    local commit_count=$(get_commit_count "$project_dir")
    if [[ "$commit_count" == "N/A" ]]; then
        echo -e "${WHITE}Commit Status:${NC} ${YELLOW}N/A${NC}"
    else
        echo -e "${WHITE}Commit Status:${NC} ${CYAN}$commit_count${NC}"
    fi
    
    local time_since=$(get_time_since_last_commit "$project_dir")
    if [[ "$time_since" == "N/A" ]]; then
        echo -e "${WHITE}Last Commit:${NC} ${YELLOW}N/A${NC}"
    else
        echo -e "${WHITE}Last Commit:${NC} ${MAGENTA}$time_since${NC}"
    fi
    
    echo ""
    
    # Commit list
    echo -e "${WHITE}=== Recent Commits ===${NC}"
    echo ""
    
    local commit_list=$(get_commit_list "$project_dir" 5)
    if [[ "$commit_list" == "N/A" ]]; then
        echo -e "${YELLOW}No commits found${NC}"
    else
        echo "$commit_list" | while read -r line; do
            echo -e "${CYAN}$line${NC}"
        done
    fi
    
    echo ""
    echo -e "$(printf '=%.0s' {1..60})"
    echo -e "${WHITE}Press Ctrl+C to exit${NC}"
    echo -e "${WHITE}Auto-refresh: 5 seconds${NC}"
}

# Main loop
main() {
    # Prompt for project path
    echo ""
    echo -e "${WHITE}Enter project directory path:${NC}"
    read -p "> " project_path
    
    if [[ -z "$project_path" ]]; then
        echo -e "${RED}No path provided. Exiting.${NC}"
        exit 1
    fi
    
    # Resolve to absolute path
    project_path=$(cd "$project_path" 2>/dev/null && pwd)
    
    if [[ ! -d "$project_path" ]]; then
        echo -e "${RED}Path does not exist: $project_path${NC}"
        exit 1
    fi
    
    # Clear screen and start loop
    clear
    
    while true; do
        display "$project_path"
        sleep 5
    done
}

# Run main
main "$@"
