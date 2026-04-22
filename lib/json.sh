#!/usr/bin/env bash
# =============================================================================
# lib/json.sh — Lightweight JSON helpers (no jq required)
# Uses grep, cut, sed, and bash string manipulation.
# =============================================================================

# ---------------------------------------------------------------------------
# get_json_value JSON_STRING KEY
# Extracts a top-level value from flat JSON using grep + sed.
# Works for simple values: strings, numbers, booleans, null.
# Usage: val="$(get_json_value "$CONFIG_JSON" "last_model")"
# ---------------------------------------------------------------------------
get_json_value() {
    json_str="$1"
    key="$2"

    # Handle escaped quotes inside the key pattern for grep
    escaped_key="${key//\\/\\\\}"
    escaped_key="${escaped_key//\"/\\\"}"

    echo "$json_str" | tr -d '\n' | \
        grep -o "\"${escaped_key}\"[[:space:]]*:[[:space:]]*[^,}]*" | \
        sed "s/\"${escaped_key}\"[[:space:]]*:[[:space:]]*//" | \
        sed 's/^[" ]*//; s/[" ]*$//' | \
        tr -d '\n\r' || true
}

# ---------------------------------------------------------------------------
# parse_json_obj JSON_STRING [ARRAY_NAME]
# Parses a flat JSON object into an associative array.
# If ARRAY_NAME is given, uses that name (default: _json_parsed).
# Sets up the global associative array for get_json_value to use.
# Usage:
#   declare -A _parsed
#   parse_json_obj "$SELECTED_MODEL_JSON" "_parsed"
#   val="${_parsed[n_ctx]}"
# ---------------------------------------------------------------------------
parse_json_obj() {
    json_str="$1"
    arr_name="${2:-_json_parsed}"

    # Flatten multi-line JSON to single line, remove outer braces
    flat="$(echo "$json_str" | tr -d '\n\r' | sed 's/^ *{//; s/} *$//')"

    # Strip the model_params value (it's a nested object — we handle it separately)
    stripped_flat="$(echo "$flat" | grep -o '"model_params"[[:space:]]*:[[:space:]]*{[^"]*}' | sed 's/"model_params"[[:space:]]*:[[:space:]]*//' || true)"

    # Remove model_params key from the flattened string to avoid confusion
    if [[ -n "$stripped_flat" ]]; then
        clean_flat="$(echo "$flat" | sed "s/\"model_params\"[[:space:]]*:[[:space:]]*{[^}]*}//")"
    else
        clean_flat="$flat"
    fi

    # Evaluate the associative array assignment
    eval "${arr_name}=()"

    remaining="$clean_flat"
    while [[ -n "$remaining" ]]; do
        # Extract next key-value pair: find first comma at top level or end of string
        kv_pair=""
        rest=""

        if [[ "$remaining" == *,* ]]; then
           # Find the comma that separates key-value pairs (not inside quotes)
            in_quote=false
            pos=0
            comma_pos=-1
            tmp="$remaining"
            while [[ -n "$tmp" ]]; do
                char="${tmp:0:1}"
                if [[ "$char" == '"' ]]; then
                    if $in_quote; then in_quote=false; else in_quote=true; fi
                elif [[ "$char" == ',' && $in_quote == false ]]; then
                    comma_pos=$pos
                    break
                fi
                pos=$((pos + 1))
                tmp="${tmp:1}"
            done

            if [[ $comma_pos -ge 0 ]]; then
                kv_pair="${remaining:0:$comma_pos}"
                rest="${remaining:$((comma_pos + 1))}"
            else
                kv_pair="$remaining"
                rest=""
            fi
        else
            kv_pair="$remaining"
            rest=""
        fi

        # Parse key:value — split on first colon (outside quotes)
        k=""
        v=""
        if [[ "$kv_pair" == *:* ]]; then
            k="$(echo "$kv_pair" | cut -d: -f1 | sed 's/^[" ]*//; s/[" ]*$//')"
            v="$(echo "$kv_pair" | cut -d: -f2- | sed 's/^[" ]*//; s/[" ]*$//')"
        else
            k="$kv_pair"
            v=""
        fi

        # Remove surrounding quotes from value
        v="${v#\"}"
        v="${v%\"}"

        # Store in array
        eval "${arr_name}[\"${k}\"]=\"${v}\""

        remaining="$rest"
    done

    # Also store the raw model_params string for later parsing
    if [[ -n "$stripped_flat" ]]; then
        eval "${arr_name}[__model_params_raw]=\"${stripped_flat}\""
    fi
}

# ---------------------------------------------------------------------------
# get_nested_json_value JSON_STRING KEY
# Extracts a value from the model_params nested object.
# Usage: val="$(get_nested_json_value "$SELECTED_MODEL_JSON" "n_ctx")"
# ---------------------------------------------------------------------------
get_nested_json_value() {
    json_str="$1"
    key="$2"

    # Extract the model_params block (everything between { and matching })
    mp_block
    mp_block="$(echo "$json_str" | tr -d '\n' | sed -n 's/.*"model_params"[[:space:]]*:[[:space:]]*{//p')"

    if [[ -z "$mp_block" ]]; then
        echo ""
        return
    fi

    # Find the matching closing brace by counting depth
    depth=1
    i=0
    in_quote=false
    while [[ $depth -gt 0 && $i -lt ${#mp_block} ]]; do
        ch="${mp_block:$i:1}"
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

    inner="${mp_block:0:$((i - 1))}"

    # Extract the specific key from the inner block
    echo "$inner" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[^,}]*" | \
        sed "s/\"${key}\"[[:space:]]*:[[:space:]]*//" | \
        sed 's/^[" ]*//; s/[" ]*$//' | \
        tr -d '\n' || true
}

# ---------------------------------------------------------------------------
# build_json KEY1 VAL1 [KEY2 VAL2 ...]
# Builds a flat JSON object string from key-value pairs.
# Usage: json="$(build_json n_ctx 4096 cache_type q4_0 threads 8)"
# ---------------------------------------------------------------------------
build_json() {
    result="{"
    first=true
    while [[ $# -ge 2 ]]; do
        if $first; then
            first=false
        else
            result+=", "
        fi
        # Quote string values, leave numbers/booleans/null unquoted
         k="$1" v="$2"
        shift 2
        case "$v" in
            true|false|null) result+="\"${k}\": ${v}" ;;
            [0-9]*|[0-9]*.[0-9]*) result+="\"${k}\": ${v}" ;;
            *) result+="\"${k}\": \"${v}\"" ;;
        esac
    done
    result+="}"
    echo "$result"
}
