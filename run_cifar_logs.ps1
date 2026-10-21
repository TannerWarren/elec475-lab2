# run_cifar_logs.ps1 - ELEC 475 Lab 2: re-run the CIFAR-10 seed-42 jobs WITH logging,
# then build plots/ablation_summary.png from those logs with the course's plotting function.
#
# Why: these runs were first done without saving their output, so no logs\*.log exist for them.
# Training is seeded (seed 42, same GPU), so the numbers should match the first runs exactly -
# this also serves as a check of the report's CIFAR-10 values.
#
# HOW TO USE (from the Lab2 folder, with .venv active; about 40 min on the RTX 3060 Ti):
#     Unblock-File .\run_cifar_logs.ps1
#     .\run_cifar_logs.ps1
#
# Same behaviour as run_all.ps1: live output, logs\<name>.log on success, logs\<name>.FAILED.log
# on a crash, and runs that already have a logs\<name>.log are skipped if you start it again.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = "utf-8"
New-Item -ItemType Directory -Force -Path logs | Out-Null

# Same commands (and checkpoint/plot names) as commands.txt sections 2-4.
$runs = @(
  @{ name = "lenet_cifar";            script = "train.py"; args = "--model lenet --dataset cifar10 --epochs 5 --batch-size 128 --seed 42 --no-augment --save-model checkpoints/lenet_baseline.pth --plot-file plots/loss_lenet.png" },
  @{ name = "lenet_modern_cifar";     script = "train.py"; args = "--model lenet_modern --dataset cifar10 --epochs 5 --batch-size 128 --seed 42 --no-augment --save-model checkpoints/lenet_modern.pth --plot-file plots/loss_lenet_modern.png" },
  @{ name = "alexnet_none_cifar";     script = "train.py"; args = "--model alexnet --norm none --dataset cifar10 --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_none.pth --plot-file plots/loss_alexnet_none.png" },
  @{ name = "alexnet_lrn_cifar";      script = "train.py"; args = "--model alexnet --norm lrn --dataset cifar10 --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_lrn.pth --plot-file plots/loss_alexnet_lrn.png" },
  @{ name = "alexnet_bn_cifar";       script = "train.py"; args = "--model alexnet --norm bn --dataset cifar10 --epochs 10 --seed 42 --no-augment --save-model checkpoints/alexnet_bn.pth --plot-file plots/loss_alexnet_bn.png" },
  @{ name = "alexnet_no_aug_cifar";   script = "train.py"; args = "--model alexnet --norm bn --dataset cifar10 --epochs 15 --seed 42 --no-augment --save-model checkpoints/alexnet_no_aug.pth --plot-file plots/loss_no_aug.png" },
  @{ name = "alexnet_with_aug_cifar"; script = "train.py"; args = "--model alexnet --norm bn --dataset cifar10 --epochs 15 --seed 42 --save-model checkpoints/alexnet_with_aug.pth --plot-file plots/loss_with_aug.png" },
  # Not training - takes seconds. Runs last so the GPU is idle for the timing measurements.
  @{ name = "compare_models";         script = "compare_models.py"; args = "--dataset cifar10" }
)

$results = @()

foreach ($run in $runs) {
  $log  = "logs\$($run.name).log"
  $tmp  = "logs\$($run.name).running.log"
  $fail = "logs\$($run.name).FAILED.log"

  if (Test-Path $log) {
    Write-Host "`nSKIP $($run.name): $log already exists" -ForegroundColor Yellow
    $results += [pscustomobject]@{ Run = $run.name; Status = "done earlier" }
    continue
  }

  Write-Host "`n===== START $($run.name)  ($(Get-Date -Format 'HH:mm:ss')) =====" -ForegroundColor Cyan
  $start = Get-Date

  $argList = @()
  if ($run.args) { $argList = $run.args -split ' ' }

  & python -X utf8 -u $run.script @argList 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $tmp
  $code = $LASTEXITCODE

  $minutes = [math]::Round(((Get-Date) - $start).TotalMinutes, 1)
  $ok = ($code -eq 0)
  if ($ok -and $run.script -eq "train.py") { $ok = Select-String -Path $tmp -Pattern "Training completed" -Quiet }

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
# Summary of the runs
# ---------------------------------------------------------------------------
$summary = @()
$summary += "ELEC 475 Lab 2 - CIFAR-10 logged re-runs ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
$summary += ""
foreach ($r in $results) { $summary += ("{0,-24} {1}" -f $r.Run, $r.Status) }
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
$summary | Set-Content -Encoding utf8 logs\summary_cifar.txt
Write-Host "`nSummary saved to logs\summary_cifar.txt" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Ablation summary plot from the logs (uses utils.visualization.plot_ablation_summary)
# ---------------------------------------------------------------------------
Write-Host "`n===== ablation summary plot =====" -ForegroundColor Cyan
& python -X utf8 -u plot_ablation_summary.py 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath logs\plot_ablation_summary.log
