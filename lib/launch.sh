#!/usr/bin/env bash
# =============================================================================
# lib/launch.sh — Build the llama-server command and launch it (or dry-run)
# No jq required — uses grep/cut/sed from lib/json.sh.
# Uses the global variables set by config.sh, menu.sh, and utils.sh.
# =============================================================================

# ---------------------------------------------------------------------------
# build_launch_command MODEL_PATH PARAMS_JSON [API_KEY]
# Assembles the full llama-server CLI command into BUILD_LAUNCH_CMD (display, masked).
# Also sets BUILD_LAUNCH_ARRAY (global) as an array for direct execution.
# Returns via global variables.
# ---------------------------------------------------------------------------
BUILD_LAUNCH_CMD=""
BUILD_LAUNCH_ARRAY=()

build_launch_command() {
    model_path="$1"
    params_json="$2"
    api_key="${3:-}"

    # Parse all parameters from the JSON into an associative array
    declare -A _p
    parse_json_obj "$params_json" "_p"

    n_ctx="${_p[n_ctx]}"
    n_gpu_layers="${_p[n_gpu_layers]}"
    threads="${_p[threads]}"
    batch_size="${_p[batch_size]}"
    cache_type_k="${_p[cache_type_k]}"
    cache_type_v="${_p[cache_type_v]}"
    use_flash_attn="${_p[use_flash_attn]}"
    use_mlock="${_p[use_mlock]}"
    temp="${_p[temp]}"
    top_p="${_p[top_p]}"
    top_k="${_p[top_k]}"
    min_p="${_p[min_p]}"
    presence_penalty="${_p[presence_penalty]}"
    repeat_penalty="${_p[repeat_penalty]}"
    enable_thinking="${_p[enable_thinking]}"
    preserve_thinking="${_p[preserve_thinking]}"

    # Build the command array (use an array to handle quoting correctly)
    BUILD_LAUNCH_ARRAY=()
    BUILD_LAUNCH_ARRAY+=("$LLAMA_SERVER_PATH")
    BUILD_LAUNCH_ARRAY+=("-m" "$model_path")
    BUILD_LAUNCH_ARRAY+=("--ctx-size" "$n_ctx")
    BUILD_LAUNCH_ARRAY+=("--host" "0.0.0.0")
    BUILD_LAUNCH_ARRAY+=("--port" "$SERVER_PORT")
    BUILD_LAUNCH_ARRAY+=("-ngl" "$n_gpu_layers")
    BUILD_LAUNCH_ARRAY+=("-t" "$threads")
    BUILD_LAUNCH_ARRAY+=("--batch-size" "$batch_size")

    # KV Cache types -- only add flags if not "none"
    if [[ "$cache_type_k" != "none" ]]; then
        BUILD_LAUNCH_ARRAY+=("--cache-type-k" "$cache_type_k")
    fi
    if [[ "$cache_type_v" != "none" ]]; then
        BUILD_LAUNCH_ARRAY+=("--cache-type-v" "$cache_type_v")
    fi

    # Sampling parameters
    BUILD_LAUNCH_ARRAY+=("--temp" "$temp")
    BUILD_LAUNCH_ARRAY+=("--top-p" "$top_p")
    BUILD_LAUNCH_ARRAY+=("--top-k" "$top_k")
    BUILD_LAUNCH_ARRAY+=("--min-p" "$min_p")
    BUILD_LAUNCH_ARRAY+=("--presence-penalty" "$presence_penalty")
    BUILD_LAUNCH_ARRAY+=("--repeat-penalty" "$repeat_penalty")

    # Fixed flags
    BUILD_LAUNCH_ARRAY+=("--no-cache-prompt")
    BUILD_LAUNCH_ARRAY+=("--verbose")
    BUILD_LAUNCH_ARRAY+=("--offline")

    # Chat template kwargs -- always pass both values to control thinking behavior
    chat_kwargs="$(build_json enable_thinking "$enable_thinking" preserve_thinking "$preserve_thinking")"
    BUILD_LAUNCH_ARRAY+=("--chat-template-kwargs" "'${chat_kwargs}'")

    # CLI-level chat template kwargs (from user flags) — merge on top if provided
    if [[ -n "${CLI_CHAT_TEMPLATE_KWARGS:-}" ]]; then
        BUILD_LAUNCH_ARRAY+=("--chat-template-kwargs" "'${CLI_CHAT_TEMPLATE_KWARGS}'")
    fi

    # API key
    if [[ -n "$api_key" ]]; then
        BUILD_LAUNCH_ARRAY+=("--api-key" "$api_key")
    fi

    # Flash attention (special: "--flash-attn on")
    if [[ "$use_flash_attn" == "true" ]]; then
        BUILD_LAUNCH_ARRAY+=("--flash-attn" "on")
    fi

    # Mlock
    if [[ "$use_mlock" == "true" ]]; then
        BUILD_LAUNCH_ARRAY+=("--mlock")
    fi

    # Join into a display string (with API key masked)
    BUILD_LAUNCH_CMD=""
    for arg in "${BUILD_LAUNCH_ARRAY[@]}"; do
        if [[ -n "$BUILD_LAUNCH_CMD" ]]; then
            BUILD_LAUNCH_CMD+=" "
        fi
        BUILD_LAUNCH_CMD+="$arg"
    done

    # Mask API key in the display string
    local masked_cmd=""
    local skip_next=false
    for arg in "${BUILD_LAUNCH_ARRAY[@]}"; do
        if [[ -n "$masked_cmd" ]]; then
            masked_cmd+=" "
        fi
        if $skip_next; then
            masked_cmd+="***"
            skip_next=false
            continue
        fi
        if [[ "$arg" == "--api-key" ]]; then
            skip_next=true
            masked_cmd+="$arg"
        else
            masked_cmd+="$arg"
        fi
    done

    BUILD_LAUNCH_CMD="$masked_cmd"
}

