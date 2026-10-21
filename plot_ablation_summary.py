"""
ELEC 475 Lab 2 - build plots/ablation_summary.png with the course's own plotting code.

utils/visualization.py provides plot_ablation_summary(), but the module has no
__main__ block (so `python -m utils.visualization --plot-ablation` does nothing) and
train.py does not save per-epoch history. This script reads the per-epoch tables that
train.py prints (captured in logs/*.log) and passes them, unchanged, to
utils.visualization.plot_ablation_summary(). No course file is modified.

Usage (from the Lab 2 root, after run_cifar_logs.ps1 has produced the logs):
    python plot_ablation_summary.py
"""
import os
import re
import sys

from utils.visualization import plot_ablation_summary

# (label shown in the legend, log file written by run_cifar_logs.ps1 / run_all.ps1)
# All CIFAR-10, seed 42.
RUNS = [
    ("1. Base LeNet-5 (5 ep)",          "logs/lenet_cifar.log"),
    ("2. Modernized LeNet (5 ep)",      "logs/lenet_modern_cifar.log"),
    ("3. AlexNet, no norm (10 ep)",     "logs/alexnet_none_cifar.log"),
    ("4. AlexNet + LRN (10 ep)",        "logs/alexnet_lrn_cifar.log"),
    ("5. AlexNet + BN (15 ep, no aug)", "logs/alexnet_no_aug_cifar.log"),
    ("6. AlexNet + BN + Aug (15 ep)",   "logs/alexnet_with_aug_cifar.log"),
    ("7. Zoo AlexNet (10 ep)",          "logs/zoo_alexnet_cifar.log"),
]

# One epoch row of train.py's table:
# Epoch | Train Loss | Train Acc (%) | Val Loss | Val Acc (%) | Val F1 (%) | Time (s) | Throughput
ROW = re.compile(
    r"^\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)\s*\|"
)


def read_log(path):
    """Return the log text. PowerShell 5.1's Tee-Object writes UTF-16; Python output may be UTF-8."""
    with open(path, "rb") as f:
        raw = f.read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff") or raw[1:2] == b"\x00":
        return raw.decode("utf-16")
    return raw.decode("utf-8-sig", errors="replace")


def parse_epochs(path):
    """Parse the epoch table that follows the 'Train Loss' header line."""
    hist = {"epochs": [], "train_losses": [], "train_accs": [],
            "val_losses": [], "val_accs": [], "val_f1s": []}
    in_table = False
    for line in read_log(path).splitlines():
        if "Train Loss" in line and "Val Acc" in line:
            in_table = True
            continue
        if not in_table:
            continue
        m = ROW.match(line)
        if m:
            ep, tl, ta, vl, va, vf = m.groups()
            hist["epochs"].append(int(ep))
            hist["train_losses"].append(float(tl))
            hist["train_accs"].append(float(ta))
            hist["val_losses"].append(float(vl))
            hist["val_accs"].append(float(va))
            hist["val_f1s"].append(float(vf))
    return hist


def main():
    missing = [p for _, p in RUNS if not os.path.exists(p)]
    if missing:
        print("Missing log files:")
        for p in missing:
            print("   ", p)
        print("Run .\\run_cifar_logs.ps1 first (it re-runs the CIFAR-10 seed-42 jobs with logging).")
        sys.exit(1)

    results = {}
    print(f"{'Model':<34} {'Epochs':>6} {'Best val acc':>13} {'Final val acc':>14}")
    print("-" * 70)
    for label, path in RUNS:
        hist = parse_epochs(path)
        if not hist["val_accs"]:
            print(f"No epoch rows found in {path} - is the run complete?")
            sys.exit(1)
        results[label] = hist
        print(f"{label:<34} {len(hist['val_accs']):>6} {max(hist['val_accs']):>12.2f}% "
              f"{hist['val_accs'][-1]:>13.2f}%")
    print()

    os.makedirs("plots", exist_ok=True)
    plot_ablation_summary(results, save_path="plots/ablation_summary.png")


if __name__ == "__main__":
    main()
