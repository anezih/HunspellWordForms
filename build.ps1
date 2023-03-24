dotnet publish .\src\HunspellWordForms.csproj -c Release
Write-Host ""
$dlls = Get-ChildItem -Path .\src\bin\Release\net7.0\publish -Filter *.dll
foreach ($dll in $dlls) {
    Copy-Item -Destination .\Unmunch -Path $dll.FullName
    Write-Host "*** Copied $($dll.Name) to Unmunch directory."
}