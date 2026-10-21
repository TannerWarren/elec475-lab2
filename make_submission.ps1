# make_submission.ps1 - ELEC 475 Lab 2: build <student_number>.zip exactly as the post-lab manual (9.1) lists
#
# HOW TO USE (from the Lab2 folder, AFTER exporting ELEC475_Lab2_Report.pdf into it
# and putting your repository URL in github_repo.txt):
#     Unblock-File .\make_submission.ps1
#     .\make_submission.ps1 -StudentNumber 20212345
#   Pair submission:  .\make_submission.ps1 -StudentNumber 20212345 -PartnerNumber 20254321
#
# The zip contains a single <student_number>/ folder with the required files.
# All plots/*.png and logs/*.log are added as supporting evidence; data/, .venv/ and
# every checkpoint except the three required ones are left out.

param(
  [Parameter(Mandatory = $true)][string]$StudentNumber,
  [string]$PartnerNumber = ""
)
$ErrorActionPreference = "Stop"

$name = $StudentNumber
if ($PartnerNumber) { $name = "$($StudentNumber)_$($PartnerNumber)" }

$required = @(
  "models\__init__.py", "models\lenet.py", "models\lenet_modern.py", "models\alexnet.py", "models\zoo.py",
  "utils\__init__.py", "utils\dataset.py", "utils\eda.py", "utils\transforms.py", "utils\metrics.py",
  "utils\visualization.py", "utils\profiler.py", "utils\seed.py",
  "configs\config.py",
  "checkpoints\lenet_baseline.pth", "checkpoints\lenet_modern.pth", "checkpoints\alexnet_bn.pth",
  "plots\loss_lenet.png", "plots\loss_lenet_modern.png", "plots\loss_alexnet_bn.png", "plots\ablation_summary.png",
  "demo_transforms.py", "compare_models.py", "train.py", "evaluate.py",
  "github_repo.txt", "commands.txt", "ELEC475_Lab2_Report.pdf"
)
$optional = @("plot_ablation_summary.py", "requirements.txt", "README.md")

# ---- checks ----
$missing = @($required | Where-Object { -not (Test-Path $_) })
if ($missing.Count -gt 0) {
  Write-Host "Missing required files (nothing was zipped):" -ForegroundColor Red
  $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  exit 1
}
$repo = (Get-Content github_repo.txt -Raw)
if ($repo -notmatch 'https?://\S+') {
  Write-Host "github_repo.txt does not contain a URL yet. Add your repository link and run again." -ForegroundColor Red
  exit 1
}

# ---- stage ----
$stageRoot = "submission"
$stage = Join-Path $stageRoot $name
if (Test-Path $stageRoot) { Remove-Item -Recurse -Force $stageRoot }
New-Item -ItemType Directory -Path $stage | Out-Null

function Copy-Into([string]$rel) {
  $dest = Join-Path $stage $rel
  $dir = Split-Path $dest -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Copy-Item $rel $dest
}
foreach ($f in $required) { Copy-Into $f }
foreach ($f in $optional) { if (Test-Path $f) { Copy-Into $f } }
Get-ChildItem plots -Filter *.png | ForEach-Object { Copy-Into ("plots\" + $_.Name) }
if (Test-Path logs) {
  Get-ChildItem logs -File | Where-Object { $_.Name -match '\.(log|txt)$' -and $_.Name -notmatch '\.running\.log$' } |
    ForEach-Object { Copy-Into ("logs\" + $_.Name) }
}

# ---- zip ----
$zip = "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
# .NET ZipFile writes '/' path separators, so the zip also opens correctly on macOS/Linux
# (Windows PowerShell 5.1's Compress-Archive writes '\' separators).
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $stageRoot).Path, (Join-Path (Get-Location).Path $zip),
  [IO.Compression.CompressionLevel]::Optimal, $false)

$sizeMB = [math]::Round((Get-Item $zip).Length / 1MB, 1)
$count = (Get-ChildItem $stage -Recurse -File).Count
Write-Host "`nCreated $zip  ($count files, $sizeMB MB)" -ForegroundColor Green
Write-Host "Required files: all $($required.Count) present." -ForegroundColor Green
Write-Host "Not included (by design): data\, .venv\, extra checkpoints, OneNote files." -ForegroundColor DarkGray
Write-Host "Open $zip once to check it before uploading to OnQ." -ForegroundColor Cyan
