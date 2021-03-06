﻿param(
    $buildVersion = $null,

    # QA params
    $QA_FIX = $null
)

$dirPath = $BuildRoot

$gemFolder = "vagrant-uplift"

. "$dirPath/.build-helpers.ps1"

$buildFolder = "build-gem"
$buildOutput = "build-output"

$srcFolder = "$dirPath/$gemFolder"

New-Folder   $buildFolder
New-Folder   $buildOutput

Enter-Build {
    Write-Build Green "Building gem..."

    Remove-Item  "$buildFolder/*" -Force -Recurse
    Remove-Item  "$buildOutput/*" -Force -Recurse
}

task PrepareGem {

    Invoke-CleanFolder $buildFolder

    Copy-Item "$srcFolder/*" "$buildFolder/" -Recurse -Force
    Remove-Item  "$buildFolder/*.gem" -Force
}

task VersionGem {
    $dateStamp = [System.DateTime]::UtcNow.ToString("yyyyMMdd")
    $timeStamp = [System.DateTime]::UtcNow.ToString("HHmmss")

    $stamp = "$dateStamp.$timeStamp"

    # repace 0 for 24 hours
    $stamp = $stamp.Replace(".000", ".")
    $stamp = $stamp.Replace(".00", ".")
    $stamp = $stamp.Replace(".0", ".")

    $script:Version = "0.1.$stamp"

    if($null -ne $env:APPVEYOR_REPO_BRANCH) {
        Write-Build Green " [~] Running under APPVEYOR branch: $($env:APPVEYOR_REPO_BRANCH)"

        if($env:APPVEYOR_REPO_BRANCH -ine "beta" -and $env:APPVEYOR_REPO_BRANCH -ine "master") {
            Write-Build Green " skipping APPVEYOR versioning for branch: $($env:APPVEYOR_REPO_BRANCH)"
        } else {
            Write-Build Green " using APPVEYOR versioning for branch: $($env:APPVEYOR_REPO_BRANCH)"

            ## 1902.build-no
            $stamp = [System.DateTime]::UtcNow.ToString("yyMM")
            $buildNumber = $env:APPVEYOR_BUILD_NUMBER;

            $script:Version = "0.2.$stamp.$buildNumber"
        }
    } 

    if ($null -ne $buildVersion ) {
        Write-Build Yellow " [+] Using version from params: $buildVersion"
        $script:Version = $buildVersion
    }

    $versionedFiles = @( 
        "$buildFolder/lib/vagrant-uplift/version.rb",
        "$buildFolder/vagrant-uplift.gemspec",
        "$buildFolder/lib/vagrant-uplift/config_builder.rb"
    )

    Write-Build Green " [~] Patching version: $($script:Version)"
    foreach($versionedFile in $versionedFiles) {
        Write-Build Green " - file: $versionedFile"
        Edit-ValueInFile $versionedFile '0.1.0' $script:Version
    }
}

task BuildGem {
    Write-Build Green "Building gems..."

    exec {
        Set-Location "$buildFolder"
        pwsh -c "gem build *.gemspec"
    }
}

