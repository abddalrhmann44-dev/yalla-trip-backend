# Generate a fully-transparent 1024x1024 PNG to use as the adaptive-icon
# foreground.  Pairing this with `adaptive_icon_background` set to the
# real icon image makes the launcher show ONLY the background layer at
# full canvas size — i.e. the user's design fills the entire icon with
# no inset and no extra orange ring.
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.Dispose()
$bmp.Save('H:\Login_widget\assets\images\icon_blank.png', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Get-Item 'H:\Login_widget\assets\images\icon_blank.png' | Select-Object Name, Length
