#!/usr/bin/env bash
# =============================================================================
# lib/menu.sh — Interactive menus for model selection and parameter editing
# No jq required — uses grep/cut/sed from lib/json.sh.
# All functions that modify params update CONFIG_JSON and save.
# =============================================================================

# ---------------------------------------------------------------------------
# display_header — print the main menu header
# ---------------------------------------------------------------------------
display_header() {
    echo
    colorize "============================================================" "$COLOR_BLUE"
    colorize "  llama.cpp Launcher" "$COLOR_GREEN${COLOR_BOLD}"
    colorize "============================================================" "$COLOR_BLUE"
    echo
    colorize "  Interactive CLI launcher for llama-server" "$COLOR_CYAN"
    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    colorize "  OPTIONS:" "$COLOR_YELLOW${COLOR_BOLD}"
    echo
    colorize "  1. Load last used model and start server" "$COLOR_GREEN${COLOR_BOLD}"
    colorize "     - Starts llama-server with the previously selected model" "$COLOR_WHITE"
    echo
    colorize "  2. Choose a model then launch it" "$COLOR_GREEN${COLOR_BOLD}"
    colorize "     - Browse available GGUF files and select one to run" "$COLOR_WHITE"
    echo
    colorize "  3. Configure API key" "$COLOR_GREEN${COLOR_BOLD}"
    colorize "     - Set or clear the authentication key for llama-server" "$COLOR_WHITE"
    echo
    colorize "  4. Configure address (default: $DEFAULT_ADDRESS)" "$COLOR_GREEN${COLOR_BOLD}"
    colorize "     - Change server host and port settings" "$COLOR_WHITE"
    echo
    colorize "  5. Exit" "$COLOR_RED${COLOR_BOLD}"
    echo
}

# ---------------------------------------------------------------------------
# choose_model — interactive model picker using select
# Returns the selected model path via SELECTED_MODEL_PATH.
# Also opens the parameter editor for that model.
# Sets SELECTED_MODEL_JSON with the resulting params JSON.
# ---------------------------------------------------------------------------
SELECTED_MODEL_PATH=""
SELECTED_MODEL_NAME=""
SELECTED_MODEL_SIZE_MB=""
SELECTED_MODEL_JSON=""

