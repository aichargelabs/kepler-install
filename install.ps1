# KeplerCrew client installer.
# Usage: powershell -ExecutionPolicy Bypass -Command "irm https://get.keplercrew.com/install.ps1 | iex"
# Env:
#   KEPLER_LICENSE_KEY  license key (prompted securely if not set)
#   KEPLER_VERSION      optional version such as 1.0.0 (default: latest)
#   KEPLER_DRY_RUN      set to 1 to resolve and print the release without downloading
#   KEPLER_INSTALL_DIR  optional install directory (default: %LOCALAPPDATA%\Programs\KeplerCrew)
#   KEPLER_NO_LAUNCH    set to 1 to skip launching after install
# Author: aichargelabs.

function Install-KeplerCrew {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $account = '11cdb180-ce9f-4b8b-82c6-ca59f9b2c512'
        $api = 'https://api.keygen.sh/v1/accounts/' + $account
        $jsonApi = 'application/vnd.api+json'

        # 1. License key — env var, or prompt (never echoed, never left in shell history).
        $key = $env:KEPLER_LICENSE_KEY
        if ([string]::IsNullOrWhiteSpace($key)) {
            if ([Console]::IsInputRedirected) {
                throw 'Set KEPLER_LICENSE_KEY when running non-interactively.'
            }
            $secure = Read-Host 'Enter your KeplerCrew license key' -AsSecureString
            $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        }
        $key = $key.Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw 'A license key is required.'
        }

        # 2. Validate the key before downloading anything.
        Write-Host 'Validating license...'
        $validation = Invoke-RestMethod -Method Post `
            -Uri ($api + '/licenses/actions/validate-key') `
            -ContentType $jsonApi -Headers @{ Accept = $jsonApi } `
            -Body (@{ meta = @{ key = $key } } | ConvertTo-Json)
        if (-not $validation.meta.valid) {
            $code = [string]$validation.meta.code
            throw ('License is not valid (' + $code + '). Contact support@aichargelabs.com.')
        }
        Write-Host 'License OK.'

        # 3. Resolve the release (latest published, or KEPLER_VERSION).
        $auth = @{ Accept = $jsonApi; Authorization = ('License ' + $key) }
        $releases = (Invoke-RestMethod -Uri ($api + '/releases?limit=20') -Headers $auth).data |
            Where-Object { $_.attributes.status -eq 'PUBLISHED' }
        $wanted = $env:KEPLER_VERSION
        if (-not [string]::IsNullOrWhiteSpace($wanted)) {
            $wanted = $wanted.Trim().TrimStart('v')
            $release = $releases | Where-Object { $_.attributes.version -eq $wanted } | Select-Object -First 1
            if ($null -eq $release) { throw ('Version "' + $wanted + '" was not found or your license cannot access it.') }
        }
        else {
            $release = $releases | Select-Object -First 1
            if ($null -eq $release) { throw 'No published release is available for your license.' }
        }
        $version = [string]$release.attributes.version

        # 4. Resolve the Windows zip artifact of that release. License-key auth
        #    cannot LIST artifacts, so the filename follows the release convention.
        #    The singular endpoint answers 303 whose body carries the artifact
        #    metadata and whose Location is the signed download URL; redirects are
        #    handled manually so the Authorization header never reaches storage.
        $filename = 'KeplerCrew-win32-x64-' + $version + '.zip'
        $metaReq = [Net.HttpWebRequest]::Create($api + '/releases/' + $release.id + '/artifacts/' + $filename)
        $metaReq.Method = 'GET'
        $metaReq.Accept = $jsonApi
        $metaReq.Headers.Add('Authorization', 'License ' + $key)
        $metaReq.AllowAutoRedirect = $false
        $metaResp = $null
        try {
            $metaResp = $metaReq.GetResponse()
        }
        catch [Net.WebException] {
            # .NET surfaces the 303 redirect itself as a WebException — recover it.
            $metaResp = $_.Exception.Response
            if ($null -eq $metaResp -or [int]$metaResp.StatusCode -ge 400) {
                throw ('Release ' + $version + ' has no Windows bundle yet (' + $filename + ' not found).')
            }
        }
        $location = [string]$metaResp.Headers['Location']
        $reader = New-Object IO.StreamReader($metaResp.GetResponseStream())
        $meta = $reader.ReadToEnd() | ConvertFrom-Json
        $reader.Close(); $metaResp.Close()
        if ([string]::IsNullOrWhiteSpace($location)) {
            throw ('The artifact endpoint returned no download location for ' + $filename)
        }
        $expected = [string]$meta.data.attributes.checksum

        if ($env:KEPLER_DRY_RUN -eq '1') {
            Write-Host ('Version:  ' + $version)
            Write-Host ('Artifact: ' + $filename)
            Write-Host ('SHA256:   ' + $expected)
            return
        }

        # 5. Download from the signed URL (time-limited, no credentials attached).
        Write-Host ('Downloading KeplerCrew ' + $version + '...')
        $downloadDir = Join-Path $env:TEMP 'keplercrew-install'
        New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
        $zipPath = Join-Path $downloadDir $filename
        Invoke-WebRequest -Uri $location -OutFile $zipPath -UseBasicParsing

        # 6. Verify checksum.
        if (-not [string]::IsNullOrWhiteSpace($expected)) {
            $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
            if ($actual -ne $expected.ToLowerInvariant()) {
                throw ('Checksum mismatch — download corrupted. Expected ' + $expected + ' got ' + $actual)
            }
            Write-Host 'Checksum OK.'
        }

        # 7. Extract.
        $installDir = $env:KEPLER_INSTALL_DIR
        if ([string]::IsNullOrWhiteSpace($installDir)) {
            $installDir = Join-Path $env:LOCALAPPDATA 'Programs\KeplerCrew'
        }
        Write-Host ('Installing to ' + $installDir + '...')
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
        Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force
        Remove-Item -LiteralPath $zipPath -Force

        # 8. Store the license for the launcher — user-only ACL, never world-readable.
        $licenseDir = Join-Path $installDir 'licenses'
        New-Item -ItemType Directory -Path $licenseDir -Force | Out-Null
        $licenseFile = Join-Path $licenseDir 'customer.key'
        Set-Content -LiteralPath $licenseFile -Value $key -NoNewline -Encoding ascii
        icacls $licenseFile /inheritance:r /grant:r ($env:USERNAME + ':(R,W)') | Out-Null

        Write-Host ('KeplerCrew ' + $version + ' installed.')

        # 9. Launch.
        $runScript = Join-Path $installDir 'run.ps1'
        if ((Test-Path -LiteralPath $runScript) -and ($env:KEPLER_NO_LAUNCH -ne '1')) {
            Write-Host 'Starting KeplerCrew...'
            Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $runScript -WorkingDirectory $installDir
        }
        else {
            Write-Host ('Run it any time: powershell -ExecutionPolicy Bypass -File "' + $runScript + '"')
        }
    }
    catch {
        Write-Error ('KeplerCrew installation failed: ' + $_.Exception.Message)
        exit 1
    }
}

Install-KeplerCrew
