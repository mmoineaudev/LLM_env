#!/usr/bin/env bash
# =============================================================================
# llama.cpp Launcher — Bash Edition
# ===========================================================
# Interactive CLI launcher for llama-server (llama.cpp).
# Pure Bash with grep/cut/sed — no jq dependency.
#
# USAGE:
#   ./llama-launcher.sh [--dry-run] [--temp N] [--top-p N] [--top-k N] \
#                       [--min-p N] [--presence-penalty N] [--repeat-penalty N]
#
# ARGUMENTS:
#   --dry-run              Display the launch command without executing it.
#   --temp FLOAT           Override default temperature (default: 0.6).
#   --top-p FLOAT          Override top-P nucleus sampling (default: 0.95).
#   --top-k INTEGER        Override top-K sampling (default: 20).
#   --min-p FLOAT          Override min-P sampling (default: 0.0).
#   --presence-penalty     Override presence penalty (default: 1.5).
#   --repeat-penalty       Override repeat penalty (default: 1.0).
#   --chat-template-kwargs JSON
#                          Merge these JSON key-value pairs into the
#                          chat-template-kwargs sent to llama-server.
#                          Can be specified multiple times; later values
#                          override earlier ones. Example:
#                            --chat-template-kwargs '{"enable_thinking":false}'
#
# CONFIGURATION:
#   Settings are stored in:  ~/Documents/LLM_env/llama-launcher-config.json
#   Launch log is written to: ~/.llama-launcher.log
#
# DEPENDENCIES:
#   bash 4.0+, coreutils (find, stat, sort, awk, date)
#   NO jq required
#
# AUTHOR: Transcoded from Python by Hermes Agent
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Working directory and library paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLM_ENV_DIR="${SCRIPT_DIR}"

# Source all libraries (order matters: colors first, then json, utils/config, etc.)
source "$LLM_ENV_DIR/lib/colors.sh"
source "$LLM_ENV_DIR/lib/json.sh"
source "$LLM_ENV_DIR/lib/utils.sh"
source "$LLM_ENV_DIR/lib/config.sh"
source "$LLM_ENV_DIR/lib/menu.sh"
source "$LLM_ENV_DIR/lib/launch.sh"

# ---------------------------------------------------------------------------
# Parse command-line arguments
# ---------------------------------------------------------------------------
DRY_RUN="false"
CLI_TEMP="${CLI_TEMP:-0.6}"
CLI_TOP_P="${CLI_TOP_P:-0.95}"
CLI_TOP_K="${CLI_TOP_K:-20}"
CLI_MIN_P="${CLI_MIN_P:-0.0}"
CLI_PRESENCE_PENALTY="${CLI_PRESENCE_PENALTY:-1.5}"
CLI_REPEAT_PENALTY="${CLI_REPEAT_PENALTY:-1.0}"
CLI_CHAT_TEMPLATE_KWARGS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --temp)
            CLI_TEMP="$2"
            shift 2
            ;;
        --top-p)
            CLI_TOP_P="$2"
            shift 2
            ;;
        --top-k)
            CLI_TOP_K="$2"
            shift 2
            ;;
        --min-p)
            CLI_MIN_P="$2"
            shift 2
            ;;
        --presence-penalty)
            CLI_PRESENCE_PENALTY="$2"
            shift 2
            ;;
        --repeat-penalty)
            CLI_REPEAT_PENALTY="$2"
            shift 2
            ;;
        --chat-template-kwargs)
            # Merge multiple occurrences into a single JSON object (no jq)
            if [[ -n "$CLI_CHAT_TEMPLATE_KWARGS" ]]; then
                # Simple merge: concatenate the two JSON strings, keep last values
                CLI_CHAT_TEMPLATE_KWARGS="$(echo "${CLI_CHAT_TEMPLATE_KWARGS} ${2}" | sed 's/}{/, /g' | sed 's/{ *{/{/' | sed 's/} *}/}/')"
            else
                CLI_CHAT_TEMPLATE_KWARGS="$2"
            fi
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Interactive CLI launcher for llama-server (llama.cpp)."
            echo
            echo "OPTIONS:"
            echo "  --dry-run              Display the launch command without executing it."
            echo "  --temp FLOAT           Override default temperature (default: 0.6)"
            echo "  --top-p FLOAT          Override top-P nucleus sampling (default: 0.95)"
            echo "  --top-k INTEGER        Override top-K sampling (default: 20)"
            echo "  --min-p FLOAT          Override min-P sampling (default: 0.0)"
            echo "  --presence-penalty     Override presence penalty (default: 1.5)"
            echo "  --repeat-penalty       Override repeat penalty (default: 1.0)"
            echo "  --chat-template-kwargs JSON"
            echo "                         Merge these JSON key-value pairs into the"
            echo "                         chat-template-kwargs sent to llama-server."
            echo "                         Can be specified multiple times; later values"
            echo "                         override earlier ones."
            echo "  --help, -h             Show this help message and exit."
            echo
            echo "CONFIGURATION:"
            echo "  Settings stored in:    $HOME/Documents/LLM_env/llama-launcher-config.json"
            echo "  Launch log written to: $HOME/.llama-launcher.log"
            echo
            echo "DEPENDENCIES:"
            echo "  bash 4.0+, coreutils (find, stat, sort, awk, date)"
            echo "  NO jq required"
            exit 0
            ;;
        *)
            colorize "Unknown option: $1" "$COLOR_RED"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Initialize environment
