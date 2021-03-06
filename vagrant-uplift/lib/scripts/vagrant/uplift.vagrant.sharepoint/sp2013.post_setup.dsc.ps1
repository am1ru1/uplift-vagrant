# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Running SharePoint post-setup tuning"
Write-UpliftEnv

Configuration Install_SharePointFarmTuning
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion "1.9.0.0"
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion "1.19.0.0" 
    
    Node localhost {

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $false
        }

        Service SharePointAdministration {
            Ensure = "Present"
            Name = "SPAdminV4"
            StartupType = "Automatic"
            State = "Running"
        }

        Service SharePointSearchHostController {
            Ensure = "Present"
            Name = "SPSearchHostController"
            StartupType = "Automatic"
            State = "Running"
        }

        Service SharePointServerSearch15 {
            Ensure = "Present"
            Name = "OSearch15"
            StartupType = "Automatic"
            State = "Running"
        }

        Service SharePointTimerService {
            Ensure = "Present"
            Name = "SPTimerV4"
            StartupType = "Automatic"
            State = "Running"
        }

        Service SharePointTracingService {
            Ensure = "Present"
            Name = "SPTraceV4"
            StartupType = "Automatic"
            State = "Running"
        }

        Service SharePointUserCodeHost {
            Ensure = "Present"
            Name = "SPUserCodeV4"
            StartupType = "Automatic"
            State = "Running"
        }

        xWebsite SharePointCentralAdministrationv4 {
            Ensure = "Present"
            Name="SharePoint Central Administration v4"
            State = "Started"
        }

        xWebsite SharePointWebServices {
            Ensure = "Present"
            Name="SharePoint Web Services"
            State = "Started"
        }

        xWebAppPool SecurityTokenServiceApplicationPool { 
            Ensure = "Present"
            Name="SecurityTokenServiceApplicationPool"
            State = "Started"
        }

        xWebAppPool SharePointCentralAdministrationv4AppPool { 
            Ensure = "Present"
            Name="SharePoint Central Administration v4"
            State = "Started"
        }

        xWebAppPool SharePointWebServicesRootAppPool { 
            Ensure = "Present"
            Name="SharePoint Web Services Root"
            State = "Started"
        }

     }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'

            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true

            RetryCount = 10           
            RetryIntervalSec = 30
        }
    )
}

$configuration = Get-Command Install_SharePointFarmTuning
Start-UpliftDSCConfiguration $configuration $config 

exit 0
