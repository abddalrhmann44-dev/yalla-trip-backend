# ─────────────────────────────────────────────────────────────────────
# Convert assets/images/icon.jpg → assets/images/icon_fg.png with the
# white background turned transparent so it works as an Android
# adaptive_icon_foreground without showing white halos around the logo.
# ─────────────────────────────────────────────────────────────────────
Add-Type -AssemblyName System.Drawing

$src = 'H:\Login_widget\assets\images\icon.jpg'
$dst = 'H:\Login_widget\assets\images\icon_fg.png'

$srcImg = [System.Drawing.Bitmap]::new($src)
$w = $srcImg.Width
$h = $srcImg.Height

# Draw onto a 32-bit ARGB canvas (JPG is 24-bit, has no alpha channel)
$bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($srcImg, 0, 0, $w, $h)
$g.Dispose()
$srcImg.Dispose()

# Lock the bits and walk every pixel; bytes are stored as B,G,R,A
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$data = $bmp.LockBits(
    $rect,
    [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ptr   = $data.Scan0
$len   = $data.Stride * $h
$bytes = New-Object byte[] $len
[System.Runtime.InteropServices.Marshal]::Copy($ptr, $bytes, 0, $len)

# Threshold: any pixel where R, G, B are all >= 235 is treated as
# "background white" and made fully transparent.  235 leaves a small
# margin so JPG compression noise around the logo edge still wins.
$threshold = 235
for ($i = 0; $i -lt $len; $i += 4) {
    if ($bytes[$i]   -ge $threshold -and
        $bytes[$i+1] -ge $threshold -and
        $bytes[$i+2] -ge $threshold) {
        $bytes[$i+3] = 0
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $ptr, $len)
$bmp.UnlockBits($data)
$bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Get-Item $dst | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