choose_model() {
    if [[ ${#GGUF_LIST[@]} -eq 0 ]]; then
        echo
        colorize "No GGUF files found in common locations." "$COLOR_RED"
        return 1
    fi

    # Build select array with display strings
    menu_items=()
    for entry in "${GGUF_LIST[@]}"; do
        IFS='|' read -r mpath mname msize <<< "$entry"
        marker=""
        if [[ "$CONFIG_JSON" != "" ]]; then
            last_model="$(get_json_value "$CONFIG_JSON" "last_model")"
            if [[ "$mpath" == "$last_model" ]]; then
                marker=" $(colorize "(last used)" "$COLOR_GREEN")"
            fi
        fi
        display="$(truncate_path "$mpath") ($msize MB)$marker"
        menu_items+=("$display")
    done

     # Use select for the model picker
    echo
    colorize "Select a model:" "$COLOR_YELLOW${COLOR_BOLD}"
    echo
    select choice in "${menu_items[@]}"; do
        if [[ -n "$choice" ]]; then
            idx=$((REPLY - 1))
            IFS='|' read -r SELECTED_MODEL_PATH SELECTED_MODEL_NAME SELECTED_MODEL_SIZE_MB <<< "${GGUF_LIST[$idx]}"

            # Save as last model using Python for safe JSON handling
            CONFIG_JSON="$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
data['last_model'] = sys.argv[1]
print(json.dumps(data, indent=4))
" "$SELECTED_MODEL_PATH")"
            config_save

            echo
            colorize "Selected: $SELECTED_MODEL_NAME" "$COLOR_GREEN"
            colorize "  Path: $SELECTED_MODEL_PATH" "$COLOR_CYAN"
            colorize "  Size: ${SELECTED_MODEL_SIZE_MB} MB" "$COLOR_CYAN"
            colorize "------------------------------------------------------------" "$COLOR_BLUE"
            return 0
        else
            # Empty/invalid select — user typed something not in the list
            :
        fi
    done
    # If select was cancelled (Ctrl+C or empty input)
    return 1
}

# ---------------------------------------------------------------------------
# edit_model_params MODEL_PATH — interactive parameter editor for a model
# Uses select-based sub-menus to minimize typing.
# Reads current params, prompts user to override each one, saves back.
# Sets SELECTED_MODEL_JSON with the final params.
# ---------------------------------------------------------------------------
edit_model_params() {
    model_path="$1"
    cli_temp="${2:-0.6}"
    cli_top_p="${3:-0.95}"
    cli_top_k="${4:-20}"
    cli_min_p="${5:-0.0}"
    cli_presence_penalty="${6:-1.5}"
    cli_repeat_penalty="${7:-1.0}"

    # Load current params (or defaults)
    SELECTED_MODEL_JSON="$(get_model_params "$model_path" "$cli_temp" "$cli_top_p" "$cli_top_k" "$cli_min_p" "$cli_presence_penalty" "$cli_repeat_penalty")"

    echo
    colorize "Current parameters for $SELECTED_MODEL_NAME:" "$COLOR_YELLOW"
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    echo

    # Parse the JSON into an associative array for easy access
    declare -A _params
    parse_json_obj "$SELECTED_MODEL_JSON" "_params"

    # --- Server / hardware params (numeric) ---
    n_ctx="${_params[n_ctx]}"
    read -rp "  Context length [$n_ctx]: " input
    [[ -z "$input" ]] && input="$n_ctx"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        n_ctx="$input"
    else
        colorize "Invalid number, keeping: $n_ctx" "$COLOR_YELLOW"
    fi
    _params[n_ctx]="$n_ctx"

    echo

    n_gpu_layers="${_params[n_gpu_layers]}"
    read -rp "  GPU layers [$n_gpu_layers] (auto or numeric): " input
    if [[ -z "$input" ]]; then
        : # keep current
    elif [[ "$input" == "auto" || "$input" =~ ^-?[0-9]+$ ]]; then
        n_gpu_layers="$input"
    else
        colorize "Invalid input, keeping: $n_gpu_layers" "$COLOR_YELLOW"
    fi
    _params[n_gpu_layers]="$n_gpu_layers"

    echo

    threads="${_params[threads]}"
    read -rp "  Threads [$threads]: " input
    [[ -z "$input" ]] && input="$threads"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        threads="$input"
    else
        colorize "Invalid number, keeping: $threads" "$COLOR_YELLOW"
    fi
    _params[threads]="$threads"

    echo

    batch_size="${_params[batch_size]}"
    read -rp "  Batch size [$batch_size]: " input
    [[ -z "$input" ]] && input="$batch_size"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        batch_size="$input"
    else
        colorize "Invalid number, keeping: $batch_size" "$COLOR_YELLOW"
    fi
    _params[batch_size]="$batch_size"

    echo

    cache_type="${_params[cache_type]}"
    colorize "  KV Cache type: $cache_type" "$COLOR_CYAN"
    cache_options=("f32" "f16" "bf16" "q8_0" "q4_0" "q4_1" "iq4_nl" "q5_0" "q5_1")

    # Use select for cache type
    cache_choice_idx=999  # sentinel
    while true; do
        select ct in "${cache_options[@]}"; do
            if [[ -n "$ct" ]]; then
                cache_type="$ct"
                break 2
            fi
        done
    done

    _params[cache_type]="$cache_type"

    echo

    use_flash_attn="${_params[use_flash_attn]}"
    if [[ "$use_flash_attn" == "true" ]]; then
        read -rp "  Flash Attention [Y/n]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && use_flash_attn="true"
    else
        read -rp "  Flash Attention [y/N]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && use_flash_attn="false"
    fi
    case "$input" in y|yes) use_flash_attn="true" ;; n|no) use_flash_attn="false" ;; esac
    _params[use_flash_attn]="$use_flash_attn"

    echo

    use_mlock="${_params[use_mlock]}"
    if [[ "$use_mlock" == "true" ]]; then
        read -rp "  Lock in RAM [Y/n]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && use_mlock="true"
    else
        read -rp "  Lock in RAM [y/N]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && use_mlock="false"
    fi
    case "$input" in y|yes) use_mlock="true" ;; n|no) use_mlock="false" ;; esac
    _params[use_mlock]="$use_mlock"

    # --- Sampling parameters ---
    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    colorize "  Sampling Parameters:" "$COLOR_YELLOW${COLOR_BOLD}"
    echo

    temp="${_params[temp]}"
    read -rp "  Temperature [$temp]: " input
    [[ -z "$input" ]] && input="$temp"
    if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        temp="$input"
    else
        colorize "Invalid number, keeping: $temp" "$COLOR_YELLOW"
    fi
    _params[temp]="$temp"

    echo

    top_p="${_params[top_p]}"
    read -rp "  Top P [$top_p]: " input
    [[ -z "$input" ]] && input="$top_p"
    if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        top_p="$input"
    else
        colorize "Invalid number, keeping: $top_p" "$COLOR_YELLOW"
    fi
    _params[top_p]="$top_p"

    echo

    top_k="${_params[top_k]}"
    read -rp "  Top K [$top_k]: " input
    [[ -z "$input" ]] && input="$top_k"
    if [[ "$input" =~ ^-?[0-9]+$ ]]; then
        top_k="$input"
    else
        colorize "Invalid number, keeping: $top_k" "$COLOR_YELLOW"
    fi
    _params[top_k]="$top_k"

    echo

    min_p="${_params[min_p]}"
    read -rp "  Min P [$min_p]: " input
    [[ -z "$input" ]] && input="$min_p"
    if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        min_p="$input"
    else
        colorize "Invalid number, keeping: $min_p" "$COLOR_YELLOW"
    fi
    _params[min_p]="$min_p"

    echo

    presence_penalty="${_params[presence_penalty]}"
    read -rp "  Presence Penalty [$presence_penalty]: " input
    [[ -z "$input" ]] && input="$presence_penalty"
    if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        presence_penalty="$input"
    else
        colorize "Invalid number, keeping: $presence_penalty" "$COLOR_YELLOW"
    fi
    _params[presence_penalty]="$presence_penalty"

    echo

    repeat_penalty="${_params[repeat_penalty]}"
    read -rp "  Repeat Penalty [$repeat_penalty]: " input
    [[ -z "$input" ]] && input="$repeat_penalty"
    if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        repeat_penalty="$input"
    else
        colorize "Invalid number, keeping: $repeat_penalty" "$COLOR_YELLOW"
    fi
    _params[repeat_penalty]="$repeat_penalty"

    # --- Chat template kwargs (thinking control) ---
    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    colorize "  Chat Template Kwargs (Thinking Control):" "$COLOR_YELLOW${COLOR_BOLD}"
    echo

    enable_thinking="${_params[enable_thinking]}"
    if [[ "$enable_thinking" == "true" ]]; then
        read -rp "  Enable thinking [Y/n]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && enable_thinking="true"
    else
        read -rp "  Enable thinking [y/N]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && enable_thinking="false"
    fi
    case "$input" in y|yes) enable_thinking="true" ;; n|no) enable_thinking="false" ;; esac
    _params[enable_thinking]="$enable_thinking"

    echo

    preserve_thinking="${_params[preserve_thinking]}"
    if [[ "$preserve_thinking" == "true" ]]; then
        read -rp "  Preserve thinking output [Y/n]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && preserve_thinking="true"
    else
        read -rp "  Preserve thinking output [y/N]: " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        [[ -z "$input" ]] && preserve_thinking="false"
    fi
    case "$input" in y|yes) preserve_thinking="true" ;; n|no) preserve_thinking="false" ;; esac
    _params[preserve_thinking]="$preserve_thinking"

    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"

    # Rebuild the JSON string from the associative array
    SELECTED_MODEL_JSON="{"
    first=true
    for key in "${!_params[@]}"; do
        if [[ "$key" == "__model_params_raw" ]]; then continue; fi
        val="${_params[$key]}"
        if $first; then first=false; else SELECTED_MODEL_JSON+=", "; fi
        case "$val" in
            true|false|null) SELECTED_MODEL_JSON+="\"${key}\": ${val}" ;;
            [0-9]*|[0-9]*.[0-9]*) SELECTED_MODEL_JSON+="\"${key}\": ${val}" ;;
            *) SELECTED_MODEL_JSON+="\"${key}\": \"${val}\"" ;;
        esac
    done
    SELECTED_MODEL_JSON+="}"

    # Save the updated params
    save_model_params "$model_path" "$SELECTED_MODEL_JSON"
}

