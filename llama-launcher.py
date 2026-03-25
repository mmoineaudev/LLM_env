#!/usr/bin/env python3
"""
llama.cpp Launcher - Interactive CLI for llama-server
A simple launcher to manage GGUF models and start llama-server with configuration.
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any

# Configuration file location
CONFIG_FILE = Path.home() / ".llama-launcher-config.json"

# Default server address (note: llama-server defaults to port 8080)
DEFAULT_ADDRESS = "http://localhost:8080"

class Launcher:
    def __init__(self):
        self.config = self.load_config()
        # Prompt for llama.cpp installation if not set
        self.llama_cpp_dir = self.config.get("llama_cpp_dir")
        if not self.llama_cpp_dir:
            print("Enter path to llama.cpp installation (e.g., ~/llama.cpp):")
            self.llama_cpp_dir = input("> ").strip()
            if not self.llama_cpp_dir:
                self.llama_cpp_dir = str(Path.home() / "llama.cpp")
            self.config["llama_cpp_dir"] = self.llama_cpp_dir
            self.save_config()
        self.llama_server_path = self.find_llama_server()
        self.gguf_files = self.scan_gguf_files()

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file or create default."""
        if CONFIG_FILE.exists():
            try:
                with open(CONFIG_FILE, 'r') as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        # Default configuration
        return {
            "last_model": None,
            "api_key": "",
            "address": DEFAULT_ADDRESS,
            "port": 8080,
            "n_ctx": 75000,
            "n_gpu_layers": 20,
            "threads": 10,
            "batch_size": 524,
            "use_flash_attn": False,
            "use_mlock": False
        }

    def save_config(self) -> None:
        """Save current configuration to file."""
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=2)

    def find_llama_server(self) -> Optional[str]:
        """Find llama-server binary in common locations."""
        base = self.llama_cpp_dir
        candidates = [
            Path(base) / "build" / "bin" / "llama-server",
            Path(base) / "build" / "bin" "llama-server",
            Path("/usr/local/bin/llama-server"),
            Path("/usr/bin/llama-server")
        ]
        for path in candidates:
            p = path.expanduser()
            if p.exists() and os.access(p, os.X_OK):
                return str(p)
        # Check current directory
        cwd_path = Path.cwd() / "build" / "bin" / "llama-server"
        if cwd_path.exists() and os.access(cwd_path, os.X_OK):
            return str(cwd_path)
        return None

    def scan_gguf_files(self) -> List[Dict[str, Any]]:
        """Scan for GGUF model files in common locations."""
        gguf_paths = [
            Path.home() / ".lmstudio" / "models",
            Path("~/models").expanduser(),
            Path("~/Downloads"),
            Path("./models")
        ]
        models = []
        for base_path in gguf_paths:
            expanded = base_path.expanduser()
            if not expanded.exists():
                continue
            try:
                for file in expanded.rglob("*.gguf"):
                    size_mb = file.stat().st_size / (1024 * 1024)
                    models.append({
                        "path": str(file),
                        "name": file.name,
                        "size_mb": round(size_mb, 2)
                    })
            except PermissionError:
                pass
        return sorted(models, key=lambda x: -x["size_mb"])

    def display_header(self) -> None:
        """Display the launcher header with help text."""
        print("\n" + "=" * 60)
        print("  llama.cpp Launcher")
        print("=" * 60)
        print()
        print("  This is an interactive CLI launcher for llama-server.")
        print()
        print("  OPTIONS:")
        print("  1. Load last used model and start server")
        print("     - Starts llama-server with the previously selected model")
        print()
        print("  2. Choose a model then launch it")
        print("     - Browse available GGUF files and select one to run")
        print()
        print("  3. Configure API key")
        print("     - Set or clear the authentication key for llama-server")
        print()
        print("  4. Configure address (default: http://localhost:8080)")
        print("     - Change server host and port settings")
        print()
        print("  5. Exit")
        print()
        print("  6. Exit (force) - closes the script")
        print()

    def choose_model(self) -> Optional[Dict[str, Any]]:
        """Interactive model selection with file listing."""
        if not self.gguf_files:
            print("\nNo GGUF files found in common locations.")
            return None

        print("\nAvailable models:")
        for i, model in enumerate(self.gguf_files, 1):
            marker = " (last used)" if self.config["last_model"] == model["path"] else ""
            # Show full path if filename long, else just filename
            base = os.path.basename(model["path"])
            path_display = base if len(base) < 40 else model["path"]
            print(f"  {i}. {path_display} ({model['size_mb']:.1f} MB){marker}")
        print()

        while True:
            choice = input("Enter model number (or 'q' to quit): ").strip()
            if choice.lower() == 'q':
                return None
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(self.gguf_files):
                    selected = self.gguf_files[idx]
                    self.config["last_model"] = selected["path"]
                    self.save_config()
                    print(f"\nSelected: {selected['name']}")
                    # Prompt for n_ctx with default of 75000
                    ctx_input = input("Enter context length (default: 75000): ").strip()
                    if not ctx_input:
                        n_ctx = 75000
                    else:
                        try:
                            n_ctx = int(ctx_input)
                        except ValueError:
                            print("Invalid number, using default 75000")
                            n_ctx = 75000
                    self.config["n_ctx"] = n_ctx
                    self.save_config()
                    # Prompt for additional params with defaults
                    gpu_layers_input = input("Enter GPU layers (default: 20): ").strip()
                    if not gpu_layers_input:
                        n_gpu_layers = 20
                    else:
                        try:
                            n_gpu_layers = int(gpu_layers_input)
                        except ValueError:
                            print("Invalid number, using default 20")
                            n_gpu_layers = 20
                    threads_input = input("Enter thread count (default: 10): ").strip()
                    if not threads_input:
                        threads = 10
                    else:
                        try:
                            threads = int(threads_input)
                        except ValueError:
                            print("Invalid number, using default 10")
                            threads = 10
                    batch_size_input = input("Enter batch size (default: 524): ").strip()
                    if not batch_size_input:
                        batch_size = 524
                    else:
                        try:
                            batch_size = int(batch_size_input)
                        except ValueError:
                            print("Invalid number, using default 524")
                            batch_size = 524
                    # Flash attention prompt (yes/no)
                    flash_attn_input = input("Use Flash Attention? (y/N): ").strip().lower()
                    use_flash_attn = flash_attn_input == 'y'
                    # Mlock prompt (yes/no)
                    mlock_input = input("Lock model in RAM? (y/N): ").strip().lower()
                    use_mlock = mlock_input == 'y'
                    self.config["n_gpu_layers"] = n_gpu_layers
                    self.config["threads"] = threads
                    self.config["batch_size"] = batch_size
                    self.config["use_flash_attn"] = use_flash_attn
                    self.config["use_mlock"] = use_mlock
                    self.save_config()
                    return selected
                else:
                    print("Invalid model number.")
            except ValueError:
                pass
            print("Please enter a valid choice.")

    def configure_api_key(self) -> None:
        """Configure API key interactively."""
        current = self.config["api_key"]
        print("\nEnter API key (leave empty to clear):")
        print(f"  Current: {current[:4] + '...' if current else '(none)'}")
        new_key = input("  New key: ").strip()
        self.config["api_key"] = new_key
        self.save_config()
        print(f"API key {'set' if new_key else 'cleared'}.")

    def configure_address(self) -> None:
        """Configure server address interactively."""
        current = self.config["address"]
        print("\nEnter server address (default: {}):".format(DEFAULT_ADDRESS))
        print(f"  Current: {current}")
        new_addr = input("  New address: ").strip()
        if not new_addr:
            return
        self.config["address"] = new_addr
        # Extract port from address if present
        try:
            import re
            match = re.search(r':([0-9]{1,5})$', new_addr)
            if match:
                self.config["port"] = int(match.group(1))
        except (ValueError, AttributeError):
            pass
        self.save_config()
        print(f"Address set to: {new_addr}")

    def start_server(self, model_path: Optional[str] = None) -> None:
        """Start llama-server with given configuration."""
        if not self.llama_server_path:
            print("\nError: llama-server binary not found.", file=sys.stderr)
            sys.exit(1)

        model = model_path or self.config.get("last_model")
        if not model:
            print("\nNo model selected. Please choose a model first.")
            return
        if not os.path.exists(model):
            print(f"\nError: Model file not found: {model}", file=sys.stderr)
            sys.exit(1)

        n_ctx = self.config.get("n_ctx", 75000)
        cmd = [
            self.llama_server_path,
            "-m", model,
            "--ctx-size", str(n_ctx),
            "--host", "0.0.0.0",
            "--port", str(self.config["port"])
        ]
        if self.config.get("api_key"):
            cmd.extend(["--api-key", self.config["api_key"]])

        full_cmd = cmd.copy()
        if self.config.get("api_key"):
            full_cmd.extend(["--api-key", "***"])

        print("\n" + "=" * 60)
        print("  Starting llama-server...")
        print("=" * 60)
        print("  Model:", os.path.basename(model))
        print("  Address:", self.config['address'])
        if self.config.get("api_key"):
            print("  API Key: *** (configured)")
        print()
        print("  COMMAND:")
        print("    " + " ".join(full_cmd))
        print()

        try:
            subprocess.run(cmd, env={**os.environ})
        except KeyboardInterrupt:
            print("\nServer stopped.")

    def run(self) -> None:
        """Main event loop."""
        while True:
            self.display_header()
            choice = input("Enter choice: ").strip()
            if choice == '1':
                model_path = self.config.get("last_model")
                if model_path and os.path.exists(model_path):
                    self.start_server(model_path)
                else:
                    print("\nNo last model configured or file missing.")
            elif choice == '2':
                model = self.choose_model()
                if model:
                    self.start_server(model["path"])
            elif choice == '3':
                self.configure_api_key()
            elif choice == '4':
                self.configure_address()
            elif choice == '5':
                print("Goodbye!")
                break
            elif choice == '6':
                print("Exiting.")
                break
            else:
                print("\nInvalid choice. Try again.")

if __name__ == "__main__":
    launcher = Launcher()
    launcher.run()