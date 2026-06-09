#!/usr/bin/env bash
set -euo pipefail

JAR="target/llm-cli-tool-1.0.0.jar"

if [[ ! -f "$JAR" ]]; then
    echo "JAR not found at $JAR. Run 'mvn clean package' first." >&2
    exit 1
fi

exec java -jar "$JAR"
