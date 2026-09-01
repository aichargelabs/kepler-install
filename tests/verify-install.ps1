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
    BoundedElevation = ($text.Contains('KEPLER_ELEVATED') -and $text.Contains('-Verb RunAs'))
    SacConditionalSignatureGate = ($text -match '(?is)if \(\$sacState -like ''On\*''\).*?Test-KeplerSignatureGate')
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value })
$checks.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }
if ($failed.Count -gt 0) { exit 2 }
exit 0
