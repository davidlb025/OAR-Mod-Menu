[CmdletBinding()]
param([switch]$FrameworkDependent)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$build=Join-Path $repo 'build'
$dist=Join-Path $repo 'dist'
New-Item -ItemType Directory -Path $build,$dist -Force | Out-Null
$archive=Join-Path $repo 'vendor\UE4SS_v3.0.1-1190-gf673aac0.zip'
$expectedHash='3CE35217FEAD1982E4563EF974364B7CFEDF1DD6D28BB1193CAF19877310364B'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expectedHash) { throw 'El archivo de UE4SS no coincide con la dependencia fijada.' }
$staging=Join-Path $build ('stage-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging -Force | Out-Null
$unpacked=Join-Path $build ('ue4ss-'+[guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
Copy-Item -LiteralPath (Join-Path $unpacked 'ue4ss\UE4SS.dll') -Destination $staging
Copy-Item -LiteralPath (Join-Path $unpacked 'dwmapi.dll') -Destination $staging
Copy-Item -LiteralPath (Join-Path $repo 'config\UE4SS-settings.ini') -Destination $staging
$mods=Join-Path $staging 'Mods'
New-Item -ItemType Directory -Path $mods -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'src\OARPracticeMenu') -Destination $mods -Recurse
Copy-Item -LiteralPath (Join-Path $repo 'vendor\UE4SS-LICENSE.txt') -Destination (Join-Path $mods 'OARPracticeMenu\UE4SS-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $mods 'OARPracticeMenu\LICENSE.txt')
$package=Join-Path $build 'package.zip'
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $package -Force
$project=Join-Path $repo 'installer\OARPracticeMenu.Setup.csproj'
$publish=Join-Path $build ('publish-'+[guid]::NewGuid().ToString('N'))
$selfContained=if($FrameworkDependent){'false'}else{'true'}
dotnet publish $project -c Release -r win-x64 --self-contained $selfContained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o $publish
if ($LASTEXITCODE) { throw 'Ha fallado la compilación del instalador.' }
$exe=Join-Path $publish 'OAR-Mod-Menu-v1.0.0-Setup.exe'
Copy-Item -LiteralPath $exe -Destination $dist -Force
$portable=Join-Path $dist 'OAR-Mod-Menu-v1.0.0-Portable.zip'
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $portable -Force
$sumLines=Get-ChildItem -LiteralPath $dist -File | Where-Object {$_.Extension -in '.exe','.zip'} | Sort-Object Name | ForEach-Object { ((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()+'  '+$_.Name) }
$sumLines | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Encoding ASCII
Write-Host ('Listo: '+$dist)
