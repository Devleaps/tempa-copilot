# Tempa launcher for Windows (TEMPA-115): the PowerShell twin of bin/tempa-launch, run through tempa-launch.cmd
# (which passes -ExecutionPolicy Bypass, so the default Restricted policy does not stop it).
#
# Order: a standalone tempa binary (TEMPA_BINARY, or tempa-win-<arch>.exe next to this script, Node inside it),
# then Node 20+ with tempa's JavaScript CLI (TEMPA_CLI, the bundled tempa.mjs, the path tempa remembered in
# ~/.tempa/cli-path, an npm install). Node: TEMPA_NODE, ~/.tempa/node-path, the PATH, the usual places.
#
# When it cannot start tempa, a hook call still gets a proper answer that explains the fix, exactly like the shell
# launcher: in Claude Code PreToolUse is denied and prompts are blocked (fail closed), SessionStart gets a
# warning; any other harness gets exit 2 with the fix on stderr. Anything else exits 127.
#
# TEMPA_LAUNCH_PATH_ONLY=1 (tests): no well-known locations.

$tempaHome = if ($env:TEMPA_HOME) { $env:TEMPA_HOME } else { Join-Path $HOME '.tempa' }
$here = $PSScriptRoot
$isHook = $args.Count -gt 0 -and $args[0] -eq 'hook'

function Read-FirstLine([string]$path) {
  if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
    return [string](Get-Content -LiteralPath $path -TotalCount 1)
  }
  return $null
}

function Get-NodeMajor([string]$node) {
  try {
    $v = & $node -v 2>$null
    if ("$v" -match '^v(\d+)\.') { return [int]$Matches[1] }
  } catch {}
  return 0
}

function Test-Node([string]$candidate) {
  return $candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf) -and ((Get-NodeMajor $candidate) -ge 20)
}

function Find-Node {
  $onPath = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  $candidates = @($env:TEMPA_NODE, (Read-FirstLine (Join-Path $tempaHome 'node-path')), $(if ($onPath) { $onPath.Source }))
  if (-not $env:TEMPA_LAUNCH_PATH_ONLY) {
    # The installer and nvm-windows' link, Volta, Scoop.
    $candidates += @(
      (Join-Path "$env:ProgramFiles" 'nodejs\node.exe'),
      (Join-Path "$env:LOCALAPPDATA" 'Volta\bin\node.exe'),
      (Join-Path $HOME 'scoop\shims\node.exe')
    )
  }
  foreach ($c in $candidates) { if (Test-Node $c) { return $c } }
  return $null
}

# A JavaScript CLI, not the install-cli wrapper (a shell script that runs the launcher).
function Test-Cli([string]$candidate) {
  if (-not $candidate -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $false }
  $second = Get-Content -LiteralPath $candidate -TotalCount 2 -ErrorAction SilentlyContinue | Select-Object -Skip 1
  return -not ("$second" -like '# Installed by /tempa:install-cli*')
}

function Find-Cli {
  $candidates = @($env:TEMPA_CLI, (Join-Path $here 'tempa.mjs'), (Read-FirstLine (Join-Path $tempaHome 'cli-path')))
  if (-not $env:TEMPA_LAUNCH_PATH_ONLY) {
    $candidates += @(Join-Path "$env:APPDATA" 'npm\node_modules\@devleaps\tempa\dist\tempa.js')
  }
  foreach ($c in $candidates) { if (Test-Cli $c) { return $c } }
  return $null
}

# The standalone binary: TEMPA_BINARY, else this plugin's for this machine. None when TEMPA_CLI is set.
function Find-Binary {
  if ($env:TEMPA_CLI) { return $null }
  if ($env:TEMPA_BINARY) {
    if (Test-Path -LiteralPath $env:TEMPA_BINARY -PathType Leaf) { return $env:TEMPA_BINARY }
    return $null
  }
  $arch = switch ($env:PROCESSOR_ARCHITECTURE) { 'AMD64' { 'x64' } 'ARM64' { 'arm64' } default { $null } }
  if (-not $arch) { return $null }
  $candidate = Join-Path $here "tempa-win-$arch.exe"
  if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  return $null
}

