# cleanup_lab2.ps1 - ELEC 475 Lab 2: tidy the folder before the GitHub repo is made
#
# HOW TO USE (from the Lab2 folder, after copying in the latest git_setup.ps1,
# make_submission.ps1, github_repo.txt and this file):
#     Unblock-File .\cleanup_lab2.ps1
#     .\cleanup_lab2.ps1
#
# It first prints what it will do and waits for you to type YES.
# Nothing is permanently deleted except Python's __pycache__ folders (Python rebuilds
# them automatically). Everything else is MOVED into _archive\, keeping its folder
# path, so you can look through it and delete _archive\ yourself when you're happy.
# _archive\ is listed in .gitignore, so it never goes to GitHub.
#
# It never touches .venv\ or data\.

param([switch]$Yes)
$ErrorActionPreference = "Stop"

if (-not (Test-Path "train.py")) {
  Write-Host "Run this from the Lab2 folder (the one with train.py)." -ForegroundColor Red
  exit 1
}

$dirs = @(".", "checkpoints", "configs", "logs", "models", "plots", "utils")

# ---------------------------------------------------------------------------
# 1. Files to move into _archive\
# ---------------------------------------------------------------------------
$toArchive = @()
# OneNote clutter in every project folder (not .venv or data)
foreach ($d in $dirs) {
  if (Test-Path -LiteralPath $d) {
    $toArchive += Get-ChildItem -LiteralPath $d -File -Filter "*.onetoc2" | ForEach-Object {
      if ($d -eq ".") { $_.Name } else { "$d\$($_.Name)" }
    }
  }
}
$toArchive += @(
  "invalid_logs",                     # Tiny ImageNet runs on the old (training-set) validation split
  "logs\compare_models.FAILED.log",   # crash before the profiler device fix; compare_models.log is the good run
  "logs\summary.txt",                 # run-script summaries; every number is in the individual logs
  "logs\summary_extra.txt",
  "logs\summary_cifar.txt",
  "checkpoints\lenet.pth",            # early in-lab run; lenet_baseline.pth is the one used
  "file_list.txt"
)
$toArchive = @($toArchive | Where-Object { Test-Path -LiteralPath $_ })

# ---------------------------------------------------------------------------
# 2. Folders to delete (rebuilt automatically by Python)
# ---------------------------------------------------------------------------
$toDelete = @()
foreach ($d in $dirs) {
  $p = Join-Path $d "__pycache__"
  if (Test-Path -LiteralPath $p) { $toDelete += $p }
}

# ---------------------------------------------------------------------------
# 3. One-line fix: run_all.ps1 passed a --device flag compare_models.py does not have
# ---------------------------------------------------------------------------
$fixRunAll = $false
if ((Test-Path "run_all.ps1") -and (Select-String -Path "run_all.ps1" -SimpleMatch -Pattern "--dataset cifar10 --device cuda" -Quiet)) {
  $fixRunAll = $true
}

# ---------------------------------------------------------------------------
# Show the plan
# ---------------------------------------------------------------------------
Write-Host "`nWill MOVE into _archive\ :" -ForegroundColor Cyan
if ($toArchive.Count) { $toArchive | ForEach-Object { Write-Host "   $_" } } else { Write-Host "   (nothing)" }
Write-Host "`nWill DELETE (Python cache, rebuilt automatically):" -ForegroundColor Cyan
if ($toDelete.Count) { $toDelete | ForEach-Object { Write-Host "   $_" } } else { Write-Host "   (nothing)" }
Write-Host "`nWill EDIT:" -ForegroundColor Cyan
if ($fixRunAll) { Write-Host '   run_all.ps1: compare_models args "--dataset cifar10 --device cuda" -> "--dataset cifar10"' }
else { Write-Host "   (nothing)" }

if (-not $Yes) {
  $answer = Read-Host "`nType YES to go ahead"
  if ($answer -cne "YES") { Write-Host "Nothing changed." -ForegroundColor Yellow; exit 0 }
}

# ---------------------------------------------------------------------------
# Do it
# ---------------------------------------------------------------------------
foreach ($rel in $toArchive) {
  $dest = Join-Path "_archive" $rel
  $destDir = Split-Path $dest -Parent
  if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
  if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
  Move-Item -LiteralPath $rel -Destination $dest
}
foreach ($p in $toDelete) { Remove-Item -LiteralPath $p -Recurse -Force }
if ($fixRunAll) {
  $path = (Resolve-Path "run_all.ps1").Path
  $text = [IO.File]::ReadAllText($path)
  $text = $text.Replace("--dataset cifar10 --device cuda", "--dataset cifar10")
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}
Write-Host "`nDone." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Up-to-date checks (read only)
# ---------------------------------------------------------------------------
Write-Host "`nChecking that every file is the latest version:" -ForegroundColor Cyan
$problems = 0
function Check([string]$label, [bool]$ok, [string]$fix) {
  if ($ok) { Write-Host "   OK       $label" -ForegroundColor Green }
  else { Write-Host "   PROBLEM  $label  -> $fix" -ForegroundColor Red; $script:problems++ }
}
function Has([string]$file, [string]$text) {
  (Test-Path -LiteralPath $file) -and (Select-String -LiteralPath $file -SimpleMatch -Pattern $text -Quiet)
}

Check "git_setup.ps1 present (latest)"      (Has "git_setup.ps1" "_archive/")          "copy in the latest git_setup.ps1"
Check "make_submission.ps1 present"         (Test-Path "make_submission.ps1")           "copy in make_submission.ps1"
Check "github_repo.txt present"             (Test-Path "github_repo.txt")               "copy in github_repo.txt (add the URL after pushing)"
Check "commands.txt is the latest"          (Has "commands.txt" "run_cifar_logs.ps1")  "copy in the latest commands.txt"
Check "plot_ablation_summary.py uses course function" (Has "plot_ablation_summary.py" "from utils.visualization import plot_ablation_summary") "copy in the latest plot_ablation_summary.py"
Check "run_all.ps1 compare_models args"     (-not (Has "run_all.ps1" "--device cuda"))  "re-run this script"
Check "models\lenet.py implemented"         (Has "models\lenet.py" "nn.Tanh")           "check models\lenet.py"
Check "models\lenet_modern.py implemented"  (Has "models\lenet_modern.py" "nn.ReLU")    "check models\lenet_modern.py"
Check "models\alexnet.py implemented"       (Has "models\alexnet.py" "def late_norm")   "copy in the final alexnet.py"
Check "utils\transforms.py augmentation"    (Has "utils\transforms.py" "RandomCrop(target_size, padding=4") "check utils\transforms.py"
Check "utils\dataset.py Tiny ImageNet val fix" (Has "utils\dataset.py" "class TinyImageNetVal") "copy in the fixed dataset.py"
Check "utils\profiler.py device fix"        (Has "utils\profiler.py" "model = model.to(device)") "re-add the one-line fix"

$need = @("checkpoints\lenet_baseline.pth", "checkpoints\lenet_modern.pth", "checkpoints\alexnet_bn.pth",
          "plots\loss_lenet.png", "plots\loss_lenet_modern.png", "plots\loss_alexnet_bn.png", "plots\ablation_summary.png")
foreach ($f in $need) { Check "$f" (Test-Path $f) "missing - needed for the submission zip" }

if ($problems -eq 0) { Write-Host "`nAll checks passed. Next: .\git_setup.ps1" -ForegroundColor Green }
else { Write-Host "`n$problems problem(s) above - fix them, then run .\git_setup.ps1" -ForegroundColor Yellow }
