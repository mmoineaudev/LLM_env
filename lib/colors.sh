#!/usr/bin/env bash
# =============================================================================
# lib/colors.sh — ANSI color helpers for the llama launcher
# =============================================================================

COLOR_RED=$'\033[91m'
COLOR_GREEN=$'\033[92m'
COLOR_YELLOW=$'\033[93m'
COLOR_BLUE=$'\033[94m'
COLOR_MAGENTA=$'\033[95m'
COLOR_CYAN=$'\033[96m'
COLOR_WHITE=$'\033[97m'
COLOR_BOLD=$'\033[1m'
COLOR_RESET=$'\033[0m'

# colorize TEXT COLOR — wrap text with the given color and reset at end
colorize() {
    text="$1"
    color="${2:-$COLOR_WHITE}"
    printf '%s%s%s' "$color" "$text" "$COLOR_RESET"
}
