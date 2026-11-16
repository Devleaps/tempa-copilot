# Tempa launcher for Windows: the PowerShell twin of bin/tempa-launch, run through tempa-launch.cmd
# (which passes -ExecutionPolicy Bypass, so the default Restricted policy does not stop it).
#
# Order: a standalone tempa binary (TEMPA_BINARY, or tempa-win-<arch>.exe next to this script, Node inside it),
# then Node 20+ with tempa's JavaScript CLI (TEMPA_CLI, the bundled tempa.mjs, the path tempa remembered in
# ~/.tempa/cli-path, an npm install). Node: TEMPA_NODE, ~/.tempa/node-path, the PATH, the usual places.
#
# When it cannot start tempa, a hook call still gets a proper answer that explains the fix, exactly like the shell
# launcher: in Claude Code PreToolUse is denied and prompts are blocked (fail closed), SessionStart gets a
# warning; any other harness gets exit 2 with the fix on stderr on a gate, and exit 0 on an event that cannot stop
# anything. Anything else exits 127.
#
# When tempa ends a hook with a status other than its own 0 and 2 (a crash, for example Node dying at exit after the
# answer was written), an event that cannot stop anything gets exit 0 with a note on stderr, and a gate gets the
# answer tempa already wrote, or exit 2 when there is none (see the shell launcher).
#
# TEMPA_LAUNCH_PATH_ONLY=1 (tests): no well-known locations.

$tempaHome = if ($env:TEMPA_HOME) { $env:TEMPA_HOME } else { Join-Path $HOME '.tempa' }
$here = $PSScriptRoot
$isHook = $args.Count -gt 0 -and $args[0] -eq 'hook'

# The hook events that cannot stop anything, as each harness names them; every other event is a gate. tempa-launch
# and tempa-launch.mjs keep the same list (test/launcher-crash.test.ts holds them to it).
$nonGates = @('SessionStart', 'SessionEnd', 'PostToolUse', 'PostToolUseFailure', 'Stop', 'SubagentStop', 'Notification', 'PreCompact', 'AfterTool', 'AfterAgent', 'PostInvocation', 'sessionStart', 'sessionEnd', 'postToolUse', 'agentStop', 'subagentStop', 'errorOccurred')

# A hook's input, read once as bytes: tempa gets it on stdin, and the launcher reads the event from it.
$hookInput = [byte[]]@()
if ($isHook) {
  $buffer = New-Object System.IO.MemoryStream
  [Console]::OpenStandardInput().CopyTo($buffer)
  $hookInput = $buffer.ToArray()
}

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

# A hook call's option (`--harness <id>`, `--event <name>`); $null when it is not given.
function Get-Option([string]$name, [string[]]$arguments) {
  for ($i = 0; $i -lt $arguments.Count; $i++) {
    if ($arguments[$i] -eq "--$name" -and $i + 1 -lt $arguments.Count) { return $arguments[$i + 1] }
    if ($arguments[$i] -like "--$name=*") { return $arguments[$i].Substring($name.Length + 3) }
  }
  return $null
}

# Whether this hook call's event can stop something: --event, else every hook_event_name in the input; an event
# the launcher cannot name is a gate.
function Test-Gate {
  if ($script:eventArg) { return -not ($nonGates -ccontains $script:eventArg) }
  $text = [Text.Encoding]::UTF8.GetString($hookInput)
  $found = [regex]::Matches($text, '"hook_event_name"\s*:\s*"([A-Za-z]*)"')
  if ($found.Count -eq 0) { return $true }
  foreach ($m in $found) { if (-not ($nonGates -ccontains $m.Groups[1].Value)) { return $true } }
  return $false
}

# One argument on a Windows command line (the rules CommandLineToArgvW and Node read).
function ConvertTo-Argument([string]$arg) {
  if ($arg -and $arg -notmatch '[\s"]') { return $arg }
  $escaped = $arg -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1'
  return '"' + $escaped + '"'
}

# Run tempa for a hook with the input on its stdin and its stdout kept as bytes; stderr goes straight through.
# Throws when the program cannot be started.
function Invoke-Hook([string]$file, [string[]]$arguments) {
  $info = New-Object System.Diagnostics.ProcessStartInfo
  $info.FileName = $file
  $info.Arguments = (@($arguments) | ForEach-Object { ConvertTo-Argument $_ }) -join ' '
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardInput = $true
  $info.RedirectStandardOutput = $true
  $process = [System.Diagnostics.Process]::Start($info)
  $out = New-Object System.IO.MemoryStream
  $copy = $process.StandardOutput.BaseStream.CopyToAsync($out)
  try {
    $process.StandardInput.BaseStream.Write($hookInput, 0, $hookInput.Length)
    $process.StandardInput.Close()
  } catch {
    # tempa ended before reading all of its input: its status says what happened
  }
  $copy.Wait()
  $process.WaitForExit()
  return @{ Status = $process.ExitCode; Out = $out.ToArray() }
}

function Write-Bytes([byte[]]$bytes) {
  if ($bytes.Length -eq 0) { return }
  $stdout = [Console]::OpenStandardOutput()
  $stdout.Write($bytes, 0, $bytes.Length)
  $stdout.Flush()
}

# End a hook call with tempa's answer. 0 and 2 are tempa's own; anything else is a crash (see the top).
function Exit-Hook([int]$status, [byte[]]$out) {
  if ($status -eq 0 -or $status -eq 2) { Write-Bytes $out; exit $status }
  if (-not (Test-Gate)) {
    Write-Bytes $out
    [Console]::Error.WriteLine("tempa-launch: tempa exited with status $status; not blocking this event, which cannot stop anything")
    exit 0
  }
  $answer = [Text.Encoding]::UTF8.GetString($out).Trim()
  if ($answer.StartsWith('{') -and $answer.EndsWith('}')) {
    $parsed = $false
    try { $null = ConvertFrom-Json $answer; $parsed = $true } catch {}
    if ($parsed) {
      Write-Bytes $out
      [Console]::Error.WriteLine("tempa-launch: tempa exited with status $status after answering; passing its answer on")
      exit 0
    }
  }
  [Console]::Error.WriteLine("tempa-launch: tempa exited with status $status; blocking (fail closed)")
  exit 2
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
  $payload = [Text.Encoding]::UTF8.GetString($hookInput)
  if ($harness -ne 'claude-code') {
    if (-not (Test-Gate)) {
      [Console]::Error.WriteLine("tempa-launch: Tempa is not running: $problem. $fix")
      exit 0
    }
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

$harness = 'claude-code'
$eventArg = $null
if ($isHook) {
  $named = Get-Option 'harness' $args
  if ($named) { $harness = $named }
  $eventArg = Get-Option 'event' $args
}

$binary = Find-Binary
if ($binary) {
  $ran = $null
  try {
    if ($isHook) {
      $ran = Invoke-Hook $binary $args
    } else {
      & $binary @args
      exit $LASTEXITCODE
    }
  } catch {
    # Not a program this machine runs (another architecture, blocked): Node takes over with the same input.
    [Console]::Error.WriteLine("tempa-launch: $binary cannot run on this machine ($($_.Exception.Message)); trying Node")
  }
  if ($ran) { Exit-Hook $ran.Status $ran.Out }
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

if ($isHook) {
  # Claude Code treats any exit code other than 0 and 2 as a non-blocking error: Exit-Hook decides for a crash.
  $ran = Invoke-Hook $node (@($cli) + $args)
  Exit-Hook $ran.Status $ran.Out
}
& $node $cli @args
exit $LASTEXITCODE