function Get-Harness {
  for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--harness' -and $i + 1 -lt $args.Count) { return $args[$i + 1] }
    if ($args[$i] -like '--harness=*') { return $args[$i].Substring(10) }
  }
  return 'claude-code'
}

function ConvertTo-JsonString([string]$text) {
  return '"' + ($text -replace '\\', '\\' -replace '"', '\"') + '"'
}

# Explain the problem and fail closed (see the shell launcher's `explain`).
function Exit-Explained([string]$problem, [string]$harness) {
  $install = switch ($harness) {
    'claude-code' { 'claude plugin install tempa@devleaps' }
    'copilot' { 'copilot plugin install tempa@devleaps' }
    'codex' { 'codex plugin marketplace add Devleaps/tempa, then Tempa from /plugins in Codex' }
    'gemini-cli' { 'gemini extensions update tempa' }
    'antigravity' { 'agy plugin install https://github.com/Devleaps/tempa/tree/plugin-release-antigravity' }
    default { 'reinstall the Tempa plugin' }
  }
  $fix = "Install Node.js 20 or newer, and install or update the plugin ($install), which carries the CLI. Guide: https://tempa.devleaps.nl/docs/install"
  if (-not $isHook) {
    [Console]::Error.WriteLine("tempa-launch: $problem. $fix")
    exit 127
  }
  $payload = [Console]::In.ReadToEnd()
  if ($harness -ne 'claude-code') {
    [Console]::Error.WriteLine("tempa-launch: Tempa is not running: $problem. $fix; blocking (fail closed)")
    exit 2
  }
  $hookEvent = if ($payload -match '"hook_event_name"\s*:\s*"([A-Za-z]*)"') { $Matches[1] } else { '' }
  $text = ConvertTo-JsonString "Tempa is not running: $problem. $fix"
  switch ($hookEvent) {
    'PreToolUse' {
      [Console]::Out.WriteLine("{""hookSpecificOutput"":{""hookEventName"":""PreToolUse"",""permissionDecision"":""deny"",""permissionDecisionReason"":$text}}")
    }
    'UserPromptSubmit' { [Console]::Out.WriteLine("{""decision"":""block"",""reason"":$text}") }
    'SessionStart' {
      $context = ConvertTo-JsonString "Tempa is not running: $problem. $fix Tool calls and prompts are blocked until it is fixed; tell the developer how to fix it."
      [Console]::Out.WriteLine("{""hookSpecificOutput"":{""hookEventName"":""SessionStart"",""additionalContext"":$context},""systemMessage"":$text}")
    }
  }
  exit 0
}

# Claude Code treats any exit code other than 0 and 2 as a non-blocking error: a hook that tempa fails in another
# way becomes 2, so it still fails closed.
function Exit-With([int]$status) {
  if ($isHook -and $status -ne 0 -and $status -ne 2) {
    [Console]::Error.WriteLine("tempa-launch: tempa exited with status $status; blocking (fail closed)")
    exit 2
  }
  exit $status
}

$harness = if ($isHook) { Get-Harness @args } else { 'claude-code' }

$binary = Find-Binary
if ($binary) {
  try {
    & $binary @args
    Exit-With $LASTEXITCODE
  } catch {
    # Not a program this machine runs (another architecture, blocked): nothing read stdin yet, try Node.
    [Console]::Error.WriteLine("tempa-launch: $binary cannot run on this machine ($($_.Exception.Message)); trying Node")
  }
}

$node = Find-Node
if (-not $node) {
  $pathNode = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($pathNode) {
    $version = & $pathNode.Source -v 2>$null
    Exit-Explained "it needs Node.js 20 or newer, and node on PATH is $version" $harness
  }
  Exit-Explained 'it needs Node.js 20 or newer and none was found' $harness
}
$cli = Find-Cli
if (-not $cli) { Exit-Explained 'the tempa CLI was not found' $harness }

& $node $cli @args
Exit-With $LASTEXITCODE
