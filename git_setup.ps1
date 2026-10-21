# git_setup.ps1 - ELEC 475 Lab 2: build a clean git history with feature branches
#
# HOW TO USE (from the Lab2 folder; Git for Windows must be installed):
#     Unblock-File .\git_setup.ps1
#     .\git_setup.ps1
#
# What it does:
#   1. Writes a .gitignore (excludes .venv, data, checkpoints, OneNote files).
#   2. Commits the starter template (with the ORIGINAL versions of the files you changed).
#   3. Adds your work on separate branches, each merged into main:
#        inlab/lenet, postlab/alexnet, postlab/augmentation,
#        fix/tiny-imagenet-val, fix/profiler-device, results/experiments
#   4. Leaves every file in the folder exactly as it is now (verified at the end).
# It does NOT push anything. The final lines tell you how to push to GitHub.

$ErrorActionPreference = "Stop"

function Run-Git {
  & $gitExe @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

$gitExe = (Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $gitExe) {
  Write-Host "Git is not installed. Install Git for Windows (https://git-scm.com/download/win), reopen PowerShell, and run this again." -ForegroundColor Red
  exit 1
}
if (Test-Path .git) {
  Write-Host "This folder is already a git repository (.git exists). Nothing was changed." -ForegroundColor Red
  exit 1
}
$needed = @("train.py", "models\lenet.py", "models\lenet_modern.py", "models\alexnet.py",
            "utils\dataset.py", "utils\profiler.py", "utils\transforms.py")
foreach ($f in $needed) {
  if (-not (Test-Path $f)) { Write-Host "Missing $f - run this from the Lab2 folder." -ForegroundColor Red; exit 1 }
}

# git identity (stored only in this repository)
$name  = (& $gitExe config user.name)
$email = (& $gitExe config user.email)
if (-not $name)  { $name  = Read-Host "Your name for git commits" }
if (-not $email) { $email = Read-Host "Your email for git commits (use your GitHub email)" }

# ---- back up your final versions of the four files we temporarily swap ----
$backup = Join-Path $env:TEMP ("elec475_git_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $backup | Out-Null
$swap = @("models\alexnet.py", "utils\transforms.py", "utils\dataset.py", "utils\profiler.py")
$hashBefore = @{}
foreach ($f in $swap) {
  Copy-Item $f (Join-Path $backup ($f -replace '\\', '__'))
  $hashBefore[$f] = (Get-FileHash $f).Hash
}
Write-Host "Backed up your final files to $backup" -ForegroundColor DarkGray

function Write-Original([string]$path, [string]$b64) {
  $text = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
  $current = [IO.File]::ReadAllText((Resolve-Path $path))
  if ($current.Contains("`r`n")) { $text = ($text -replace "`r?`n", "`r`n") }
  [IO.File]::WriteAllText((Resolve-Path $path), $text, (New-Object Text.UTF8Encoding($false)))
}
function Restore-Final([string]$path) {
  Copy-Item -Force (Join-Path $backup ($path -replace '\\', '__')) $path
}

$ORIG_ALEXNET    = "IiIiCkVMRUMgNDc1OiBMYWIgMiAtIEZ1bGwgQWxleE5ldCBBcmNoaXRlY3R1cmUgKFN0YXJ0ZXIgVGVtcGxhdGUpCkFkYXB0ZWQgZm9yIDY0eDY0IFJHQiBpbnB1dCB3aXRoIGNvbmZpZ3VyYWJsZSBOb3JtYWxpemF0aW9uOgogICAgLSAnbm9uZSc6IE5vIG5vcm1hbGl6YXRpb24KICAgIC0gJ2xybicgOiBMb2NhbCBSZXNwb25zZSBOb3JtYWxpemF0aW9uIChvcmlnaW5hbCAyMDEyIHBhcGVyKQogICAgLSAnYm4nICA6IE1vZGVybiBCYXRjaCBOb3JtYWxpemF0aW9uIChtb2Rlcm4gc3RhbmRhcmQgcG9zdC0yMDE1KQoKUmVmZXJlbmNlOgogICAgQS4gS3JpemhldnNreSwgSS4gU3V0c2tldmVyLCBhbmQgRy4gRS4gSGludG9uLAogICAgIkltYWdlTmV0IENsYXNzaWZpY2F0aW9uIHdpdGggRGVlcCBDb252b2x1dGlvbmFsIE5ldXJhbCBOZXR3b3JrcywiCiAgICBOZXVySVBTIDIwMTIuCiIiIgppbXBvcnQgdG9yY2gKaW1wb3J0IHRvcmNoLm5uIGFzIG5uCgpjbGFzcyBBbGV4TmV0NjQobm4uTW9kdWxlKToKICAgICIiIgogICAgQWxleE5ldCBhcmNoaXRlY3R1cmUgYWRhcHRlZCBmb3IgKDMsIDY0LCA2NCkgUkdCIGltYWdlcy4KICAgIEZlYXR1cmVzIDUgZGVlcCBjb252b2x1dGlvbmFsIHN0YWdlcywgb3ZlcmxhcHBpbmcgTWF4UG9vbCAoM3gzLCBzPTIpLAogICAgY29uZmlndXJhYmxlIG5vcm1hbGl6YXRpb24gKExSTiB2cyBCYXRjaE5vcm0pLCBhbmQgZGVuc2UgY2xhc3NpZmllciB3aXRoIERyb3BvdXQgKHA9MC41KS4KCiAgICBTcGF0aWFsIGRpbWVuc2lvbnMgdGhyb3VnaCB0aGUgbmV0d29yazoKICAgICAgICBJbnB1dCAgIDogKEIsIDMsIDY0LCA2NCkKICAgICAgICBDb252MSAgIDogNXg1LCBzPTIsIHA9MiAgLS0+IChCLCA2NCwgMzIsIDMyKQogICAgICAgIFBvb2wxICAgOiAzeDMsIHM9MiAgICAgICAtLT4gKEIsIDY0LCAxNSwgMTUpCiAgICAgICAgQ29udjIgICA6IDV4NSwgcz0xLCBwPTIgIC0tPiAoQiwgMTkyLCAxNSwgMTUpCiAgICAgICAgUG9vbDIgICA6IDN4Mywgcz0yICAgICAgIC0tPiAoQiwgMTkyLCA3LCA3KQogICAgICAgIENvbnYzICAgOiAzeDMsIHM9MSwgcD0xICAtLT4gKEIsIDM4NCwgNywgNykKICAgICAgICBDb252NCAgIDogM3gzLCBzPTEsIHA9MSAgLS0+IChCLCAzODQsIDcsIDcpCiAgICAgICAgQ29udjUgICA6IDN4Mywgcz0xLCBwPTEgIC0tPiAoQiwgMjU2LCA3LCA3KQogICAgICAgIFBvb2wzICAgOiAzeDMsIHM9MiAgICAgICAtLT4gKEIsIDI1NiwgMywgMykKICAgICAgICBGbGF0dGVuIDogMjU2ICogMyAqIDMgPSAyLDMwNCBmZWF0dXJlcwogICAgICAgIEZDMSAgICAgOiAyLDMwNCAtPiAxLDAyNCAod2l0aCBEcm9wb3V0IDAuNSAmIFJlTFUpCiAgICAgICAgRkMyICAgICA6IDEsMDI0IC0+IDEsMDI0ICh3aXRoIERyb3BvdXQgMC41ICYgUmVMVSkKICAgICAgICBGQzMgICAgIDogMSwwMjQgLT4gbnVtX2NsYXNzZXMKICAgICIiIgogICAgZGVmIF9faW5pdF9fKHNlbGYsIG51bV9jbGFzc2VzOiBpbnQgPSAxMCwgaW5fY2hhbm5lbHM6IGludCA9IDMsIG5vcm1fdHlwZTogc3RyID0gImJuIik6CiAgICAgICAgc3VwZXIoQWxleE5ldDY0LCBzZWxmKS5fX2luaXRfXygpCiAgICAgICAgc2VsZi5udW1fY2xhc3NlcyA9IG51bV9jbGFzc2VzCiAgICAgICAgc2VsZi5pbl9jaGFubmVscyA9IGluX2NoYW5uZWxzCiAgICAgICAgc2VsZi5ub3JtX3R5cGUgPSBub3JtX3R5cGUubG93ZXIoKQoKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICAjIEhlbHBlcjogTm9ybWFsaXphdGlvbiBMYXllciBGYWN0b3J5CiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgZGVmIGdldF9ub3JtX2xheWVyKG51bV9mZWF0dXJlczogaW50KSAtPiBubi5Nb2R1bGU6CiAgICAgICAgICAgIGlmIHNlbGYubm9ybV90eXBlID09ICJibiI6CiAgICAgICAgICAgICAgICByZXR1cm4gbm4uQmF0Y2hOb3JtMmQobnVtX2ZlYXR1cmVzKQogICAgICAgICAgICBlbGlmIHNlbGYubm9ybV90eXBlID09ICJscm4iOgogICAgICAgICAgICAgICAgIyBPcmlnaW5hbCBBbGV4TmV0IExSTjogaz0yLCBuPTUsIGFscGhhPTFlLTQsIGJldGE9MC43NQogICAgICAgICAgICAgICAgcmV0dXJuIG5uLkxvY2FsUmVzcG9uc2VOb3JtKHNpemU9NSwgYWxwaGE9MWUtNCwgYmV0YT0wLjc1LCBrPTIuMCkKICAgICAgICAgICAgZWxpZiBzZWxmLm5vcm1fdHlwZSA9PSAibm9uZSI6CiAgICAgICAgICAgICAgICByZXR1cm4gbm4uSWRlbnRpdHkoKQogICAgICAgICAgICBlbHNlOgogICAgICAgICAgICAgICAgcmFpc2UgVmFsdWVFcnJvcihmIlVua25vd24gbm9ybV90eXBlICd7bm9ybV90eXBlfScuIENob29zZSBmcm9tICdub25lJywgJ2xybicsICdibicuIikKCiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgIyBUT0RPIFtQT1NULUxBQiBTVEVQIDEgJiAyXTogSW1wbGVtZW50IHRoZSA1LVN0YWdlIEFsZXhOZXQgRmVhdHVyZSBFeHRyYWN0b3IKICAgICAgICAjCiAgICAgICAgIyBCdWlsZCBzZWxmLmZlYXR1cmVzIHVzaW5nIG5uLlNlcXVlbnRpYWwgb3IgYSBsaXN0IG9mIGxheWVyczoKICAgICAgICAjICAgU3RhZ2UgMTogQ29udjJkKGluX2NoYW5uZWxzLCA2NCwga2VybmVsX3NpemU9NSwgc3RyaWRlPTIsIHBhZGRpbmc9MikKICAgICAgICAjICAgICAgICAgICAgLT4gZ2V0X25vcm1fbGF5ZXIoNjQpCiAgICAgICAgIyAgICAgICAgICAgIC0+IG5uLlJlTFUoaW5wbGFjZT1UcnVlKQogICAgICAgICMgICAgICAgICAgICAtPiBubi5NYXhQb29sMmQoa2VybmVsX3NpemU9Mywgc3RyaWRlPTIpCiAgICAgICAgIwogICAgICAgICMgICBTdGFnZSAyOiBDb252MmQoNjQsIDE5Miwga2VybmVsX3NpemU9NSwgc3RyaWRlPTEsIHBhZGRpbmc9MikKICAgICAgICAjICAgICAgICAgICAgLT4gZ2V0X25vcm1fbGF5ZXIoMTkyKQogICAgICAgICMgICAgICAgICAgICAtPiBubi5SZUxVKGlucGxhY2U9VHJ1ZSkKICAgICAgICAjICAgICAgICAgICAgLT4gbm4uTWF4UG9vbDJkKGtlcm5lbF9zaXplPTMsIHN0cmlkZT0yKQogICAgICAgICMKICAgICAgICAjICAgU3RhZ2UgMzogQ29udjJkKDE5MiwgMzg0LCBrZXJuZWxfc2l6ZT0zLCBzdHJpZGU9MSwgcGFkZGluZz0xKQogICAgICAgICMgICAgICAgICAgICAtPiAobm4uQmF0Y2hOb3JtMmQoMzg0KSBpZiBzZWxmLm5vcm1fdHlwZSA9PSAnYm4nIGVsc2Ugbm4uSWRlbnRpdHkoKSkKICAgICAgICAjICAgICAgICAgICAgLT4gbm4uUmVMVShpbnBsYWNlPVRydWUpCiAgICAgICAgIwogICAgICAgICMgICBTdGFnZSA0OiBDb252MmQoMzg0LCAzODQsIGtlcm5lbF9zaXplPTMsIHN0cmlkZT0xLCBwYWRkaW5nPTEpCiAgICAgICAgIyAgICAgICAgICAgIC0+IChubi5CYXRjaE5vcm0yZCgzODQpIGlmIHNlbGYubm9ybV90eXBlID09ICdibicgZWxzZSBubi5JZGVudGl0eSgpKQogICAgICAgICMgICAgICAgICAgICAtPiBubi5SZUxVKGlucGxhY2U9VHJ1ZSkKICAgICAgICAjCiAgICAgICAgIyAgIFN0YWdlIDU6IENvbnYyZCgzODQsIDI1Niwga2VybmVsX3NpemU9Mywgc3RyaWRlPTEsIHBhZGRpbmc9MSkKICAgICAgICAjICAgICAgICAgICAgLT4gKG5uLkJhdGNoTm9ybTJkKDI1NikgaWYgc2VsZi5ub3JtX3R5cGUgPT0gJ2JuJyBlbHNlIG5uLklkZW50aXR5KCkpCiAgICAgICAgIyAgICAgICAgICAgIC0+IG5uLlJlTFUoaW5wbGFjZT1UcnVlKQogICAgICAgICMgICAgICAgICAgICAtPiBubi5NYXhQb29sMmQoa2VybmVsX3NpemU9Mywgc3RyaWRlPTIpCiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgc2VsZi5mZWF0dXJlcyA9IG5uLlNlcXVlbnRpYWwoCiAgICAgICAgICAgICMgUmVwbGFjZSB3aXRoIHlvdXIgNS1zdGFnZSBjb252b2x1dGlvbmFsIGFyY2hpdGVjdHVyZQogICAgICAgICkKCiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgIyBUT0RPIFtQT1NULUxBQiBTVEVQIDFdOiBJbXBsZW1lbnQgdGhlIERlbnNlIENsYXNzaWZpZXIgd2l0aCBEcm9wb3V0CiAgICAgICAgIwogICAgICAgICMgUmVxdWlyZW1lbnRzOgogICAgICAgICMgICAxLiBubi5Ecm9wb3V0KHA9MC41KQogICAgICAgICMgICAyLiBubi5MaW5lYXIoaW5fZmVhdHVyZXM9MjU2ICogMyAqIDMsIG91dF9mZWF0dXJlcz0xMDI0KQogICAgICAgICMgICAzLiBubi5SZUxVKGlucGxhY2U9VHJ1ZSkKICAgICAgICAjICAgNC4gbm4uRHJvcG91dChwPTAuNSkKICAgICAgICAjICAgNS4gbm4uTGluZWFyKGluX2ZlYXR1cmVzPTEwMjQsIG91dF9mZWF0dXJlcz0xMDI0KQogICAgICAgICMgICA2LiBubi5SZUxVKGlucGxhY2U9VHJ1ZSkKICAgICAgICAjICAgNy4gbm4uTGluZWFyKGluX2ZlYXR1cmVzPTEwMjQsIG91dF9mZWF0dXJlcz1udW1fY2xhc3NlcykKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICBzZWxmLmNsYXNzaWZpZXIgPSBubi5TZXF1ZW50aWFsKAogICAgICAgICAgICAjIFJlcGxhY2Ugd2l0aCB5b3VyIGRyb3BvdXQtcmVndWxhcml6ZWQgZGVuc2UgY2xhc3NpZmllcgogICAgICAgICkKCiAgICBkZWYgZm9yd2FyZChzZWxmLCB4OiB0b3JjaC5UZW5zb3IpIC0+IHRvcmNoLlRlbnNvcjoKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICAjIFRPRE8gW1BPU1QtTEFCIFNURVAgMV06IEltcGxlbWVudCB0aGUgRm9yd2FyZCBQYXNzCiAgICAgICAgIyAxLiBQYXNzIGlucHV0IHggdGhyb3VnaCBzZWxmLmZlYXR1cmVzOiB4ID0gc2VsZi5mZWF0dXJlcyh4KQogICAgICAgICMgMi4gRmxhdHRlbiBmZWF0dXJlIG1hcHM6IHggPSB0b3JjaC5mbGF0dGVuKHgsIHN0YXJ0X2RpbT0xKQogICAgICAgICMgMy4gUGFzcyBmbGF0dGVuZWQgdmVjdG9yIHRocm91Z2ggc2VsZi5jbGFzc2lmaWVyOiBsb2dpdHMgPSBzZWxmLmNsYXNzaWZpZXIoeCkKICAgICAgICAjIDQuIFJldHVybiBsb2dpdHMKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICBwYXNzCgppZiBfX25hbWVfXyA9PSAiX19tYWluX18iOgogICAgZnJvbSB0b3JjaGluZm8gaW1wb3J0IHN1bW1hcnkKICAgIG1vZGVsID0gQWxleE5ldDY0KG51bV9jbGFzc2VzPTEwLCBpbl9jaGFubmVscz0zLCBub3JtX3R5cGU9ImJuIikKICAgIHByaW50KCJUZXN0aW5nIEFsZXhOZXQtNjQgQXJjaGl0ZWN0dXJlOiIpCiAgICB0cnk6CiAgICAgICAgc3VtbWFyeShtb2RlbCwgaW5wdXRfc2l6ZT0oMSwgMywgNjQsIDY0KSkKICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZToKICAgICAgICBwcmludChmIk1vZGVsIG5vdCBmdWxseSBpbXBsZW1lbnRlZCB5ZXQ6IHtlfSIpCg=="
$ORIG_TRANSFORMS = "IiIiCkVMRUMgNDc1OiBMYWIgMiAtIFB5VG9yY2ggVHJhbnNmb3JtICYgQXVnbWVudGF0aW9uIFBpcGVsaW5lcyAoU3RhcnRlciBUZW1wbGF0ZSkKIiIiCmltcG9ydCB0b3JjaHZpc2lvbi50cmFuc2Zvcm1zIGFzIHRyYW5zZm9ybXMKCkRBVEFTRVRfU1RBVFMgPSB7CiAgICAiY2lmYXIxMCI6IHsKICAgICAgICAibWVhbiI6IFswLjQ5MTQsIDAuNDgyMiwgMC40NDY1XSwKICAgICAgICAic3RkIjogIFswLjI0NzAsIDAuMjQzNSwgMC4yNjE2XQogICAgfSwKICAgICJ0aW55X2ltYWdlbmV0IjogewogICAgICAgICJtZWFuIjogWzAuNDgwMiwgMC40NDgxLCAwLjM5NzVdLAogICAgICAgICJzdGQiOiAgWzAuMjc2NCwgMC4yNjg5LCAwLjI4MjFdCiAgICB9Cn0KCmRlZiBnZXRfdHJhaW5fdHJhbnNmb3JtcyhkYXRhc2V0OiBzdHIgPSAiY2lmYXIxMCIsIGF1Z21lbnQ6IGJvb2wgPSBUcnVlLCB0YXJnZXRfc2l6ZTogaW50ID0gNjQpOgogICAgIiIiCiAgICBDb25zdHJ1Y3RzIHRoZSB0cmFpbmluZyB0cmFuc2Zvcm0gcGlwZWxpbmUuCiAgICAiIiIKICAgIHN0YXRzID0gREFUQVNFVF9TVEFUUy5nZXQoZGF0YXNldC5sb3dlcigpLCBEQVRBU0VUX1NUQVRTWyJjaWZhcjEwIl0pCiAgICAKICAgIHRyYW5zZm9ybV9saXN0ID0gWwogICAgICAgIHRyYW5zZm9ybXMuUmVzaXplKCh0YXJnZXRfc2l6ZSwgdGFyZ2V0X3NpemUpKQogICAgXQoKICAgIGlmIGF1Z21lbnQ6CiAgICAgICAgIyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiAgICAgICAgIyBUT0RPIFtQT1NULUxBQiBTVEVQIDNdOiBJbXBsZW1lbnQgUHlUb3JjaCBEYXRhIEF1Z21lbnRhdGlvbiBQaXBlbGluZQogICAgICAgICMKICAgICAgICAjIEFkZCB0aGUgZm9sbG93aW5nIHB1cmUgUHlUb3JjaCBHUFUtZnJpZW5kbHkgdHJhbnNmb3JtYXRpb25zOgogICAgICAgICMgICAxLiB0cmFuc2Zvcm1zLlJhbmRvbUNyb3AodGFyZ2V0X3NpemUsIHBhZGRpbmc9NCwgcGFkZGluZ19tb2RlPSJyZWZsZWN0IikKICAgICAgICAjICAgMi4gdHJhbnNmb3Jtcy5SYW5kb21Ib3Jpem9udGFsRmxpcChwPTAuNSkKICAgICAgICAjICAgMy4gdHJhbnNmb3Jtcy5Db2xvckppdHRlcihicmlnaHRuZXNzPTAuMiwgY29udHJhc3Q9MC4yLCBzYXR1cmF0aW9uPTAuMikKICAgICAgICAjID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0KICAgICAgICBwYXNzCgogICAgdHJhbnNmb3JtX2xpc3QuZXh0ZW5kKFsKICAgICAgICB0cmFuc2Zvcm1zLlRvVGVuc29yKCksCiAgICAgICAgdHJhbnNmb3Jtcy5Ob3JtYWxpemUobWVhbj1zdGF0c1sibWVhbiJdLCBzdGQ9c3RhdHNbInN0ZCJdKQogICAgXSkKCiAgICByZXR1cm4gdHJhbnNmb3Jtcy5Db21wb3NlKHRyYW5zZm9ybV9saXN0KQoKZGVmIGdldF90ZXN0X3RyYW5zZm9ybXMoZGF0YXNldDogc3RyID0gImNpZmFyMTAiLCB0YXJnZXRfc2l6ZTogaW50ID0gNjQpOgogICAgIiIiCiAgICBDb25zdHJ1Y3RzIGRldGVybWluaXN0aWMgZXZhbHVhdGlvbiB0cmFuc2Zvcm0gcGlwZWxpbmUgKG5vIHJhbmRvbSBhdWdtZW50YXRpb25zKS4KICAgICIiIgogICAgc3RhdHMgPSBEQVRBU0VUX1NUQVRTLmdldChkYXRhc2V0Lmxvd2VyKCksIERBVEFTRVRfU1RBVFNbImNpZmFyMTAiXSkKICAgIHJldHVybiB0cmFuc2Zvcm1zLkNvbXBvc2UoWwogICAgICAgIHRyYW5zZm9ybXMuUmVzaXplKCh0YXJnZXRfc2l6ZSwgdGFyZ2V0X3NpemUpKSwKICAgICAgICB0cmFuc2Zvcm1zLlRvVGVuc29yKCksCiAgICAgICAgdHJhbnNmb3Jtcy5Ob3JtYWxpemUobWVhbj1zdGF0c1sibWVhbiJdLCBzdGQ9c3RhdHNbInN0ZCJdKQogICAgXSkK"
$ORIG_DATASET    = "IiIiCkVMRUMgNDc1OiBMYWIgMiAtIFVuaWZpZWQgRGF0YXNldCAmIERhdGFMb2FkZXIgRmFjdG9yeQpTdXBwb3J0cyBDSUZBUi0xMCAocHJpbWFyeSkgYW5kIFRpbnkgSW1hZ2VOZXQtMjAwIChzZWNvbmRhcnkgYmVuY2htYXJrKS4KIiIiCmltcG9ydCBvcwppbXBvcnQgdXJsbGliLnJlcXVlc3QKaW1wb3J0IHppcGZpbGUKaW1wb3J0IHRvcmNoCmZyb20gdG9yY2gudXRpbHMuZGF0YSBpbXBvcnQgRGF0YUxvYWRlcgpmcm9tIHRvcmNodmlzaW9uLmRhdGFzZXRzIGltcG9ydCBDSUZBUjEwLCBJbWFnZUZvbGRlcgpmcm9tIC50cmFuc2Zvcm1zIGltcG9ydCBnZXRfdHJhaW5fdHJhbnNmb3JtcywgZ2V0X3Rlc3RfdHJhbnNmb3JtcwoKQ0lGQVIxMF9DTEFTU0VTID0gWwogICAgJ2FpcnBsYW5lJywgJ2F1dG9tb2JpbGUnLCAnYmlyZCcsICdjYXQnLCAnZGVlcicsCiAgICAnZG9nJywgJ2Zyb2cnLCAnaG9yc2UnLCAnc2hpcCcsICd0cnVjaycKXQoKVElOWV9JTUFHRU5FVF9VUkwgPSAiaHR0cDovL2NzMjMxbi5zdGFuZm9yZC5lZHUvdGlueS1pbWFnZW5ldC0yMDAuemlwIgoKZGVmIGRvd25sb2FkX2FuZF9leHRyYWN0X3RpbnlfaW1hZ2VuZXQoZGF0YV9kaXI6IHN0ciA9ICIuL2RhdGEiKToKICAgIHRhcmdldF9kaXIgPSBvcy5wYXRoLmpvaW4oZGF0YV9kaXIsICJ0aW55LWltYWdlbmV0LTIwMCIpCiAgICBpZiBvcy5wYXRoLmV4aXN0cyh0YXJnZXRfZGlyKToKICAgICAgICByZXR1cm4gdGFyZ2V0X2RpcgoKICAgIG9zLm1ha2VkaXJzKGRhdGFfZGlyLCBleGlzdF9vaz1UcnVlKQogICAgemlwX3BhdGggPSBvcy5wYXRoLmpvaW4oZGF0YV9kaXIsICJ0aW55LWltYWdlbmV0LTIwMC56aXAiKQoKICAgIGlmIG5vdCBvcy5wYXRoLmV4aXN0cyh6aXBfcGF0aCk6CiAgICAgICAgcHJpbnQoZiJEb3dubG9hZGluZyBUaW55IEltYWdlTmV0LTIwMCBmcm9tIHtUSU5ZX0lNQUdFTkVUX1VSTH0uLi4iKQogICAgICAgIHVybGxpYi5yZXF1ZXN0LnVybHJldHJpZXZlKFRJTllfSU1BR0VORVRfVVJMLCB6aXBfcGF0aCkKICAgICAgICBwcmludCgiRG93bmxvYWQgY29tcGxldGUuIikKCiAgICBwcmludChmIkV4dHJhY3Rpbmcge3ppcF9wYXRofS4uLiIpCiAgICB3aXRoIHppcGZpbGUuWmlwRmlsZSh6aXBfcGF0aCwgJ3InKSBhcyB6aXBfcmVmOgogICAgICAgIHppcF9yZWYuZXh0cmFjdGFsbChkYXRhX2RpcikKICAgIHByaW50KCJFeHRyYWN0aW9uIGNvbXBsZXRlLiIpCiAgICByZXR1cm4gdGFyZ2V0X2RpcgoKZGVmIGdldF9kYXRhbG9hZGVycygKICAgIGRhdGFzZXQ6IHN0ciA9ICJjaWZhcjEwIiwKICAgIGRhdGFfZGlyOiBzdHIgPSAiLi9kYXRhIiwKICAgIGJhdGNoX3NpemU6IGludCA9IDEyOCwKICAgIG51bV93b3JrZXJzOiBpbnQgPSAyLAogICAgcGluX21lbW9yeTogYm9vbCA9IFRydWUsCiAgICB1c2VfYXVnbWVudGF0aW9uOiBib29sID0gVHJ1ZSwKICAgIHRhcmdldF9zaXplOiBpbnQgPSA2NAopOgogICAgZGF0YXNldF9uYW1lID0gZGF0YXNldC5sb3dlcigpCgogICAgaWYgZGF0YXNldF9uYW1lID09ICJjaWZhcjEwIjoKICAgICAgICB0cmFpbl90ZiA9IGdldF90cmFpbl90cmFuc2Zvcm1zKCJjaWZhcjEwIiwgYXVnbWVudD11c2VfYXVnbWVudGF0aW9uLCB0YXJnZXRfc2l6ZT10YXJnZXRfc2l6ZSkKICAgICAgICB2YWxfdGYgICA9IGdldF90ZXN0X3RyYW5zZm9ybXMoImNpZmFyMTAiLCB0YXJnZXRfc2l6ZT10YXJnZXRfc2l6ZSkKCiAgICAgICAgdHJhaW5fc2V0ID0gQ0lGQVIxMChyb290PWRhdGFfZGlyLCB0cmFpbj1UcnVlLCBkb3dubG9hZD1UcnVlLCB0cmFuc2Zvcm09dHJhaW5fdGYpCiAgICAgICAgdmFsX3NldCAgID0gQ0lGQVIxMChyb290PWRhdGFfZGlyLCB0cmFpbj1GYWxzZSwgZG93bmxvYWQ9VHJ1ZSwgdHJhbnNmb3JtPXZhbF90ZikKICAgICAgICBudW1fY2xhc3NlcyA9IDEwCiAgICAgICAgY2xhc3NlcyA9IENJRkFSMTBfQ0xBU1NFUwoKICAgIGVsaWYgZGF0YXNldF9uYW1lIGluIFsidGlueV9pbWFnZW5ldCIsICJ0aW55aW1hZ2VuZXQiXToKICAgICAgICB0aW55X2RpciA9IGRvd25sb2FkX2FuZF9leHRyYWN0X3RpbnlfaW1hZ2VuZXQoZGF0YV9kaXIpCiAgICAgICAgdHJhaW5fZGlyID0gb3MucGF0aC5qb2luKHRpbnlfZGlyLCAidHJhaW4iKQoKICAgICAgICB0cmFpbl90ZiA9IGdldF90cmFpbl90cmFuc2Zvcm1zKCJ0aW55X2ltYWdlbmV0IiwgYXVnbWVudD11c2VfYXVnbWVudGF0aW9uLCB0YXJnZXRfc2l6ZT10YXJnZXRfc2l6ZSkKICAgICAgICB2YWxfdGYgICA9IGdldF90ZXN0X3RyYW5zZm9ybXMoInRpbnlfaW1hZ2VuZXQiLCB0YXJnZXRfc2l6ZT10YXJnZXRfc2l6ZSkKCiAgICAgICAgdHJhaW5fc2V0ID0gSW1hZ2VGb2xkZXIocm9vdD10cmFpbl9kaXIsIHRyYW5zZm9ybT10cmFpbl90ZikKICAgICAgICB2YWxfc2V0ICAgPSBJbWFnZUZvbGRlcihyb290PXRyYWluX2RpciwgdHJhbnNmb3JtPXZhbF90ZikKICAgICAgICBudW1fY2xhc3NlcyA9IDIwMAogICAgICAgIGNsYXNzZXMgPSB0cmFpbl9zZXQuY2xhc3NlcwoKICAgIGVsc2U6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcihmIlVua25vd24gZGF0YXNldCAne2RhdGFzZXR9Jy4gQ2hvb3NlIGZyb20gJ2NpZmFyMTAnLCAndGlueV9pbWFnZW5ldCcuIikKCiAgICB0cmFpbl9sb2FkZXIgPSBEYXRhTG9hZGVyKAogICAgICAgIHRyYWluX3NldCwKICAgICAgICBiYXRjaF9zaXplPWJhdGNoX3NpemUsCiAgICAgICAgc2h1ZmZsZT1UcnVlLAogICAgICAgIG51bV93b3JrZXJzPW51bV93b3JrZXJzLAogICAgICAgIHBpbl9tZW1vcnk9cGluX21lbW9yeSBhbmQgdG9yY2guY3VkYS5pc19hdmFpbGFibGUoKSwKICAgICAgICBkcm9wX2xhc3Q9VHJ1ZQogICAgKQoKICAgIHZhbF9sb2FkZXIgPSBEYXRhTG9hZGVyKAogICAgICAgIHZhbF9zZXQsCiAgICAgICAgYmF0Y2hfc2l6ZT1iYXRjaF9zaXplLAogICAgICAgIHNodWZmbGU9RmFsc2UsCiAgICAgICAgbnVtX3dvcmtlcnM9bnVtX3dvcmtlcnMsCiAgICAgICAgcGluX21lbW9yeT1waW5fbWVtb3J5IGFuZCB0b3JjaC5jdWRhLmlzX2F2YWlsYWJsZSgpLAogICAgICAgIGRyb3BfbGFzdD1GYWxzZQogICAgKQoKICAgIHJldHVybiB0cmFpbl9sb2FkZXIsIHZhbF9sb2FkZXIsIG51bV9jbGFzc2VzLCBjbGFzc2VzCg=="

try {
  # ---- starter versions of the swapped files ----
  Write-Original "models\alexnet.py"   $ORIG_ALEXNET
  Write-Original "utils\transforms.py" $ORIG_TRANSFORMS
  Write-Original "utils\dataset.py"    $ORIG_DATASET
  # profiler.py: the only change was one added line; remove it to get the starter version
  $lines = [IO.File]::ReadAllLines((Resolve-Path "utils\profiler.py"))
  $out = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($i -gt 0 -and $lines[$i - 1] -match 'for name, model in models_dict\.items\(\):' -and $lines[$i] -match '^\s*model\s*=\s*model\.to\(') { continue }
    $out.Add($lines[$i])
  }
  $nl = "`n"; if ([IO.File]::ReadAllText((Resolve-Path "utils\profiler.py")).Contains("`r`n")) { $nl = "`r`n" }
  [IO.File]::WriteAllText((Resolve-Path "utils\profiler.py"), ($out -join $nl) + $nl, (New-Object Text.UTF8Encoding($false)))

  # ---- repository + .gitignore ----
  if (-not (Test-Path .gitignore)) {
    [IO.File]::WriteAllText((Join-Path (Get-Location) ".gitignore"), @"
# Python
__pycache__/
*.pyc
.venv/

# Datasets and large training artifacts (checkpoints go in the OnQ zip, not git)
data/
checkpoints/
*.pth

# Windows / OneNote clutter
*.onetoc2
Thumbs.db
desktop.ini

# Submission packaging and in-progress logs
submission/
*.zip
logs/*.running.log

# Files set aside by cleanup_lab2.ps1
_archive/
"@, (New-Object Text.UTF8Encoding($false)))
  }
  Run-Git init -q
  Run-Git symbolic-ref HEAD refs/heads/main
  Run-Git config user.name  "$name"
  Run-Git config user.email "$email"

  # ---- 1. starter template on main ----
  Run-Git add -A
  Run-Git rm -r -q --cached --ignore-unmatch -- models/lenet.py models/lenet_modern.py logs plots `
        commands.txt github_repo.txt run_all.ps1 run_extra.ps1 run_cifar_logs.ps1 cleanup_lab2.ps1 git_setup.ps1 make_submission.ps1 `
        plot_ablation_summary.py ELEC475_Lab2_Report.pdf
  Run-Git commit -q -m "Initial commit: ELEC 475 Lab 2 starter template"

  function Branch-Commit([string]$branch, [string[]]$paths, [string]$msg) {
    Run-Git checkout -q -b $branch
    Run-Git add -A -- @paths
    Run-Git commit -q -m $msg
    Run-Git checkout -q main
    Run-Git merge -q --no-ff $branch -m "Merge branch '$branch'"
  }

  # ---- 2. in-lab ----
  Branch-Commit "inlab/lenet" @("models/lenet.py", "models/lenet_modern.py") `
    "In-lab: implement LeNet-5 and modernized LeNet (ReLU, overlapping MaxPool, padding 2)"

  # ---- 3. post-lab Step 1 ----
  Restore-Final "models\alexnet.py"
  Branch-Commit "postlab/alexnet" @("models/alexnet.py") `
    "Post-lab Step 1: implement 5-stage AlexNet-64 with none/LRN/BatchNorm and dropout classifier"

  # ---- 4. post-lab Step 3 ----
  Restore-Final "utils\transforms.py"
  Branch-Commit "postlab/augmentation" @("utils/transforms.py") `
    "Post-lab Step 3: RandomCrop, RandomHorizontalFlip and ColorJitter augmentation pipeline"

  # ---- 5. bug fixes ----
  Restore-Final "utils\dataset.py"
  Branch-Commit "fix/tiny-imagenet-val" @("utils/dataset.py") `
    "Fix Tiny ImageNet validation: read val/images + val_annotations.txt instead of the training folder"

  Restore-Final "utils\profiler.py"
  Branch-Commit "fix/profiler-device" @("utils/profiler.py") `
    "Fix compare_models crash: move each model to the device before profiling"

  # ---- 6. results ----
  Branch-Commit "results/experiments" @(".") `
    "Add training logs, plots, run scripts, ablation plot script and commands.txt"
}
finally {
  # Always put your final files back, even if something above failed
  foreach ($f in $swap) { Restore-Final $f }
}

# ---- verify nothing in your folder changed ----
$ok = $true
foreach ($f in $swap) {
  if ((Get-FileHash $f).Hash -ne $hashBefore[$f]) { $ok = $false; Write-Host "WARNING: $f differs from your backup in $backup" -ForegroundColor Red }
}
if ($ok) { Write-Host "`nAll your files are unchanged." -ForegroundColor Green }
$dirty = (& $gitExe status --porcelain)
if ($dirty) { Write-Host "Note: uncommitted changes remain:`n$dirty" -ForegroundColor Yellow }

Write-Host "`nHistory:" -ForegroundColor Cyan
& $gitExe log --oneline --graph --all

Write-Host @"

NEXT STEPS
1. On github.com: New repository -> name it (e.g. elec475-lab2) -> do NOT add a README -> Create.
2. Then run (paste your repository URL):
     git remote add origin https://github.com/<you>/<repo>.git
     git push -u origin main
     git push origin --all
3. Put the URL in github_repo.txt, then after exporting the report PDF:
     git add github_repo.txt ELEC475_Lab2_Report.pdf
     git commit -m "Add final report and repository link"
     git push
"@ -ForegroundColor Cyan