# ---------------------------------------------------------------------------
# launch_server MODEL_PATH [PARAMS_JSON]
# Builds the command and either prints it (dry-run) or executes it.
# Also logs to ~/.llama-launcher.log.
# ---------------------------------------------------------------------------
launch_server() {
    model_path="${1:-}"
    params_json="${2:-}"

    api_key="$(get_json_value "$CONFIG_JSON" "api_key")"

    # Determine model path from config if not passed explicitly
    if [[ -z "$model_path" ]]; then
        model_path="$(get_json_value "$CONFIG_JSON" "last_model")"
    fi

    if [[ -z "$model_path" ]]; then
        echo
        colorize "No model selected. Please choose a model first." "$COLOR_YELLOW"
        return 1
    fi

    # Validate model file exists
    if [[ ! -f "$model_path" ]]; then
        echo
        colorize "Error: Model file not found: $model_path" "$COLOR_RED" >&2
        return 1
    fi

    # Resolve per-model params
    if [[ -z "$params_json" ]]; then
        params_json="$(get_model_params "$model_path" "${CLI_TEMP:-0.6}" "${CLI_TOP_P:-0.95}" "${CLI_TOP_K:-20}" "${CLI_MIN_P:-0.0}" "${CLI_PRESENCE_PENALTY:-1.5}" "${CLI_REPEAT_PENALTY:-1.0}")"
    fi

    # Build the command (parses JSON into BUILD_LAUNCH_ARRAY and BUILD_LAUNCH_CMD)
    build_launch_command "$model_path" "$params_json" "$api_key"

    display_cmd="$BUILD_LAUNCH_CMD"

    # Parse params once for display (reuse _p from build_launch_command)
    declare -A _lp
    parse_json_obj "$params_json" "_lp"

    n_ctx="${_lp[n_ctx]}"
    n_gpu_layers="${_lp[n_gpu_layers]}"
    threads="${_lp[threads]}"
    batch_size="${_lp[batch_size]}"
     cache_type_k="${_lp[cache_type_k]}"
    cache_type_v="${_lp[cache_type_v]}"
    use_flash_attn="${_lp[use_flash_attn]}"
    use_mlock="${_lp[use_mlock]}"
    temp="${_lp[temp]}"
    top_p="${_lp[top_p]}"
    top_k="${_lp[top_k]}"
    min_p="${_lp[min_p]}"
    enable_thinking="${_lp[enable_thinking]}"
    preserve_thinking="${_lp[preserve_thinking]}"
    presence_penalty="${_lp[presence_penalty]}"
    repeat_penalty="${_lp[repeat_penalty]}"

    # Print the launch banner
    echo
    colorize "============================================================" "$COLOR_BLUE"
    colorize "  Starting llama-server..." "$COLOR_GREEN${COLOR_BOLD}"
    colorize "============================================================" "$COLOR_BLUE"
    echo
    colorize "  Model:" "$COLOR_CYAN" "$(basename "$model_path")"
    config_address="$(get_json_value "$CONFIG_JSON" "address")"
    server_port_val="$(get_json_value "$CONFIG_JSON" "port")"
    colorize "  Address:" "$COLOR_CYAN" "${config_address}:${server_port_val}"
    if [[ -n "$api_key" ]]; then
        colorize "  API Key:" "$COLOR_CYAN" "*** (configured)"
    fi
    echo
    colorize "  Parameters:" "$COLOR_YELLOW${COLOR_BOLD}"
    colorize "  --------------------------------------------------------" "$COLOR_BLUE"
    echo "    Context length: $n_ctx"
    echo "    GPU layers:   $n_gpu_layers"
    echo "    Threads:      $threads"
    echo "    Batch size:   $batch_size"
    echo "    KV Cache K:   $cache_type_k"
    echo "    KV Cache V:   $cache_type_v"
    echo "    Flash Attn:   $use_flash_attn"
    echo "    Lock RAM:     $use_mlock"
    echo "    Enable Thinking: $enable_thinking"
    echo "    Preserve Thinking: $preserve_thinking"
    colorize "  --------------------------------------------------------" "$COLOR_BLUE"
    colorize "  Sampling:" "$COLOR_YELLOW${COLOR_BOLD}"
    echo "      Temperature:      $temp"
    echo "      Top P:            $top_p"
    echo "      Top K:            $top_k"
    echo "      Min P:            $min_p"
    echo "      Presence Penalty: $presence_penalty"
    echo "      Repeat Penalty:   $repeat_penalty"
    colorize "  --------------------------------------------------------" "$COLOR_BLUE"
    echo

    colorize "  COMMAND:" "$COLOR_MAGENTA${COLOR_BOLD}"
    echo "    $display_cmd"
    echo
    colorize "  Press Ctrl+C to stop" "$COLOR_RED"
    echo

    # Log to file
    log_file="$HOME/.llama-launcher.log"
    echo "$(date -Iseconds) | $display_cmd" >> "$log_file"

    # Dry-run mode: just print and exit
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        colorize "[DRY RUN] Command displayed above. Not launching." "$COLOR_YELLOW"
        return 0
    fi

    # Reuse the command array from build_launch_command (no duplication)
     exec_cmd=("${BUILD_LAUNCH_ARRAY[@]}")

    echo "${exec_cmd[@]} "

    echo "${exec_cmd[@]} " > ./run.sh
    bash run.sh
}
