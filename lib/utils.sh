#!/usr/bin/env bash
# =============================================================================
# lib/utils.sh — Utility functions: GGUF scanning, binary discovery, input helpers
# No jq required.
# =============================================================================

# Number of CPU cores for default thread count (set in main script)
DEFAULT_NPROC="${NPROC:-$(nproc 2>/dev/null || echo 4)}"

# ---------------------------------------------------------------------------
# scan_gguf_files — find all .gguf files in common locations
# Populates the global array GGUF_LIST as "path|name|size_mb" lines.
# Sorted by size descending (largest first).
# ---------------------------------------------------------------------------
declare -a GGUF_LIST=()

scan_gguf_files() {
    GGUF_LIST=()
    tmpfile="$(mktemp)"

    # Directories to scan
    search_dirs=(
        "$HOME/.lmstudio/models"
        "$HOME/Models"
        "$HOME/Downloads"
        "./Models"
    )

    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -maxdepth 10 -name '*.gguf' -type f 2>/dev/null | while read -r filepath; do
                size_bytes="$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)"
                # Convert to MB with one decimal using awk
                size_mb="$(awk "BEGIN {printf \"%.1f\", $size_bytes / 1048576}")"
                printf '%s|%s|%s\n' "$filepath" "$(basename "$filepath")" "$size_mb" >> "$tmpfile"
            done
        fi
    done

    # Sort by size (field 3) descending, store in array
    if [[ -s "$tmpfile" ]]; then
        while IFS='|' read -r fpath fname fsize; do
            GGUF_LIST+=("$fpath|$fname|$fsize")
        done < <(sort -t'|' -k3 -rn "$tmpfile")
    fi

    rm -f "$tmpfile"
}

# ---------------------------------------------------------------------------
# find_llama_server — locate the llama-server binary
# Populates LLAMA_SERVER_PATH (global). Returns 1 if not found.
# ---------------------------------------------------------------------------
LLAMA_SERVER_PATH=""

find_llama_server() {
    candidates=(
        "$HOME/Modèles/llama.cpp/build/bin/llama-server"
        "$HOME/llama.cpp/build/bin/llama-server"
        "/usr/local/bin/llama-server"
        "/usr/bin/llama-server"
        "./build/bin/llama-server"
    )

    for cand in "${candidates[@]}"; do
        if [[ -x "$cand" ]]; then
            LLAMA_SERVER_PATH="$cand"
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# prompt_int VAR_NAME PROMPT_TEXT DEFAULT
# Reads an integer from the user, validates it, sets VAR_NAME.
# ---------------------------------------------------------------------------
prompt_int() {
    var_name="$1"
    prompt_text="$2"
    default_val="$3"

    input=""
    while true; do
        read -rp "$prompt_text" input
        if [[ -z "$input" ]]; then
            eval "$var_name='$default_val'"
            return 0
        fi
        if [[ "$input" =~ ^-?[0-9]+$ ]]; then
            eval "$var_name='$input'"
            return 0
        fi
        colorize "Invalid number, using default: $default_val" "$COLOR_YELLOW"
        echo
    done
}

# ---------------------------------------------------------------------------
# prompt_float VAR_NAME PROMPT_TEXT DEFAULT
# Reads a float from the user, validates it, sets VAR_NAME.
# ---------------------------------------------------------------------------
prompt_float() {
    var_name="$1"
    prompt_text="$2"
    default_val="$3"

    input=""
    while true; do
        read -rp "$prompt_text" input
        if [[ -z "$input" ]]; then
            eval "$var_name='$default_val'"
            return 0
        fi
        # Validate float (integer is also valid)
        if [[ "$input" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
            eval "$var_name='$input'"
            return 0
        fi
        colorize "Invalid number, keeping current value: $default_val" "$COLOR_YELLOW"
        echo
    done
}

# ---------------------------------------------------------------------------
# prompt_bool VAR_NAME PROMPT_TEXT DEFAULT_IS_TRUE
# Reads y/n, sets VAR_NAME to "true" or "false".
# ---------------------------------------------------------------------------
prompt_bool() {
    var_name="$1"
    prompt_text="$2"
    default_is_true="${3:-true}"

    if [[ "$default_is_true" == "true" ]]; then
        default_char="Y/n"
    else
        default_char="y/N"
    fi

    input=""
    while true; do
        read -rp "$prompt_text ($default_char): " input
        input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
        if [[ -z "$input" ]]; then
            if [[ "$default_is_true" == "true" ]]; then
                eval "$var_name='true'"
            else
                eval "$var_name='false'"
            fi
            return 0
        fi
        case "$input" in
            y|yes) eval "$var_name='true'"; return 0 ;;
            n|no)  eval "$var_name='false'"; return 0 ;;
            *) colorize "Please enter y or n" "$COLOR_YELLOW"; echo ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# prompt_choice VAR_NAME PROMPT_TEXT DEFAULT
# Generic input with default. Sets VAR_NAME.
# ---------------------------------------------------------------------------
prompt_choice() {
    var_name="$1"
    prompt_text="$2"
    default_val="$3"

    read -rp "$prompt_text" var_name
    if [[ -z "${!var_name}" ]]; then
        eval "$var_name='$default_val'"
    fi
}

# ---------------------------------------------------------------------------
# truncate_path PATH MAX_LENGTH — shorten path display for menus
# Outputs the truncated path to stdout.
# ---------------------------------------------------------------------------
truncate_path() {
    filepath="$1"
    max_len="${2:-40}"
    base="$(basename "$filepath")"

    if [[ ${#base} -le $max_len ]]; then
        echo "$base"
    else
        tail_len=$((max_len - 3))
        printf '…%s' "${filepath: -$tail_len}"
    fi
}
