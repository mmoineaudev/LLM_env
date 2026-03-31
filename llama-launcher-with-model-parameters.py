#!/usr/bin/env python3
"""
llama.cpp Launcher - Interactive CLI for llama-server
======================================================
A simple launcher to manage GGUF models and start llama-server with configuration.

USAGE:
    Run this script directly. It will scan common locations for GGUF files,
    save your preferences, and provide an interactive menu.

CONFIGURATION:
    Settings are stored in ~/.llama-launcher-config.json
"""

import json
import os
import subprocess
import sys
import datetime
import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional

# ANSI color codes
class Colors:
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    WHITE = "\033[97m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

def colorize(text: str, color: str) -> str:
    return f"{color}{text}{Colors.RESET}"

# Configuration file location
CONFIG_FILE = Path.home() / ".llama-launcher-config.json"

# Default server address
DEFAULT_ADDRESS = "http://localhost:8080"

class Launcher:
    def __init__(self, cli_sampling_params=None):
        self.config = self.load_config()
        self.llama_server_path = self.find_llama_server()
        self.gguf_files = self.scan_gguf_files()
        self.cli_sampling_params = cli_sampling_params or {}

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file or create default."""
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, "r") as f:
                    config = json.load(f)
                # Ensure model_params exists (for configs created before this feature)
                if "model_params" not in config:
                    config["model_params"] = {}
                return config
            except (json.JSONDecodeError, IOError):
                pass

        # Default configuration
        return {
            "last_model": None,
            "api_key": "",
            "address": DEFAULT_ADDRESS,
            "port": 8080,
            "model_params": {}  # Per-model parameter storage
        }
    
    def get_default_model_params(self) -> Dict[str, Any]:
        """Return default parameters for a new model."""
        return {
            "n_ctx": 125000,
            "n_gpu_layers": 999,
            "threads": 22,
            "batch_size": 524,
            "cache_type": "q4_0",
            "use_flash_attn": True,
            "use_mlock": True,
            # Sampling parameters (use CLI values if provided, otherwise defaults)
            "temp": self.cli_sampling_params.get("temp", 0.7),
            "top_p": self.cli_sampling_params.get("top_p", 0.8),
            "top_k": self.cli_sampling_params.get("top_k", 20),
            "min_p": self.cli_sampling_params.get("min_p", 0.00),
            "presence_penalty": self.cli_sampling_params.get("presence_penalty", 1.5),
            "repeat_penalty": self.cli_sampling_params.get("repeat_penalty", 1.0),
        }

    def save_config(self) -> None:
        """Save current configuration to file."""
        with open(CONFIG_FILE, "w") as f:
            json.dump(self.config, f, indent=2)

    def find_llama_server(self) -> Optional[str]:
        """Find llama-server binary in common locations."""
        candidates = [
            Path.home() / "Modèles/llama.cpp/build/bin/llama-server",
            Path("~/llama.cpp/build/bin/llama-server").expanduser(),
            Path("~/llama.cpp/build/bin/llama-server").expanduser(),
            Path("/usr/local/bin/llama-server"),
            Path("/usr/bin/llama-server"),
        ]

        for path in candidates:
            if path.exists() and os.access(path, os.X_OK):
                return str(path)

        # Check current directory
        if (Path.cwd() / "build" / "bin" / "llama-server").exists():
            return str(Path.cwd() / "build" / "bin" / "llama-server")

        return None

    def scan_gguf_files(self) -> List[Dict[str, Any]]:
        """Scan for GGUF model files in common locations."""
        gguf_paths = [
            Path.home() / ".lmstudio/models",
            Path("~/Models").expanduser(),
            Path("~/Downloads"),
            Path("./Models"),
        ]

        models = []
        for base_path in gguf_paths:
            expanded = base_path.expanduser()
            if not expanded.exists():
                continue
            try:
                for file in expanded.rglob("*.gguf"):
                    size_mb = file.stat().st_size / (1024 * 1024)
                    models.append(
                        {
                            "path": str(file),
                            "name": file.name,
                            "size_mb": round(size_mb, 2),
                        }
                    )
            except PermissionError:
                pass

        return sorted(models, key=lambda x: -x["size_mb"])

    def display_header(self) -> None:
        """Display the launcher header with help text."""
        print("\n" + colorize("=" * 60, Colors.BLUE))
        print(colorize("  llama.cpp Launcher", Colors.GREEN + Colors.BOLD))
        print(colorize("=" * 60, Colors.BLUE))
        print()
        print(colorize("  Interactive CLI launcher for llama-server", Colors.CYAN))
        print()
        print(colorize("  OPTIONS:", Colors.YELLOW + Colors.BOLD))
        print(colorize("  1. Load last used model and start server", Colors.GREEN))
        print(colorize("     - Starts llama-server with the previously selected model", Colors.WHITE))
        print()
        print(colorize("  2. Choose a model then launch it", Colors.GREEN))
        print(colorize("     - Browse available GGUF files and select one to run", Colors.WHITE))
        print()
        print(colorize("  3. Configure API key", Colors.GREEN))
        print(colorize("     - Set or clear the authentication key for llama-server", Colors.WHITE))
        print()
        print(colorize("  4. Configure address (default: http://localhost:8080)", Colors.GREEN))
        print(colorize("     - Change server host and port settings", Colors.WHITE))
        print()
        print(colorize("  5. Exit", Colors.RED))
        print()

    def choose_model(self) -> Optional[Dict[str, Any]]:
        """Interactive model selection with file listing."""
        if not self.gguf_files:
            print("\n" + colorize("No GGUF files found in common locations.", Colors.RED))
            return None

        print("\n" + colorize("Available models:", Colors.YELLOW + Colors.BOLD))
        for i, model in enumerate(self.gguf_files, 1):
            marker = colorize(" (last used)", Colors.GREEN) if self.config["last_model"] == model["path"] else ""
            path_display = (
                os.path.basename(model["path"])
                if len(os.path.basename(model["path"])) < 40
                else model["path"]
            )
            print(f"  {i}. {colorize(path_display, Colors.CYAN)} ({model['size_mb']:.1f} MB){marker}")
        print()

        while True:
            choice = input("Enter model number (or 'q' to quit): ").strip()
            if choice.lower() == "q":
                return None
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(self.gguf_files):
                    selected = self.gguf_files[idx]
                    model_path = selected["path"]
                    self.config["last_model"] = model_path

                    # Load per-model params or use defaults
                    if model_path not in self.config["model_params"]:
                        self.config["model_params"][model_path] = self.get_default_model_params()
                    params = self.config["model_params"][model_path]
                    
                    # Merge with defaults to add any missing keys (for old configs)
                    defaults = self.get_default_model_params()
                    for key, value in defaults.items():
                        if key not in params:
                            params[key] = value

                    # Show current params for this model
                    print(f"\n{colorize('Current parameters for this model:', Colors.YELLOW)}")
                    print(f"  Context length: {params['n_ctx']}")
                    print(f"  GPU layers: {params['n_gpu_layers']} (999=max)")
                    print(f"  Threads: {params['threads']}")
                    print(f"  Batch size: {params['batch_size']}")
                    print(f"  KV Cache type: {params['cache_type']}")
                    print(f"  Flash Attention: {'Yes' if params['use_flash_attn'] else 'No'}")
                    print(f"  Lock in RAM: {'Yes' if params['use_mlock'] else 'No'}")
                    print(f"  Sampling parameters:")
                    print(f"    Temperature: {params['temp']}")
                    print(f"    Top P: {params['top_p']}")
                    print(f"    Top K: {params['top_k']}")
                    print(f"    Min P: {params['min_p']}")
                    print(f"    Presence Penalty: {params['presence_penalty']}")
                    print(f"    Repeat Penalty: {params['repeat_penalty']}")
                    print()

                    # Prompt for context length
                    ctx_input = input(
                        f"Enter context length (default: {params['n_ctx']}): "
                    ).strip()
                    if not ctx_input:
                        n_ctx = params["n_ctx"]
                    else:
                        try:
                            n_ctx = int(ctx_input)
                        except ValueError:
                            print(colorize("Invalid number, using current value", Colors.YELLOW))
                            n_ctx = params["n_ctx"]
                    params["n_ctx"] = n_ctx

                    # Prompt for GPU layers
                    gpu_layers_input = input(
                        f"Enter GPU layers (default: {params['n_gpu_layers']}, 999=max): "
                    ).strip()
                    if not gpu_layers_input:
                        n_gpu_layers = params["n_gpu_layers"]
                    else:
                        try:
                            n_gpu_layers = int(gpu_layers_input)
                        except ValueError:
                            print(colorize("Invalid number, using current value", Colors.YELLOW))
                            n_gpu_layers = params["n_gpu_layers"]
                    params["n_gpu_layers"] = n_gpu_layers

                    # Prompt for threads
                    threads_input = input(
                        f"Enter thread count (default: {params['threads']}): "
                    ).strip()
                    if not threads_input:
                        threads = params["threads"]
                    else:
                        try:
                            threads = int(threads_input)
                        except ValueError:
                            print(colorize("Invalid number, using current value", Colors.YELLOW))
                            threads = params["threads"]
                    params["threads"] = threads

                    # Prompt for batch size
                    batch_size_input = input(
                        f"Enter batch size (default: {params['batch_size']}): "
                    ).strip()
                    if not batch_size_input:
                        batch_size = params["batch_size"]
                    else:
                        try:
                            batch_size = int(batch_size_input)
                        except ValueError:
                            print(colorize("Invalid number, using current value", Colors.YELLOW))
                            batch_size = params["batch_size"]
                    params["batch_size"] = batch_size

                    # Prompt for KV cache type
                    cache_type_input = input(
                        f"Enter KV cache type (f32/f16/bf16/q8_0/q4_0/q4_1/iq4_nl/q5_0/q5_1, default: {params['cache_type']}): "
                    ).strip()
                    if not cache_type_input:
                        cache_type = params["cache_type"]
                    else:
                        allowed_cache_types = [
                            "f32",
                            "f16",
                            "bf16",
                            "q8_0",
                            "q4_0",
                            "q4_1",
                            "iq4_nl",
                            "q5_0",
                            "q5_1",
                        ]
                        if cache_type_input in allowed_cache_types:
                            cache_type = cache_type_input
                        else:
                            print(colorize(f"Invalid value '{cache_type_input}', using current", Colors.YELLOW))
                            cache_type = params["cache_type"]
                    params["cache_type"] = cache_type

                    # Prompt for Flash attention
                    flash_attn_input = (
                        input(f"Use Flash Attention? ({'y' if params['use_flash_attn'] else 'N'}/n): ").strip().lower()
                    )
                    use_flash_attn = params["use_flash_attn"] if not flash_attn_input else (flash_attn_input == "y")
                    params["use_flash_attn"] = use_flash_attn

                    # Prompt for Mlock
                    mlock_input = input(f"Lock model in RAM? ({'y' if params['use_mlock'] else 'N'}/n): ").strip().lower()
                    use_mlock = params["use_mlock"] if not mlock_input else (mlock_input == "y")
                    params["use_mlock"] = use_mlock

                    # Prompt for sampling parameters
                    print(f"\n{colorize('Sampling Parameters:', Colors.YELLOW)}")
                    
                    temp_input = input(f"Temperature (default: {params['temp']}): ").strip()
                    if temp_input:
                        try:
                            params["temp"] = float(temp_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))
                    
                    top_p_input = input(f"Top P (default: {params['top_p']}): ").strip()
                    if top_p_input:
                        try:
                            params["top_p"] = float(top_p_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))
                    
                    top_k_input = input(f"Top K (default: {params['top_k']}): ").strip()
                    if top_k_input:
                        try:
                            params["top_k"] = int(top_k_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))
                    
                    min_p_input = input(f"Min P (default: {params['min_p']}): ").strip()
                    if min_p_input:
                        try:
                            params["min_p"] = float(min_p_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))
                    
                    presence_penalty_input = input(f"Presence Penalty (default: {params['presence_penalty']}): ").strip()
                    if presence_penalty_input:
                        try:
                            params["presence_penalty"] = float(presence_penalty_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))
                    
                    repeat_penalty_input = input(f"Repeat Penalty (default: {params['repeat_penalty']}): ").strip()
                    if repeat_penalty_input:
                        try:
                            params["repeat_penalty"] = float(repeat_penalty_input)
                        except ValueError:
                            print(colorize("Invalid number, keeping current value", Colors.YELLOW))

                    self.save_config()
                    print(f"\n{colorize('Selected:', Colors.GREEN)} {selected['name']}")
                    return selected
            except ValueError:
                pass
            print(colorize("Please enter a valid choice.", Colors.YELLOW))

        return None

    def configure_api_key(self) -> None:
        """Configure API key interactively."""
        current = self.config["api_key"]
        print(f"\n{colorize('Enter API key (leave empty to clear):', Colors.YELLOW)}")
        print(f"  Current: {current[:4] + '...' if current else '(none)'}")
        new_key = input("  New key: ").strip()
        self.config["api_key"] = new_key
        self.save_config()
        print(f"API key {'set' if new_key else 'cleared'}.")

    def configure_address(self) -> None:
        """Configure server address interactively."""
        current = self.config["address"]
        print(f"\n{colorize('Enter server address (default: {}):'.format(DEFAULT_ADDRESS), Colors.YELLOW)}")
        print(f"  Current: {current}")
        new_addr = input("  New address: ").strip()
        if not new_addr:
            return
        self.config["address"] = new_addr
        # Extract port from address if present
        try:
            import re
            match = re.search(r":([0-9]{1,5})$", new_addr)
            if match:
                self.config["port"] = int(match.group(1))
        except (ValueError, AttributeError):
            pass
        self.save_config()
        print(f"Address set to: {new_addr}")

    def start_server(self, model_path: Optional[str] = None) -> None:
        """Start llama-server with given configuration."""
        if not self.llama_server_path:
            print("\n" + colorize("Error: llama-server binary not found.", Colors.RED), file=sys.stderr)
            sys.exit(1)

        # Determine model path
        model = model_path or self.config.get("last_model")
        if not model:
            print("\n" + colorize("No model selected. Please choose a model first.", Colors.YELLOW))
            return

        if not os.path.exists(model):
            print(f"\n{colorize('Error: Model file not found:', Colors.RED)} {model}", file=sys.stderr)
            sys.exit(1)

        # Get per-model parameters or use defaults
        if model not in self.config["model_params"]:
            self.config["model_params"][model] = self.get_default_model_params()
        params = self.config["model_params"][model]
        
        # Merge with defaults to add any missing keys (for old configs)
        defaults = self.get_default_model_params()
        for key, value in defaults.items():
            if key not in params:
                params[key] = value

        # Build command line arguments
        cmd = [
            self.llama_server_path,
            "-m",
            model,
            "--ctx-size",
            str(params["n_ctx"]),
            "--host",
            "0.0.0.0",
            "--port",
            str(self.config["port"]),
            "-ngl",
            str(params["n_gpu_layers"]),
            "-t",
            str(params["threads"]),
            "--batch-size",
            str(params["batch_size"]),
            "--cache-type-k",
            params["cache_type"],
            "--cache-type-v",
            params["cache_type"],
            # Sampling parameters
            "--temp",
            str(params["temp"]),
            "--top-p",
            str(params["top_p"]),
            "--top-k",
            str(params["top_k"]),
            "--min-p",
            str(params["min_p"]),
            "--presence-penalty",
            str(params["presence_penalty"]),
            "--repeat-penalty",
            str(params["repeat_penalty"]),
        ]

        if self.config.get("api_key"):
            cmd.extend(["--api-key", self.config["api_key"]])
        if params["use_flash_attn"]:
            cmd.append("--flash-attn")
            cmd.append("on")
        if params["use_mlock"]:
            cmd.append("--mlock")

        # Create display version of command (mask API key)
        display_cmd = cmd.copy()
        api_key_idx = None
        for i, arg in enumerate(cmd):
            if arg == "--api-key":
                api_key_idx = i + 1
                break
        if api_key_idx:
            display_cmd[api_key_idx] = "***"

        # Set environment variables for KV cache type
        env = os.environ.copy()
        env["LLAMA_ARG_CACHE_TYPE_K"] = params["cache_type"]
        env["LLAMA_ARG_CACHE_TYPE_V"] = params["cache_type"]

        cmd_str = " ".join(display_cmd)

        print("\n" + colorize("=" * 60, Colors.BLUE))
        print(colorize("  Starting llama-server...", Colors.GREEN + Colors.BOLD))
        print(colorize("=" * 60, Colors.BLUE))
        print(colorize("  Model:", Colors.CYAN), os.path.basename(model))
        print(colorize("  Address:", Colors.CYAN), self.config["address"])
        if self.config.get("api_key"):
            print(colorize("  API Key:", Colors.CYAN), "*** (configured)")
        print(colorize("  Parameters:", Colors.YELLOW))
        print(f"    Context length: {params['n_ctx']}")
        print(f"    GPU layers: {params['n_gpu_layers']} (999=max)")
        print(f"    Threads: {params['threads']}")
        print(f"    Batch size: {params['batch_size']}")
        print(f"    KV Cache type: {params['cache_type']}")
        print(f"    Flash Attention: {'Yes' if params['use_flash_attn'] else 'No'}")
        print(f"    Lock in RAM: {'Yes' if params['use_mlock'] else 'No'}")
        print(colorize("    Sampling Parameters:", Colors.YELLOW))
        print(f"      Temperature: {params['temp']}")
        print(f"      Top P: {params['top_p']}")
        print(f"      Top K: {params['top_k']}")
        print(f"      Min P: {params['min_p']}")
        print(f"      Presence Penalty: {params['presence_penalty']}")
        print(f"      Repeat Penalty: {params['repeat_penalty']}")
        print()
        print(colorize("  COMMAND:", Colors.MAGENTA + Colors.BOLD))
        print(f"    {cmd_str}")
        print()
        print(colorize("  Press Ctrl+C to stop", Colors.RED))
        print()

        # Log command to file
        log_file = Path.home() / ".llama-launcher.log"
        with open(log_file, "a") as f:
            f.write(f"{datetime.datetime.now().isoformat()} | {cmd_str}\n")

        try:
            subprocess.run(cmd, env=env)
        except KeyboardInterrupt:
            print("\n" + colorize("Server stopped.", Colors.YELLOW))

    def run(self) -> None:
        """Main event loop."""
        while True:
            self.display_header()
            choice = input("Enter choice: ").strip()

            if choice == "1":
                model_path = self.config.get("last_model")
                if model_path and os.path.exists(model_path):
                    self.start_server(model_path)
                else:
                    print("\n" + colorize("No last model configured or file missing.", Colors.YELLOW))
            elif choice == "2":
                model = self.choose_model()
                if model:
                    self.start_server(model["path"])
            elif choice == "3":
                self.configure_api_key()
            elif choice == "4":
                self.configure_address()
            elif choice == "5":
                print(colorize("Goodbye!", Colors.GREEN))
                break
            else:
                print("\n" + colorize("Invalid choice. Try again.", Colors.RED))


if __name__ == "__main__":
    # Parse command-line arguments for sampling parameters
    parser = argparse.ArgumentParser(
        description="llama.cpp Launcher - Interactive CLI for llama-server"
    )
    parser.add_argument("--temp", type=float, default=0.7,
                        help="Temperature (default: 0.7)")
    parser.add_argument("--top-p", type=float, default=0.8,
                        help="Top P nucleus sampling (default: 0.8)")
    parser.add_argument("--top-k", type=int, default=20,
                        help="Top K sampling (default: 20)")
    parser.add_argument("--min-p", type=float, default=0.00,
                        help="Min P sampling (default: 0.00)")
    parser.add_argument("--presence-penalty", type=float, default=1.5,
                        help="Presence penalty (default: 1.5)")
    parser.add_argument("--repeat-penalty", type=float, default=1.0,
                        help="Repeat penalty (default: 1.0)")
    
    args = parser.parse_args()
    
    # Pass CLI sampling parameters to launcher
    cli_params = {
        "temp": args.temp,
        "top_p": args.top_p,
        "top_k": args.top_k,
        "min_p": args.min_p,
        "presence_penalty": args.presence_penalty,
        "repeat_penalty": args.repeat_penalty,
    }
    
    launcher = Launcher(cli_sampling_params=cli_params)
    launcher.run()
