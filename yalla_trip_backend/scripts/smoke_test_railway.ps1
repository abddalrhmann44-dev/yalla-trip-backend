# Smoke test the Railway production deployment after a Wave 30 push.
# Walks through the freshly shipped endpoints to confirm:
#   - /health/live       → basic liveness
#   - /health/ready      → DB reachable (alembic upgrade happened)
#   - /promo-banners/active → new public router mounted
#   - /admin/* (a few)   → returns 401/403 when unauth (router mounted)
#
# Any 5xx, timeout, or missing router counts as FAIL.

$ErrorActionPreference = "Stop"
$base = "https://yalla-trip-backend-production.up.railway.app"

function Probe {
    param([string]$Path, [string]$Label, [int[]]$ExpectedCodes = @(200))
    # Use raw System.Net.Http client so we get the status code even
    # for non-2xx responses without PowerShell raising exceptions.
    # (``Invoke-WebRequest -SkipHttpErrorCheck`` is PS7+ only.)
    try {
        $req = [System.Net.HttpWebRequest]::Create($base + $Path)
        $req.Method = "GET"
        $req.Timeout = 30000
        $req.AllowAutoRedirect = $false
        try {
            $resp = $req.GetResponse()
        } catch [System.Net.WebException] {
            $resp = $_.Exception.Response
            if ($null -eq $resp) { throw }
        }
        $code = [int]$resp.StatusCode
        $body = ""
        try {
            $stream = $resp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $body = $reader.ReadToEnd()
            $reader.Close()
        } catch { $body = "" }
        $resp.Close()
        $ok = $ExpectedCodes -contains $code
        $mark = if ($ok) { "PASS" } else { "FAIL" }
        $preview = ""
        if ($body) {
            $len = [Math]::Min($body.Length, 140)
            $preview = $body.Substring(0, $len).Replace("`n", " ").Replace("`r", "")
        }
        Write-Host ("[{0}] {1,-40} HTTP {2}  {3}" -f $mark, $Label, $code, $preview)
        return $ok
    } catch {
        Write-Host ("[FAIL] {0,-40} ERROR: {1}" -f $Label, $_.Exception.Message)
        return $false
    }
}

Write-Host ""
Write-Host "=== Railway production smoke test ==="
Write-Host "Target: $base"
Write-Host ""

$all = $true
$all = (Probe "/health/live"                    "health.live")                      -and $all
$all = (Probe "/health/ready"                   "health.ready")                     -and $all
$all = (Probe "/promo-banners/active"           "promo_banners.active (Wave 30)")   -and $all
# Admin endpoints: we don't have a token, so 401/403 means the router IS mounted.
$all = (Probe "/admin/feature-flags"            "admin.feature_flags (Wave 30)"     @(401, 403)) -and $all
$all = (Probe "/admin/api-keys"                 "admin.api_keys (Wave 30)"          @(401, 403)) -and $all
$all = (Probe "/admin/promo-banners"            "admin.promo_banners (Wave 30)"     @(401, 403)) -and $all
$all = (Probe "/admin/chat/messages"            "admin.chat_monitor (Wave 30)"      @(401, 403)) -and $all
$all = (Probe "/admin/settings"                 "admin.platform_settings"           @(401, 403)) -and $all
$all = (Probe "/admin/analytics/advanced"       "admin.advanced_analytics"          @(401, 403)) -and $all
$all = (Probe "/admin/fraud-detection"          "admin.fraud_detection"             @(401, 403)) -and $all

Write-Host ""
if ($all) {
    Write-Host "=== ALL CHECKS PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== SOME CHECKS FAILED ===" -ForegroundColor Red
    exit 1
}
