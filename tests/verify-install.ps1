param([Parameter(Mandatory = $true)][string]$InstallerPath)

$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $InstallerPath, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) {
    $errors | ForEach-Object { Write-Error $_.Message }
    exit 1
}

$text = [IO.File]::ReadAllText($InstallerPath)
$priorTestOnly = $env:KEPLER_INSTALLER_TEST_ONLY
$env:KEPLER_INSTALLER_TEST_ONLY = '1'
try { . $InstallerPath }
finally { $env:KEPLER_INSTALLER_TEST_ONLY = $priorTestOnly }

$wideBindCases = @(
    'python server.py --host 0.0.0.0',
    'python server.py --host [::]',
    'python server.py --host *',
    '$host = "::"',
    '[Net.IPAddress]::Any',
    '[Net.IPAddress]::IPv6Any'
)
$wideBindBehavior = $true
foreach ($case in $wideBindCases) {
    if (-not (Test-KeplerWideBind -ScriptText $case)) { $wideBindBehavior = $false }
}
$loopbackBehavior = -not (Test-KeplerWideBind -ScriptText 'python server.py --host 127.0.0.1')

$checks = [ordered]@{
    ParserClean = $true
    AuthenticodeGate = $text.Contains('Get-AuthenticodeSignature')
    RejectsInvalidSignature = $text.Contains('SIGN-INVALID')
    ReadsSmartAppControl = $text.Contains('VerifiedAndReputablePolicyState')
    NeverWritesSmartAppControl = ($text -notmatch '(?is)(Set|New)-ItemProperty[^\r\n]*VerifiedAndReputablePolicyState')
    NoDefenderWeakening = ($text -notmatch '(?i)(Set-MpPreference|Add-MpPreference)')
    NoFirewallMutation = ($text -notmatch '(?i)(New-NetFirewallRule|Set-NetFirewallRule|Remove-NetFirewallRule|Set-NetFirewallProfile)')
    NoQuarantineRestoreGuidance = ($text -notmatch '(?i)quarantined a binary: restore it')
    LoopbackOnlyProbe = $text.Contains('http://127.0.0.1:')
    RejectsWideBind = $text.Contains('BIND-WIDE')
    RejectsWideBindVariants = ($wideBindBehavior -and $loopbackBehavior)
    IncludesHiddenSignedFiles = ($text -match '(?is)Get-ChildItem[^\r\n]*-Force')
    DefaultPathNeverElevates = ($text.Contains('DEFAULT-PATH-UNWRITABLE') -and $text.Contains('$customInstallDir'))
    LaunchScopedIntegrityEvents = ($text.Contains('$StartedAt') -and $text.Contains('$launchStartedAt'))
    BoundedElevation = ($text.Contains('KEPLER_ELEVATED') -and $text.Contains('-Verb RunAs'))
    SacConditionalSignatureGate = ($text -match '(?is)if \(\$sacState -like ''On\*''\).*?Test-KeplerSignatureGate')
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
$checks.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }
if ($failed.Count -gt 0) { exit 2 }
exit 0
