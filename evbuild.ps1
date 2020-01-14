$wxver = "3.1.3-20191030"
$optdir = @{
    x86 = "C:\opt (x86)"
    x64 = "C:\opt"
}
$prefix = @{
    x86 = "vc"
    x64 = "vc_x64"
}
$sdkver = ""

function SetupEnvironment([string]$platform, [string]$sdkver)
{
    # Default to our vc140 install path unless we find a newer install
    $vcvars = "${env:ProgramFiles(x86)}\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"

    # Try newer visual studio versions first in order to get a newer version of msbuild which may be required
    # Newer installs won't pickup the correct msbuild when executing vcvarsall from the old path
    $basePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
    gci -dir "$basePath" | % {
        gci -dir $_.FullName | % {
            $verPath = $_.FullName
            $filePath = "$verPath\VC\Auxiliary\Build\vcvarsall.bat"
            if (Test-Path "$filePath")
            {
                $vcvars = $filePath
            }
        }
    }

    # Is there a better way to get the environment than this?
    "$vcvars $platform $sdkver"
    cmd /c "`"$vcvars`" $platform $sdkver & set" | % { Invoke-Expression "`${env:$_`"".Replace("=", "}=`"") } 2>$null
}

function GetPlatform([string]$platform)
{
    if ($platform -eq "x86")
    {
        return "Win32"
    }

    return $platform
}


# Clean up any pre-existing builds artifacts
#pushd lib\
#rmdir -ea ig -force -recurse vc_*
#popd
#pushd build\msw\
#rmdir -ea ig -force -recurse vc_*
#popd
pushd include\wx\msw
del -ea ig -force setup.h
cat setup0.h | %{$_ -replace "#define wxUSE_EXCEPTIONS.*", "#define wxUSE_EXCEPTIONS 0" -replace "#define wxUSE_ON_FATAL_EXCEPTION.*", "#define wxUSE_ON_FATAL_EXCEPTION 0" -replace "#define wxUSE_CRASHREPORT.*", "#define wxUSE_CRASHREPORT 0" } > setup.h
popd

foreach ($platform in "x64", "x86")
{
    SetupEnvironment $platform $sdkver
    $slnPlatform = GetPlatform $platform

    pushd build\msw
    ${env:_LINK_}="/DEBUG"
    msbuild /m wx_vc14.sln /p:Configuration="DLL Debug" /p:Platform=$slnPlatform /p:PlatformToolset=v140 /p:wxToolkitDllNameSuffix=_vc_xdv
    msbuild /m wx_vc14.sln /p:Configuration="DLL Release" /p:Platform=$slnPlatform /p:PlatformToolset=v140 /p:wxToolkitDllNameSuffix=_vc_xdv

    # Debug and release configurations are /MDd so override them because we want to link the static runtime
    ${env:_CL_}="/MT"
    msbuild /m wx_vc14.sln /p:Configuration="Debug" /p:Platform=$slnPlatform /p:PlatformToolset=v140 /p:wxToolkitDllNameSuffix=_vc_xdv
    msbuild /m wx_vc14.sln /p:Configuration="Release" /p:Platform=$slnPlatform /p:PlatformToolset=v140 /p:wxToolkitDllNameSuffix=_vc_xdv
    ${env:_CL_}=""
    ${env:_LINK_}=""
    popd

    "Copying output..."
    $outdir = $optdir.$platform + "\wxWidgets\${wxver}_vc14"
    $libprefix = $prefix.$platform
    mkdir -p "$outdir\lib\"
    cp -r -force "lib\${libprefix}_dll\" "$outdir\lib\"
    cp -r -force "lib\${libprefix}_lib\" "$outdir\lib\"
    cp -r -force "include\" "$outdir\"
    "Done!"
    ""
}

