# Convert the user's new transparent/full-canvas icon (icon.jpg.jpeg) into
# the canonical PNG paths used by flutter_launcher_icons + native splash.
Add-Type -AssemblyName System.Drawing

$src = 'H:\Login_widget\assets\images\icon.jpg.jpeg'
if (-not (Test-Path $src)) { throw "Source icon not found: $src" }

$img = [System.Drawing.Image]::FromFile($src)
'Source: ' + $src
'Size  : ' + $img.Width + 'x' + $img.Height + ' (' + $img.PixelFormat + ')'

# Save as PNG so flutter_launcher_icons + flutter_native_splash accept it
$img.Save('H:\Login_widget\assets\images\icon.png',   [System.Drawing.Imaging.ImageFormat]::Png)
$img.Save('H:\Login_widget\assets\images\splash.png', [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()

Get-Item 'H:\Login_widget\assets\images\icon.png','H:\Login_widget\assets\images\splash.png' |
  Select-Object Name, Length, LastWriteTime |
  Format-Table -AutoSize