# ---------------------------------------------------------------------------
# configure_api_key — interactive API key editor
# ---------------------------------------------------------------------------
configure_api_key() {
    current_key="$(get_json_value "$CONFIG_JSON" "api_key")"

    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    colorize "  Configure API Key:" "$COLOR_YELLOW${COLOR_BOLD}"
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    echo
    colorize "Enter API key (leave empty to clear):" "$COLOR_YELLOW"

    if [[ -n "$current_key" ]]; then
        masked="${current_key:0:4}..."
        colorize "  Current: $masked" "$COLOR_CYAN"
    else
        colorize "  Current: (none)" "$COLOR_CYAN"
    fi

     read -rp "  New key: " new_key
    CONFIG_JSON="$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
data['api_key'] = sys.argv[1]
print(json.dumps(data, indent=4))
" "${new_key:-}")"
    config_save

    echo
    if [[ -z "$new_key" ]]; then
        colorize "API key cleared." "$COLOR_GREEN"
    else
        colorize "API key set." "$COLOR_GREEN"
    fi
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
}

# ---------------------------------------------------------------------------
# configure_address — interactive address/port editor
# Extracts port from the address string automatically.
# ---------------------------------------------------------------------------
configure_address() {
    current_address="$(get_json_value "$CONFIG_JSON" "address")"
    current_port="$(get_json_value "$CONFIG_JSON" "port")"

    echo
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    colorize "  Configure Address:" "$COLOR_YELLOW${COLOR_BOLD}"
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
    echo
    colorize "Enter server address (default: $DEFAULT_ADDRESS):" "$COLOR_YELLOW"
    colorize "  Current: $current_address:$current_port" "$COLOR_CYAN"

    read -rp "  New address: " new_addr
    if [[ -z "$new_addr" ]]; then
        return 0
    fi

     # Extract port if present in the address
    new_port="$current_port"
    if [[ "$new_addr" =~ :([0-9]{1,5})$ ]]; then
        new_port="${BASH_REMATCH[1]}"
    fi

    CONFIG_JSON="$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
data['address'] = sys.argv[1]
data['port'] = int(sys.argv[2])
print(json.dumps(data, indent=4))
" "$new_addr" "$new_port")"
    config_save

    echo
    colorize "Address set to: $new_addr:$new_port" "$COLOR_GREEN"
    colorize "------------------------------------------------------------" "$COLOR_BLUE"
}
