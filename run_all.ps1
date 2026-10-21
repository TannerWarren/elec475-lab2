# run_all.ps1 - ELEC 475 Lab 2 post-lab: remaining training runs + benchmarks
#
# HOW TO USE (from the Lab2 folder, with .venv active):
#     .\run_all.ps1
#
# - Each run's output is shown live AND written to logs\<name>.running.log as it goes.
# - When a run finishes successfully, that file is renamed to logs\<name>.log.
# - If a run crashes, its partial output is kept as logs\<name>.FAILED.log and the
#   script moves on to the next run instead of stopping.
# - Runs whose logs\<name>.log already says "Training completed" are SKIPPED, so after
#   a crash you can just run .\run_all.ps1 again and it picks up where it stopped.
# - At the end, a summary of every run is printed and saved to logs\summary.txt.
 
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
New-Item -ItemType Directory -Force -Path logs | Out-Null
 
# ---------------------------------------------------------------------------
# Runs to do. All Tiny ImageNet runs use the fixed validation split in utils/dataset.py.
# ---------------------------------------------------------------------------
$runs = @(
  @{ name = "alexnet_bn_tiny";     script = "train.py"; args = "--model alexnet --norm bn --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_tiny_imagenet.pth --plot-file plots/loss_tiny_imagenet.png" },
  @{ name = "lenet_tiny";          script = "train.py"; args = "--model lenet --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/lenet_tiny.pth --plot-file plots/loss_lenet_tiny.png" },
  @{ name = "lenet_modern_tiny";   script = "train.py"; args = "--model lenet_modern --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/lenet_modern_tiny.pth --plot-file plots/loss_lenet_modern_tiny.png" },
  @{ name = "alexnet_none_tiny";   script = "train.py"; args = "--model alexnet --norm none --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_none_tiny.pth --plot-file plots/loss_alexnet_none_tiny.png" },
  @{ name = "alexnet_lrn_tiny";    script = "train.py"; args = "--model alexnet --norm lrn --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_lrn_tiny.pth --plot-file plots/loss_alexnet_lrn_tiny.png" },
  @{ name = "alexnet_aug_tiny";    script = "train.py"; args = "--model alexnet --norm bn --dataset tiny_imagenet --epochs 10 --seed 42 --save-model checkpoints/alexnet_aug_tiny.pth --plot-file plots/loss_alexnet_aug_tiny.png" },
  @{ name = "zoo_alexnet_tiny";    script = "train.py"; args = "--model zoo_alexnet --dataset tiny_imagenet --epochs 10 --seed 42 --no-augment --save-model checkpoints/zoo_alexnet_tiny.pth --plot-file plots/loss_zoo_alexnet_tiny.png" },
  @{ name = "zoo_alexnet_cifar";   script = "train.py"; args = "--model zoo_alexnet --dataset cifar10 --epochs 10 --seed 42 --no-augment --save-model checkpoints/zoo_alexnet.pth --plot-file plots/loss_zoo_alexnet.png" },
  # Not training runs - these finish in seconds. Run after training so the GPU is idle.
  @{ name = "compare_models";      script = "compare_models.py";  args = "--dataset cifar10" },
  @{ name = "demo_transforms";     script = "demo_transforms.py"; args = "" }
)
 
$results = @()
 
foreach ($run in $runs) {
  $log  = "logs\$($run.name).log"
  $tmp  = "logs\$($run.name).running.log"
  $fail = "logs\$($run.name).FAILED.log"
 
  # Skip runs that already finished in an earlier attempt
  if (Test-Path $log) {
    Write-Host "`nSKIP $($run.name): $log already exists" -ForegroundColor Yellow
    $results += [pscustomobject]@{ Run = $run.name; Status = "done earlier" }
    continue
  }
 
  Write-Host "`n===== START $($run.name)  ($(Get-Date -Format 'HH:mm:ss')) =====" -ForegroundColor Cyan
  $start = Get-Date
 
  $argList = @()
  if ($run.args) { $argList = $run.args -split ' ' }
 
  # Run; show output live and write it to the .running.log file line by line.
  # ForEach-Object turns Python's warnings (stderr) into plain text lines.
  & python -X utf8 -u $run.script @argList 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $tmp
  $code = $LASTEXITCODE
 
  $minutes = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)
  $isTrain = $run.script -eq "train.py"
  $ok = ($code -eq 0)
  if ($ok -and $isTrain) { $ok = Select-String -Path $tmp -Pattern "Training completed" -Quiet }
 
  if ($ok) {
    Move-Item -Force $tmp $log
    Write-Host "===== DONE  $($run.name) in $minutes min -> $log =====" -ForegroundColor Green
    $results += [pscustomobject]@{ Run = $run.name; Status = "OK ($minutes min)" }
  } else {
    Move-Item -Force $tmp $fail
    Write-Host "===== FAILED $($run.name) (exit code $code) -> $fail =====" -ForegroundColor Red
    $results += [pscustomobject]@{ Run = $run.name; Status = "FAILED (exit $code) - see $fail" }
  }
}
 
# ---------------------------------------------------------------------------
# Summary: status of every run + the key result lines from each finished log
# ---------------------------------------------------------------------------
$summary = @()
$summary += "ELEC 475 Lab 2 - run summary ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
$summary += ""
foreach ($r in $results) { $summary += ("{0,-22} {1}" -f $r.Run, $r.Status) }
$summary += ""
foreach ($run in $runs) {
  $log = "logs\$($run.name).log"
  if ((Test-Path $log) -and ($run.script -eq "train.py")) {
    $summary += "--- $($run.name) ---"
    Select-String -Path $log -Pattern "Training completed|Best Val Accuracy|Model Complexity" |
      ForEach-Object { $summary += "  " + $_.Line.Trim() }
  }
}
 
Write-Host "`n"
$summary | ForEach-Object { Write-Host $_ }
$summary | Set-Content -Encoding utf8 logs\summary.txt
Write-Host "`nSummary saved to logs\summary.txt" -ForegroundColor Cyan