#!/usr/bin/env bash
# =============================================================================
# lib/config.sh — Configuration management (load, save, defaults)
# No jq required — uses grep/cut/sed from lib/json.sh.
# =============================================================================

# Where the config lives
CONFIG_FILE="${LLM_ENV_DIR:-$HOME/Documents/LLM_env}/llama-launcher-config.json"

# Default server address
DEFAULT_ADDRESS="http://localhost:8080"
DEFAULT_PORT=8080

# ---------------------------------------------------------------------------
# get_default_model_params — return the default parameter set as a JSON string
# Called when a model has no stored params yet.
# ---------------------------------------------------------------------------
get_default_model_params() {
    cli_temp="${1:-0.6}"
    cli_top_p="${2:-0.95}"
    cli_top_k="${3:-20}"
    cli_min_p="${4:-0.0}"
    cli_presence_penalty="${5:-1.5}"
    cli_repeat_penalty="${6:-1.0}"

    build_json \
        n_ctx 125000 \
        n_gpu_layers auto \
        threads "$DEFAULT_NPROC" \
        batch_size 1024 \
        cache_type q8_0 \
        use_flash_attn true \
        use_mlock true \
        temp "$cli_temp" \
        top_p "$cli_top_p" \
        top_k "$cli_top_k" \
        min_p "$cli_min_p" \
        presence_penalty "$cli_presence_penalty" \
        repeat_penalty "$cli_repeat_penalty" \
        enable_thinking true \
        preserve_thinking true
}

# ---------------------------------------------------------------------------
# config_init — create a fresh default config file
# ---------------------------------------------------------------------------
config_init() {
    cli_temp="${1:-0.6}"
    cli_top_p="${2:-0.95}"
    cli_top_k="${3:-20}"
    cli_min_p="${4:-0.0}"
    cli_presence_penalty="${5:-1.5}"
    cli_repeat_penalty="${6:-1.0}"

    default_params="$(get_default_model_params "$cli_temp" "$cli_top_p" "$cli_top_k" "$cli_min_p" "$cli_presence_penalty" "$cli_repeat_penalty")"

    # Write JSON directly — no jq needed
    cat > "$CONFIG_FILE" <<EOF
{
    "last_model": null,
    "api_key": "",
    "address": "${DEFAULT_ADDRESS}",
    "port": ${DEFAULT_PORT},
    "model_params": {}
}
EOF
}

# ---------------------------------------------------------------------------
# config_load — read config from disk into CONFIG_JSON variable
# Returns 1 if file is missing or corrupt.
# ---------------------------------------------------------------------------
CONFIG_JSON=""

config_load() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi

    # Read and validate JSON (basic check: must start with { and end with })
    CONFIG_JSON="$(cat "$CONFIG_FILE")"
    first_char="${CONFIG_JSON:0:1}"
    # Flatten to one line, then grab the last non-whitespace char
    flat_json="$(echo "$CONFIG_JSON" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    last_char="${flat_json: -1}"

    if [[ "$first_char" != "{" || "$last_char" != "}" ]]; then
        return 1
    fi

  # Ensure model_params key exists (backward compat)
    if ! echo "$CONFIG_JSON" | grep -q '"model_params"'; then
        CONFIG_JSON="$(python3 -c "
import json
data = json.loads(sys.argv[1])
if 'model_params' not in data:
    data['model_params'] = {}
print(json.dumps(data, indent=4))
" "$CONFIG_JSON")"
    fi

    return 0
}

