# run_extra.ps1 - ELEC 475 Lab 2 post-lab: benchmark fix, LRN collapse check, multi-seed repeats
#
# HOW TO USE (from the Lab2 folder, with .venv active):
#     Unblock-File .\run_extra.ps1   (once, after downloading)
#     .\run_extra.ps1
#
# - Each run's output is shown live AND written to logs\<name>.running.log as it goes.
# - When a run finishes successfully, that file is renamed to logs\<name>.log.
# - If a run crashes, its partial output is kept as logs\<name>.FAILED.log and the
#   script moves on to the next run instead of stopping.
# - Runs whose logs\<name>.log already says "Training completed" are SKIPPED, so after
#   a crash you can just run .\run_all.ps1 again and it picks up where it stopped.
# - At the end, a summary of every run is printed and saved to logs\summary_extra.txt.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
New-Item -ItemType Directory -Force -Path logs | Out-Null

# ---------------------------------------------------------------------------
# Runs to do (about 1 hour in total).
# ---------------------------------------------------------------------------
$runs = @(
  # 1. Benchmark (fixed: compare_models.py has no --device flag)
  @{ name = "compare_models";        script = "compare_models.py"; args = "--dataset cifar10" },
  # 2. LRN collapse on Tiny ImageNet: is it the seed, or the learning rate?
  @{ name = "alexnet_lrn_tiny_s43";  script = "train.py"; args = "--model alexnet --norm lrn --dataset tiny_imagenet --epochs 10 --seed 43 --no-augment --save-model checkpoints/alexnet_lrn_tiny_s43.pth --plot-file plots/loss_alexnet_lrn_tiny_s43.png" },
  @{ name = "alexnet_lrn_tiny_s44";  script = "train.py"; args = "--model alexnet --norm lrn --dataset tiny_imagenet --epochs 10 --seed 44 --no-augment --save-model checkpoints/alexnet_lrn_tiny_s44.pth --plot-file plots/loss_alexnet_lrn_tiny_s44.png" },
  @{ name = "alexnet_lrn_tiny_lr3e-4"; script = "train.py"; args = "--model alexnet --norm lrn --dataset tiny_imagenet --epochs 10 --seed 42 --lr 0.0003 --no-augment --save-model checkpoints/alexnet_lrn_tiny_lr3e-4.pth --plot-file plots/loss_alexnet_lrn_tiny_lr3e-4.png" },
  # 3. Multi-seed repeats of the CIFAR-10 normalization study (seed 42 already done) -> mean +/- std
  @{ name = "alexnet_none_s43";      script = "train.py"; args = "--model alexnet --norm none --dataset cifar10 --epochs 10 --seed 43 --no-augment --save-model checkpoints/alexnet_none_s43.pth --plot-file plots/loss_alexnet_none_s43.png" },
  @{ name = "alexnet_none_s44";      script = "train.py"; args = "--model alexnet --norm none --dataset cifar10 --epochs 10 --seed 44 --no-augment --save-model checkpoints/alexnet_none_s44.pth --plot-file plots/loss_alexnet_none_s44.png" },
  @{ name = "alexnet_lrn_s43";       script = "train.py"; args = "--model alexnet --norm lrn --dataset cifar10 --epochs 10 --seed 43 --no-augment --save-model checkpoints/alexnet_lrn_s43.pth --plot-file plots/loss_alexnet_lrn_s43.png" },
  @{ name = "alexnet_lrn_s44";       script = "train.py"; args = "--model alexnet --norm lrn --dataset cifar10 --epochs 10 --seed 44 --no-augment --save-model checkpoints/alexnet_lrn_s44.pth --plot-file plots/loss_alexnet_lrn_s44.png" },
  @{ name = "alexnet_bn_s43";        script = "train.py"; args = "--model alexnet --norm bn --dataset cifar10 --epochs 10 --seed 43 --no-augment --save-model checkpoints/alexnet_bn_s43.pth --plot-file plots/loss_alexnet_bn_s43.png" },
  @{ name = "alexnet_bn_s44";        script = "train.py"; args = "--model alexnet --norm bn --dataset cifar10 --epochs 10 --seed 44 --no-augment --save-model checkpoints/alexnet_bn_s44.pth --plot-file plots/loss_alexnet_bn_s44.png" }
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
$summary | Set-Content -Encoding utf8 logs\summary_extra.txt
Write-Host "`nSummary saved to logs\summary_extra.txt" -ForegroundColor Cyan