# ---------------------------------------------------------------------------

# Detect CPU count for default thread count (80% of total, floored)
if [[ -z "${NPROC:-}" ]]; then
    TOTAL_THREADS="$(nproc 2>/dev/null || echo 4)"
    NPROC=$(( TOTAL_THREADS * 8 / 10 ))
fi

# ---------------------------------------------------------------------------
# Load or initialize configuration
# ---------------------------------------------------------------------------
if ! config_load; then
    # Config file missing or corrupt — create fresh one
    colorize "No configuration found. Creating default config..." "$COLOR_YELLOW"
    config_init "$CLI_TEMP" "$CLI_TOP_P" "$CLI_TOP_K" "$CLI_MIN_P" "$CLI_PRESENCE_PENALTY" "$CLI_REPEAT_PENALTY"
    config_load
fi

# Read address and port into shell variables for convenience
CONFIG_JSON_ADDRESS="$(get_json_value "$CONFIG_JSON" "address")"
SERVER_PORT="$(get_json_value "$CONFIG_JSON" "port")"

# ---------------------------------------------------------------------------
# Locate llama-server binary
# ---------------------------------------------------------------------------
if ! find_llama_server; then
    colorize "Error: llama-server binary not found." "$COLOR_RED"
    echo
    colorize "Searched locations:" "$COLOR_YELLOW"
    for cand in \
        "$HOME/Modèles/llama.cpp/build/bin/llama-server" \
        "$HOME/llama.cpp/build/bin/llama-server" \
        "/usr/local/bin/llama-server" \
        "/usr/bin/llama-server" \
        "./build/bin/llama-server"; do
        echo "  $cand"
    done
    echo
    colorize "Please build llama.cpp or set the path manually." "$COLOR_YELLOW"
    exit 1
fi

colorize "Found llama-server: $LLAMA_SERVER_PATH" "$COLOR_GREEN"

# ---------------------------------------------------------------------------
# Scan for GGUF model files
# ---------------------------------------------------------------------------
scan_gguf_files

if [[ ${#GGUF_LIST[@]} -eq 0 ]]; then
    colorize "No GGUF model files found. Scanned:" "$COLOR_YELLOW"
    for dir in "$HOME/.lmstudio/models" "$HOME/Models" "$HOME/Downloads" "./Models"; do
        if [[ -d "$dir" ]]; then
            echo "  $dir"
        else
            colorize "  $dir (not found)" "$COLOR_RED"
        fi
    done
    echo
    colorize "Place .gguf files in one of the above directories and restart." "$COLOR_YELLOW"
    exit 0
fi

colorize "Found ${#GGUF_LIST[@]} GGUF model(s)." "$COLOR_GREEN"

# ---------------------------------------------------------------------------
# Main event loop — interactive unless --dry-run (then tests last model)
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "true" ]]; then
    # Dry-run: load last model and display the command without launching
    colorize "[DRY RUN] Testing with last configured model..." "$COLOR_YELLOW"
    echo

    last_model="$(get_json_value "$CONFIG_JSON" "last_model")"

    if [[ -n "$last_model" && -f "$last_model" ]]; then
        launch_server "$last_model"
    else
        colorize "[DRY RUN] No last model configured. Listing available models:" "$COLOR_YELLOW"
        for entry in "${GGUF_LIST[@]}"; do
            IFS='|' read -r mpath mname msize <<< "$entry"
            echo "  $mname ($msize MB) — $mpath"
        done
    fi

    exit 0
fi

# Interactive mode
while true; do
    display_header

    # Use select for the main menu to minimize typing
    menu_items=("Load last used model and start server" \
                "Choose a model then launch it" \
                "Configure API key" \
                "Configure address" \
                "Exit")

    select choice in "${menu_items[@]}"; do
        case "$choice" in
            "Load last used model and start server")
                last_model="$(get_json_value "$CONFIG_JSON" "last_model")"

                if [[ -n "$last_model" && -f "$last_model" ]]; then
                    launch_server "$last_model"
                else
                    colorize "No last model configured or file missing." "$COLOR_YELLOW"
                fi
                break
                ;;

            "Choose a model then launch it")
                if choose_model; then
                    # Edit parameters for the selected model
                    edit_model_params "$SELECTED_MODEL_PATH" \
                        "$CLI_TEMP" "$CLI_TOP_P" "$CLI_TOP_K" \
                        "$CLI_MIN_P" "$CLI_PRESENCE_PENALTY" "$CLI_REPEAT_PENALTY"

                    # Launch with the edited params
                    launch_server "$SELECTED_MODEL_PATH" "$SELECTED_MODEL_JSON"
                else
                    colorize "No model selected." "$COLOR_YELLOW"
                fi
                break
                ;;

            "Configure API key")
                configure_api_key
                break
                ;;

            "Configure address")
                configure_address
                break
                ;;

            "Exit")
                colorize "Goodbye!" "$COLOR_GREEN"
                exit 0
                ;;

            *)
                colorize "Invalid choice. Try again." "$COLOR_RED"
                ;;
        esac
    done
done
