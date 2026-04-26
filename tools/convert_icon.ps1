Add-Type -AssemblyName System.Drawing
$src = 'H:\Login_widget\assets\images\icon.jpg'
$img = [System.Drawing.Image]::FromFile($src)
$img.Save('H:\Login_widget\assets\images\icon.png',   [System.Drawing.Imaging.ImageFormat]::Png)
$img.Save('H:\Login_widget\assets\images\splash.png', [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
Get-Item 'H:\Login_widget\assets\images\icon.png','H:\Login_widget\assets\images\splash.png' |
  Select-Object Name, Length, LastWriteTime |
  Format-Table -AutoSize