# ---------------------------------------------------------------------------
# config_save — write CONFIG_JSON back to disk (pretty-printed via Python)
# ---------------------------------------------------------------------------
config_save() {
    echo "$CONFIG_JSON" | python3 -c "import json,sys; data=json.load(sys.stdin); print(json.dumps(data,indent=4))" > "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# config_get KEY — get a top-level value from CONFIG_JSON
# Usage:  val="$(config_get last_model)"
#         val="$(config_get api_key)"
# ---------------------------------------------------------------------------
config_get() {
    key="$1"
    get_json_value "$CONFIG_JSON" "$key"
}

# ---------------------------------------------------------------------------
# config_set KEY VALUE — set a top-level key and save
# Usage:  config_set last_model "/path/to/model.gguf"
#         config_set api_key "mykey123"
# Uses Python for reliable JSON manipulation.
# ---------------------------------------------------------------------------
config_set() {
    key="$1"
    value="$2"

    CONFIG_JSON="$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
k = sys.argv[1]
v = sys.argv[2]
# Try to parse as number/bool/null; fall back to string
try:
    if v.lower() == 'true':
        data[k] = True
    elif v.lower() == 'false':
        data[k] = False
    elif v.lower() == 'null':
        data[k] = None
    else:
        try:
            data[k] = int(v)
        except ValueError:
            try:
                data[k] = float(v)
            except ValueError:
                data[k] = v
except Exception:
    data[k] = v
print(json.dumps(data, indent=4))
" "$key" "$value")"

    config_save
}

# ---------------------------------------------------------------------------
# _extract_brace_block INPUT START_KEY — find a block between { and matching }
# Sets global BRACE_RESULT with the content inside the braces.
# Uses depth counting to handle nested objects correctly.
# ---------------------------------------------------------------------------
BRACE_RESULT=""

_extract_brace_block() {
    input="$1"
    start_key="$2"

    # Find the opening brace after the key
    block="$(echo "$input" | tr -d '\n' | sed -n "s/.*\"${start_key}\"[[:space:]]*:[[:space:]]*{//p")"

    if [[ -z "$block" ]]; then
        BRACE_RESULT=""
        return
    fi

    # Count braces to find matching close
    depth=1
    i=0
    in_quote=false
    while [[ $depth -gt 0 && $i -lt ${#block} ]]; do
        ch="${block:$i:1}"
        if [[ "$ch" == '"' ]]; then
            if $in_quote; then in_quote=false; else in_quote=true; fi
        elif [[ $in_quote == false ]]; then
            if [[ "$ch" == "{" ]]; then
                depth=$((depth + 1))
            elif [[ "$ch" == "}" ]]; then
                depth=$((depth - 1))
            fi
        fi
        i=$((i + 1))
    done

    BRACE_RESULT="${block:0:$((i - 1))}"
}

# ---------------------------------------------------------------------------
# get_model_params MODEL_PATH — return the params JSON for a given model
# Creates defaults if none exist, and merges missing keys.
# ---------------------------------------------------------------------------
get_model_params() {
    model_path="$1"
    cli_temp="${2:-0.6}"
    cli_top_p="${3:-0.95}"
    cli_top_k="${4:-20}"
    cli_min_p="${5:-0.0}"
    cli_presence_penalty="${6:-1.5}"
    cli_repeat_penalty="${7:-1.0}"

    # Extract model_params block from CONFIG_JSON
    _extract_brace_block "$CONFIG_JSON" "model_params"
    inner_mp="$BRACE_RESULT"

    # Check if this model has stored params (look for its path as a key)
    stored_params=""
    escaped_model="$(echo "$model_path" | sed 's/[\/&]/\\&/g')"
    if echo "$inner_mp" | grep -q "\"${escaped_model}\""; then
        # Extract the value for this model's key — grab everything after ": " until matching }
        _extract_brace_block "$inner_mp" "$model_path"
        raw_val="$BRACE_RESULT"

        if [[ -n "$raw_val" ]]; then
            stored_params="$raw_val"
        fi
    fi

    if [[ -z "$stored_params" ]]; then
        stored_params="$(get_default_model_params "$cli_temp" "$cli_top_p" "$cli_top_k" "$cli_min_p" "$cli_presence_penalty" "$cli_repeat_penalty")"
    fi

    # Merge with defaults to fill any missing keys
    defaults="$(get_default_model_params "$cli_temp" "$cli_top_p" "$cli_top_k" "$cli_min_p" "$cli_presence_penalty" "$cli_repeat_penalty")"

    # Parse both into temp arrays, then merge (stored values override defaults)
    declare -A _defaults
    parse_json_obj "$defaults" "_defaults"

    declare -A _stored
    parse_json_obj "$stored_params" "_stored"

    # Build merged JSON: start with defaults, override with stored
    merged="{"
    first=true
    for dk in "${!_defaults[@]}"; do
        if [[ "$dk" == "__model_params_raw" ]]; then continue; fi
        if $first; then first=false; else merged+=", "; fi
        dv="${_defaults[$dk]}"
        sv="${_stored[$dk]:-$dv}"
        case "$sv" in
            true|false|null) merged+="\"${dk}\": ${sv}" ;;
            [0-9]*|[0-9]*.[0-9]*) merged+="\"${dk}\": ${sv}" ;;
            *) merged+="\"${dk}\": \"${sv}\"" ;;
        esac
    done

    # Add any keys only in stored (shouldn't happen but be safe)
    for sk in "${!_stored[@]}"; do
        if [[ "$sk" == "__model_params_raw" ]]; then continue; fi
        if [[ -z "${_defaults[$sk]:-}" ]]; then
            merged+=", "
            sv="${_stored[$sk]}"
            case "$sv" in
                true|false|null) merged+="\"${sk}\": ${sv}" ;;
                [0-9]*|[0-9]*.[0-9]*) merged+="\"${sk}\": ${sv}" ;;
                *) merged+="\"${sk}\": \"${sv}\"" ;;
            esac
        fi
    done
    merged+="}"

    echo "$merged"
}

# ---------------------------------------------------------------------------
# save_model_params MODEL_PATH PARAMS_JSON — store params for a model
# Uses Python for reliable JSON manipulation (avoiding fragile sed/awk).
# ---------------------------------------------------------------------------
save_model_params() {
    model_path="$1"
    params_json="$2"

    # Use Python to safely update the JSON config file
    CONFIG_JSON="$(python3 -c "
import json, sys

with open('$CONFIG_FILE') as f:
    data = json.load(f)

model = sys.argv[1]
params = json.loads(sys.argv[2])

if 'model_params' not in data:
    data['model_params'] = {}
data['model_params'][model] = params

# Write back pretty-printed
print(json.dumps(data, indent=4))
" "$model_path" "$params_json")"

    config_save
}
