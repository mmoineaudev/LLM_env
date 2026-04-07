#!/usr/bin/env python3
"""
llama.cpp Benchmark - Automated parameter benchmarking for GGUF models
=======================================================================

This script benchmarks llama-bench with various parameter combinations to find
optimal settings for GPU layer offload, context size, threads, and batch size.

USAGE:
    Run this script directly. It will scan for GGUF files and run benchmarks
    in chains, saving results to an hourdated result.md file.

CONFIGURATION:
    Settings can be customized by modifying the PARAMETER_RANGES dictionary.
"""

import json
import os
import re
import subprocess
import sys
import datetime
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

# Default llama-bench parameters
DEFAULT_BENCH_PARAMS = {
    "n_prompt": 512,      # Prompt tokens for benchmark
    "n_gen": 128,         # Generated tokens for benchmark
    "repetitions": 3,     # Number of repetitions per test
}

class BenchmarkRunner:
    def __init__(self):
        self.llama_bench_path = self.find_llama_bench()
        self.gguf_files = self.scan_gguf_files()
        self.results = []
        
    def find_llama_bench(self) -> Optional[str]:
        """Find llama-bench binary in common locations."""
        candidates = [
            Path("/home/neo/llama.cpp/build/bin/llama-bench"),
            Path("~/llama.cpp/build/bin/llama-bench").expanduser(),
            Path("~/Modèles/llama.cpp/build/bin/llama-bench").expanduser(),
            Path("./build/bin/llama-bench").expanduser(),
        ]
        
        for path in candidates:
            if path.exists() and os.access(path, os.X_OK):
                return str(path)
        
        # Check PATH
        result = subprocess.run(["which", "llama-bench"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        
        return None
    
    def scan_gguf_files(self) -> List[Dict[str, Any]]:
        """Scan for GGUF model files in common locations."""
        gguf_paths = [
            Path.home() / ".lmstudio/models",
            Path("~/Models").expanduser(),
            Path("~/Downloads"),
            Path("./Models"),
            Path("/home/neo/Models"),
        ]
        
        models = []
        seen_paths = set()  # Track unique paths to avoid duplicates
        
        for base_path in gguf_paths:
            expanded = base_path.expanduser()
            if not expanded.exists():
                continue
            try:
                for file in expanded.rglob("*.gguf"):
                    # Skip mmproj files (multimodal project files)
                    if "mmproj" in file.name.lower():
                        continue
                    
                    path_str = str(file.resolve())  # Use resolved path for deduplication
                    
                    # Skip if already seen (avoid duplicates from overlapping paths)
                    if path_str in seen_paths:
                        continue
                    seen_paths.add(path_str)
                    
                    size_mb = file.stat().st_size / (1024 * 1024)
                    models.append({
                        "path": str(file),
                        "name": file.name,
                        "size_mb": round(size_mb, 2),
                    })
            except PermissionError:
                pass
        
        return sorted(models, key=lambda x: -x["size_mb"])
    
    def display_model_list(self) -> Optional[int]:
        """Display model list and get user selection."""
        if not self.gguf_files:
            print(colorize("\nNo GGUF files found in common locations.", Colors.RED))
            return None
        
        print(colorize(f"\nFound {len(self.gguf_files)} GGUF model(s)", Colors.GREEN))
        for i, model in enumerate(self.gguf_files, 1):
            path_display = os.path.basename(model["path"]) if len(os.path.basename(model["path"])) < 50 else model["path"]
            print(f"  {i}. {colorize(path_display, Colors.CYAN)} ({model['size_mb']:.1f} MB)")
        
        while True:
            choice = input(colorize("\nEnter model number to benchmark (or 'q' to quit): ", Colors.YELLOW)).strip()
            if choice.lower() == 'q':
                return None
            try:
                idx = int(choice) - 1
                if 0 <= idx < len(self.gguf_files):
                    return idx
                print(colorize(f"Please enter a number between 1 and {len(self.gguf_files)}", Colors.YELLOW))
            except ValueError:
                print(colorize("Invalid input. Please enter a number.", Colors.YELLOW))
    
    def display_param_selection_menu(self) -> Dict[str, List[Any]]:
        """Display parameter selection menu and get user choices."""
        # Default ranges
        default_ranges = {
            "n_gpu_layers": [10, 20, 30, 40, 50, 60, 70, 80, 90, 99],
            "threads": [4, 8, 16, 22, 32],
            "batch_size": [512, 1024, 2048],
            "n_ctx": [4096, 8192, 16384, 32768, 65536, 128000],
        }
        
        print(colorize("\n" + "=" * 60, Colors.BLUE))
        print(colorize("  PARAMETER SELECTION", Colors.GREEN + Colors.BOLD))
        print(colorize("=" * 60, Colors.BLUE))
        print()
        print(colorize("Select which parameters to benchmark (vary):", Colors.YELLOW))
        print(colorize("Leave empty to keep constant (use default values)", Colors.WHITE))
        print()
        
        selections = {}
        
        # GPU Layers
        print(colorize("-" * 40, Colors.CYAN))
        print(f"{colorize('GPU Layers (-ngl):', Colors.BOLD)}")
        print(f"  Default: {default_ranges['n_gpu_layers']}")
        gpu_input = input("  Enter values separated by commas (or empty to skip): ").strip()
        if gpu_input:
            try:
                selections["n_gpu_layers"] = [int(x.strip()) for x in gpu_input.split(",")]
            except ValueError:
                print(colorize("  Invalid input, using default", Colors.YELLOW))
        
        # Threads
        print(colorize("-" * 40, Colors.CYAN))
        print(f"{colorize('Threads (-t):', Colors.BOLD)}")
        print(f"  Default: {default_ranges['threads']}")
        threads_input = input("  Enter values separated by commas (or empty to skip): ").strip()
        if threads_input:
            try:
                selections["threads"] = [int(x.strip()) for x in threads_input.split(",")]
            except ValueError:
                print(colorize("  Invalid input, using default", Colors.YELLOW))
        
        # Batch Size
        print(colorize("-" * 40, Colors.CYAN))
        print(f"{colorize('Batch Size (-b):', Colors.BOLD)}")
        print(f"  Default: {default_ranges['batch_size']}")
        batch_input = input("  Enter values separated by commas (or empty to skip): ").strip()
        if batch_input:
            try:
                selections["batch_size"] = [int(x.strip()) for x in batch_input.split(",")]
            except ValueError:
                print(colorize("  Invalid input, using default", Colors.YELLOW))
        
        # Context Size
        print(colorize("-" * 40, Colors.CYAN))
        print(f"{colorize('Context Size (-p):', Colors.BOLD)}")
        print(f"  Default: {default_ranges['n_ctx']}")
        ctx_input = input("  Enter values separated by commas (or empty to skip): ").strip()
        if ctx_input:
            try:
                selections["n_ctx"] = [int(x.strip()) for x in ctx_input.split(",")]
            except ValueError:
                print(colorize("  Invalid input, using default", Colors.YELLOW))
        
        # If no parameters selected, use all defaults
        if not selections:
            print(colorize("\nNo parameters selected. Using all defaults.", Colors.YELLOW))
            selections = {k: v for k, v in default_ranges.items()}
        
        return selections
    
    def run_benchmark(self, model_path: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Run llama-bench with given parameters and return results for each test row."""
        cmd = [self.llama_bench_path]
        
        # Add model path
        cmd.extend(["-m", model_path])
        
        # Add benchmark parameters
        cmd.extend(["-p", str(params.get("n_prompt", DEFAULT_BENCH_PARAMS["n_prompt"]))])
        cmd.extend(["-n", str(params.get("n_gen", DEFAULT_BENCH_PARAMS["n_gen"]))])
        cmd.extend(["-r", str(params.get("repetitions", DEFAULT_BENCH_PARAMS["repetitions"]))])
        
        # Add variable parameters
        if "n_gpu_layers" in params:
            cmd.extend(["-ngl", str(params["n_gpu_layers"])])
        if "threads" in params:
            cmd.extend(["-t", str(params["threads"])])
        if "batch_size" in params:
            cmd.extend(["-b", str(params["batch_size"])])
        
        # Note: n_ctx is handled via -p (prompt size) for benchmark purposes
        
        # Run the benchmark
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout per test
            )
            
            if result.returncode == 0:
                # Parse each test row from the output as a separate result
                return self.parse_benchmark_output(result.stdout, params.copy(), model_path)
            else:
                return [{
                    "success": False,
                    "error": result.stderr,
                    "params": params.copy(),
                    "model": {"path": model_path},
                }]
        except subprocess.TimeoutExpired:
            return [{
                "success": False,
                "error": "Timeout expired",
                "params": params.copy(),
                "model": {"path": model_path},
            }]
        except Exception as e:
            return [{
                "success": False,
                "error": str(e),
                "params": params.copy(),
                "model": {"path": model_path},
            }]
    
    def parse_benchmark_output(self, stdout_text: str, base_params: Dict[str, Any], model_path: str) -> List[Dict[str, Any]]:
        """Parse llama-bench markdown output and return a list of results (one per test row)."""
        results = []
        
        # Parse the markdown table from llama-bench output
        lines = stdout_text.strip().split('\n')
        in_table = False
        header_parts = None
        
        for line in lines:
            if '|' not in line:
                continue
            
            parts = [p.strip() for p in line.split('|')]
            
            # Check if this is a header row (contains column names)
            if any('model' in p.lower() or 'size' in p.lower() or 'params' in p.lower() for p in parts):
                in_table = True
                header_parts = parts
                continue
            
            # Check if this is a separator row (contains dashes)
            if in_table and all('-' in p or ':' in p or not p for p in parts):
                continue
            
            # This should be a data row
            if in_table and len(parts) >= 7:
                # Check if this looks like a data row (has numeric values)
                if any(re.match(r'^[\d.]+', p) for p in parts):
                    # Extract t/s value from the last column (may have ± error)
                    tps_value = "N/A"
                    time_ms = "N/A"
                    
                    # Look for columns with ± error pattern - these are t/s values
                    for part in parts:
                        if '±' in part:
                            tps_match = re.match(r'([\d.]+)', part)
                            if tps_match:
                                tps_value = tps_match.group(1)
                            break
                    
                    # If still no t/s, try last numeric column
                    if tps_value == "N/A":
                        numeric_parts = [p for p in parts if re.match(r'^[\d.]+', p)]
                        if numeric_parts:
                            tps_value = numeric_parts[-1]
                    
                    # Create a result entry for this test row
                    results.append({
                        "success": True,
                        "stdout": stdout_text,  # Keep full output for reference
                        "stderr": "",
                        "params": base_params.copy(),
                        "model": {"path": model_path},
                        "tps_value": tps_value,
                        "time_ms": time_ms,
                    })
        
        return results if results else [{
            "success": False,
            "error": "Could not parse benchmark output",
            "params": base_params.copy(),
            "model": {"path": model_path},
        }]
    
    def generate_test_combinations(self, selections: Dict[str, List[Any]]) -> List[Dict[str, Any]]:
        """Generate all combinations of selected parameters to test."""
        combinations = []
        
        # Get the parameter names that were selected
        param_names = list(selections.keys())
        
        if not param_names:
            return []
        
        # Generate cartesian product using recursion
        def generate_combinations(index: int, current: Dict[str, Any]):
            if index == len(param_names):
                combinations.append(current.copy())
                return
            
            param = param_names[index]
            for value in selections[param]:
                current[param] = value
                generate_combinations(index + 1, current)
        
        generate_combinations(0, {})
        return combinations
    
    def run_benchmarks_for_model(self, model: Dict[str, Any], selections: Dict[str, List[Any]]) -> List[Dict[str, Any]]:
        """Run all benchmarks for a single model."""
        model_path = model["path"]
        print(f"\n{colorize('=' * 60, Colors.BLUE)}")
        print(colorize(f"  Benchmarking: {model['name']}", Colors.GREEN + Colors.BOLD))
        print(colorize(f"  Path: {model_path}", Colors.CYAN))
        print(colorize(f"  Size: {model['size_mb']:.1f} MB", Colors.WHITE))
        print(colorize('=' * 60, Colors.BLUE))
        
        # Show selected parameters
        print(colorize("\n  Selected parameters to vary:", Colors.YELLOW))
        for param, values in selections.items():
            display_name = {
                "n_gpu_layers": "GPU Layers (-ngl)",
                "threads": "Threads (-t)",
                "batch_size": "Batch Size (-b)",
                "n_ctx": "Context Size (-p)"
            }.get(param, param)
            print(f"    {display_name}: {values}")
        
        combinations = self.generate_test_combinations(selections)
        model_results = []
        
        total_tests = len(combinations)
        step = 0  # Track actual benchmark steps
        
        for i, params in enumerate(combinations, 1):
            display_params = ", ".join([f"{k}={v}" for k, v in params.items()])
            print(f"\r{colorize(f'  Progress: {i}/{total_tests} ({i*100//total_tests}%)', Colors.YELLOW)} | {display_params}", end="", flush=True)
            
            # run_benchmark now returns a list of results (one per test row)
            batch_results = self.run_benchmark(model_path, params)
            for result in batch_results:
                result["model"] = model.copy()
                result["step"] = step  # Add step counter for tracking
                model_results.append(result)
                step += 1
            
            if batch_results and not batch_results[0]["success"]:
                print(f"\n{colorize(f'  ERROR: {batch_results[0].get("error", "Unknown error")}', Colors.RED)}")
        
        print()  # New line after progress
        return model_results
    
    def run_all_benchmarks(self, selections: Dict[str, List[Any]]) -> List[Dict[str, Any]]:
        """Run benchmarks for selected models."""
        all_results = []
        
        # Get selected model indices from user
        while True:
            print(colorize("\n" + "=" * 60, Colors.BLUE))
            print(colorize("  MODEL SELECTION", Colors.GREEN + Colors.BOLD))
            print(colorize("=" * 60, Colors.BLUE))
            
            if not self.gguf_files:
                print(colorize("\nNo GGUF files found in common locations.", Colors.RED))
                return []
            
            print(colorize(f"\nFound {len(self.gguf_files)} GGUF model(s)", Colors.GREEN))
            for i, model in enumerate(self.gguf_files, 1):
                path_display = os.path.basename(model["path"]) if len(os.path.basename(model["path"])) < 50 else model["path"]
                print(f"  {i}. {colorize(path_display, Colors.CYAN)} ({model['size_mb']:.1f} MB)")
            
            choice = input(colorize("\nEnter model number(s) to benchmark (comma-separated, or 'q' to quit): ", Colors.YELLOW)).strip()
            if choice.lower() == 'q':
                return []
            
            selected_indices = []
            try:
                for part in choice.split(","):
                    part = part.strip()
                    if '-' in part:
                        # Handle ranges like "1-3"
                        start, end = map(int, part.split("-"))
                        selected_indices.extend(range(start - 1, end))
                    else:
                        idx = int(part) - 1
                        selected_indices.append(idx)
                
                # Validate indices
                valid = all(0 <= idx < len(self.gguf_files) for idx in selected_indices)
                if not valid:
                    print(colorize(f"Please enter numbers between 1 and {len(self.gguf_files)}", Colors.YELLOW))
                    continue
                
                break
            except ValueError:
                print(colorize("Invalid input. Please enter numbers separated by commas.", Colors.YELLOW))
        
        # Run benchmarks for selected models
        for idx in selected_indices:
            model = self.gguf_files[idx]
            model_results = self.run_benchmarks_for_model(model, selections)
            all_results.extend(model_results)
        
        return all_results
    
    def format_results_markdown(self, results: List[Dict[str, Any]]) -> str:
        """Format benchmark results as markdown table."""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        output = []
        output.append(f"# llama.cpp Benchmark Results")
        output.append(f"\nGenerated: {timestamp}")
        output.append(f"\nTotal tests run: {len(results)}\n")
        
        # Group by model
        models_seen = set()
        for result in results:
            if result["model"]["name"] not in models_seen:
                models_seen.add(result["model"]["name"])
                output.append(f"## Model: {result['model']['name']}")
                output.append(f"**Path:** `{result['model']['path']}`")
                output.append(f"**Size:** {result['model']['size_mb']:.1f} MB\n")
                
                # Create table header
                output.append("| n_gpu_layers | threads | batch_size | n_ctx | status | time (ms) | t/s |")
                output.append("|-------------:|---------|-----------:|------:|--------|----------:|----:|")
                
                # Add results for this model
                for r in results:
                    if r["model"]["name"] == result["model"]["name"]:
                        status = colorize("✓", Colors.GREEN) if r["success"] else colorize("✗", Colors.RED)
                        
                        if r["success"]:
                            # Use pre-parsed values from parse_benchmark_output
                            tps_value = r.get("tps_value", "N/A")
                            time_ms = r.get("time_ms", "N/A")
                        else:
                            tps_value = "ERROR"
                            time_ms = "N/A"
                        
                        output.append(
                            f"| {r['params']['n_gpu_layers']} | {r['params']['threads']} | "
                            f"{r['params']['batch_size']} | {r['params']['n_ctx']} | {status} | {time_ms} | {tps_value} |"
                        )
                
                output.append("")
        
        return "\n".join(output)
    
    def save_results(self, results: List[Dict[str, Any]], format_type: str = "md") -> str:
        """Save results to an hourdated file."""
        timestamp = datetime.datetime.now()
        hour_key = timestamp.strftime("%Y-%m-%d_%H")
        
        if format_type == "md":
            content = self.format_results_markdown(results)
            filename = f"benchmark_results_{hour_key}.md"
        elif format_type == "json":
            # Convert results to JSON-serializable format
            json_results = []
            for r in results:
                json_result = {
                    "model_name": r["model"]["name"],
                    "model_path": r["model"]["path"],
                    "params": r["params"],
                    "success": r["success"],
                    "stdout": r.get("stdout", ""),
                    "stderr": r.get("error", ""),
                }
                # Add parsed values if available
                if "tps_value" in r:
                    json_result["tps_value"] = r["tps_value"]
                if "time_ms" in r:
                    json_result["time_ms"] = r["time_ms"]
                if "step" in r:
                    json_result["step"] = r["step"]
                json_results.append(json_result)
            content = json.dumps(json_results, indent=2)
            filename = f"benchmark_results_{hour_key}.json"
        else:
            raise ValueError(f"Unknown format type: {format_type}")
        
        # Save to output directory
        output_dir = Path.home() / "Documents" / "LLM_env" / "outputs"
        output_dir.mkdir(parents=True, exist_ok=True)
        
        filepath = output_dir / filename
        with open(filepath, "w") as f:
            f.write(content)
        
        return str(filepath)
    
    def display_summary(self, results: List[Dict[str, Any]]) -> None:
        """Display a summary of the benchmark results."""
        successful = [r for r in results if r["success"]]
        failed = [r for r in results if not r["success"]]
        
        print(colorize("\n" + "=" * 60, Colors.BLUE))
        print(colorize("  BENCHMARK SUMMARY", Colors.GREEN + Colors.BOLD))
        print(colorize("=" * 60, Colors.BLUE))
        print(f"\n{colorize('Total tests:', Colors.YELLOW)} {len(results)}")
        print(f"{colorize('Successful:', Colors.GREEN)} {len(successful)}")
        print(f"{colorize('Failed:', Colors.RED)} {len(failed)}")
        
        if successful:
            # Find best results by GPU layers
            print(colorize("\n  Best results by GPU layer count:", Colors.CYAN))
            
            best_by_ngl = {}
            for r in successful:
                ngl = r["params"]["n_gpu_layers"]
                if ngl not in best_by_ngl or r["params"]["threads"] > best_by_ngl[ngl]["params"]["threads"]:
                    best_by_ngl[ngl] = r
            
            for ngl in sorted(best_by_ngl.keys()):
                r = best_by_ngl[ngl]
                print(f"  {colorize(f'  ngl={ngl}:', Colors.WHITE)} threads={r['params']['threads']}, batch={r['params']['batch_size']}")
        
        print(colorize("\n" + "=" * 60, Colors.BLUE))


def main():
    """Main entry point."""
    print(colorize("=" * 60, Colors.BLUE))
    print(colorize("  llama.cpp Benchmark Runner", Colors.GREEN + Colors.BOLD))
    print(colorize("=" * 60, Colors.BLUE))
    
    runner = BenchmarkRunner()
    
    if not runner.llama_bench_path:
        print(colorize("\nError: llama-bench binary not found.", Colors.RED))
        print("Please ensure llama.cpp is built and llama-bench is accessible.")
        sys.exit(1)
    
    if not runner.gguf_files:
        print(colorize("\nNo GGUF files found. Please add models to one of these locations:", Colors.YELLOW))
        print("  - ~/.lmstudio/models")
        print("  - ~/Models")
        print("  - ~/Downloads")
        sys.exit(1)
    
    # Get parameter selections from user
    selections = runner.display_param_selection_menu()
    
    if not selections:
        print(colorize("\nNo parameters selected. Exiting.", Colors.YELLOW))
        sys.exit(0)
    
    # Run benchmarks
    results = runner.run_all_benchmarks(selections)
    
    if not results:
        print(colorize("\nNo benchmarks were run.", Colors.YELLOW))
        sys.exit(0)
    
    # Save results
    output_file = runner.save_results(results, format_type="md")
    print(colorize(f"\nResults saved to: {output_file}", Colors.GREEN))
    
    # Display summary
    runner.display_summary(results)


if __name__ == "__main__":
    main()