task CopyGem {
    Write-Build Green "Copying to build folder..."
    exec {
        $gemFile = Get-ChildItem "$buildFolder" -Filter "*.gem" `
            | Select-Object -First 1

        Write-Build Green "Found gem: $gemFile"

        Copy-Item $gemFile.FullName "$buildOutput/latest.gem" -Force
        Copy-Item $gemFile.FullName "$buildOutput/" -Force
    }
}

task InstallGem {

    exec {
        Write-Build Green "Uninstalling gem..."
        vagrant plugin uninstall vagrant-uplift

        $path = "$buildOutput/latest.gem"

        Write-Build Green "Installing latest gem"
        Write-Build Green " - src: $path"

        vagrant plugin install "$path"
        Confirm-ExitCode $LASTEXITCODE  "vagrant plugin install $dirPath/build/latest.gem"
    }
}

task ShowVagrantPlugins {

    exec {
        vagrant plugin list
    }
}

task PublishGem {

    Write-Build Green "Publishing gems..."

    if($null -ne $env:APPVEYOR_REPO_BRANCH) {
        Write-Build Green " [~] Running under APPVEYOR branch: $($env:APPVEYOR_REPO_BRANCH)"

        # if($env:APPVEYOR_REPO_BRANCH -ine "beta" -and $env:APPVEYOR_REPO_BRANCH -ine "master") {

        # publishing to https://rubygems.org/gems/vagrant-uplift on master branch only
        # non-master branch artefacts can be downloaded from appveyor/builds/artifacts tab
        if($env:APPVEYOR_REPO_BRANCH -ine "master") {
            Write-Build Green " skipping publishing for branch: $($env:APPVEYOR_REPO_BRANCH)"
            return;
        }

        $apiKeyFile = "~/.gem/credentials"

        $apiKeyEnvName = ("SPS_RUBYGEMS_API_KEY_" + $env:APPVEYOR_REPO_BRANCH)
        $apiKeyValue   = (get-item env:$apiKeyEnvName).Value;

        "---" >  $apiKeyFile
        ":rubygems_api_key: $apiKeyValue" >>  $apiKeyFile
    }

    exec {
        Write-Build Green "gem push latest.gem"
        Set-Location "$buildOutput"
        pwsh -c "gem push latest.gem"
    }
}

# Synopsis: Runs PSScriptAnalyzer
task AnalyzeModule {
    exec {
        # https://github.com/PowerShell/PSScriptAnalyzer

        #$packerScriptsPath  = "packer/scripts"
        $folderPaths = Get-ChildItem . -Recurse `
            | ? { $_.PSIsContainer } `
            | Select-Object FullName -ExpandProperty FullName

        foreach ($folderPath in $folderPaths) {

            $filePaths = (Get-ChildItem -Path $folderPath -Filter *.ps1)

            foreach ($filePathContainer in $filePaths) {
                $filePath = $filePathContainer.FullName
                
                if ($filePath.Contains(".dsc.ps1") -eq $True -and $IsMacOS) {
                    Write-Build Yellow " - skipping DSC validation under macOS"

                    Write-Build Green " - file   : $filePath"
                    Write-Build Green " - QA_FIX : $QA_FIX"

                    Write-Build Green  " - https://github.com/PowerShell/PowerShell/issues/5707"
                    Write-Build Green  " - https://github.com/PowerShell/PowerShell/issues/5970"
                    Write-Build Green  " - https://github.com/PowerShell/MMI/issues/33"

                    continue;
                }

                if ($filePath.Contains(".Tests.ps1") -eq $True -and $IsMacOS) {
                    Write-Build Yellow " - skipping valiation for Pester test files"

                    Write-Build Green " - file   : $filePath"
                    Write-Build Green " - QA_FIX : $QA_FIX"

                    continue;
                }
              
                Write-Build Green " - file   : $filePath"
                Write-Build Green " - QA_FIX : $QA_FIX"

                if ($psFilesCount -eq 0) {
                    continue;
                }

                if ($null -eq $QA_FIX) {
                    pwsh -c Invoke-ScriptAnalyzer -Path $filePath -EnableExit -ReportSummary
                    Confirm-ExitCode $LASTEXITCODE "[~] failed!"
                }
                else {
                    pwsh -c Invoke-ScriptAnalyzer -Path $filePath -EnableExit -ReportSummary -Fix
                }
            }
        }
    }
}

# Synopsis: Executes Appveyor specific setup
task AppveyorPrepare {
    Write-Build Green "ruby -v"
    ruby -v

    Write-Build Green "gem -v"
    gem -v

    Write-Build Green "bundle -v"
    bundle  -v
}

task QA AnalyzeModule

task DefaultBuildGem PrepareGem,
    VersionGem,
    BuildGem,
    CopyGem

task DefaultBuild DefaultBuildGem,
    ShowVagrantPlugins,
    InstallGem,
    ShowVagrantPlugins

task . DefaultBuild

task Release QA, DefaultBuild, PublishGem

task Appveyor AppveyorPrepare,
    DefaultBuildGem,
    PublishGem