[CmdletBinding()]
param(
    [string] $SharePointCmdletModule = (Join-Path $PSScriptRoot "..\Stubs\SharePoint\15.0.4693.1000\Microsoft.SharePoint.PowerShell.psm1" -Resolve)
)

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..\..).Path
$Global:CurrentSharePointStubModule = $SharePointCmdletModule 

$ModuleName = "MSFT_xSPSearchRoles"
Import-Module (Join-Path $RepoRoot "Modules\xSharePoint\DSCResources\$ModuleName\$ModuleName.psm1")

Describe "xSPSearchRoles" {
    InModuleScope $ModuleName {
        $testParams = @{
            ServiceAppName = "Search Service Application"
            Admin = $true
            Crawler = $true
            ContentProcessing = $true
            AnalyticsProcessing = $true
            QueryProcessing = $true
            Ensure = "Present"
            FirstPartitionIndex = "0"
            FirstPartitionDirectory = "C:\ExamplePath"
            FirstPartitionServers = $env:COMPUTERNAME
        }
        Import-Module (Join-Path ((Resolve-Path $PSScriptRoot\..\..).Path) "Modules\xSharePoint")
        Import-Module $Global:CurrentSharePointStubModule -WarningAction SilentlyContinue 

        Mock Invoke-xSharePointCommand { 
            return Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $Arguments -NoNewScope
        }
        Mock New-PSSession {
            return $null
        }
        Mock New-Item { return @{} }
        Mock Get-SPEnterpriseSearchServiceInstance  {
            return @{
                Server = @{
                    Address = $env:COMPUTERNAME
                }
                Status = "Online"
            }
        }
        Mock Get-SPEnterpriseSearchServiceApplication {
            return @{
                ActiveTopology = @{}
            }
        }

        Add-Type -TypeDefinition "public class AdminComponent { public string ServerName { get; set; } public System.Guid ComponentId {get; set;}}"
        Add-Type -TypeDefinition "public class CrawlComponent { public string ServerName { get; set; } public System.Guid ComponentId {get; set;}}"
        Add-Type -TypeDefinition "public class ContentProcessingComponent { public string ServerName { get; set; } public System.Guid ComponentId {get; set;}}"
        Add-Type -TypeDefinition "public class AnalyticsProcessingComponent { public string ServerName { get; set; } public System.Guid ComponentId {get; set;}}"
        Add-Type -TypeDefinition "public class QueryProcessingComponent { public string ServerName { get; set; } public System.Guid ComponentId {get; set;}}"

        $adminComponent = New-Object AdminComponent
        $adminComponent.ServerName = $env:COMPUTERNAME
        $adminComponent.ComponentId = [Guid]::NewGuid()

        $crawlComponent = New-Object CrawlComponent
        $crawlComponent.ServerName = $env:COMPUTERNAME
        $crawlComponent.ComponentId = [Guid]::NewGuid()

        $contentProcessingComponent = New-Object ContentProcessingComponent
        $contentProcessingComponent.ServerName = $env:COMPUTERNAME
        $contentProcessingComponent.ComponentId = [Guid]::NewGuid()

        $analyticsProcessingComponent = New-Object AnalyticsProcessingComponent
        $analyticsProcessingComponent.ServerName = $env:COMPUTERNAME
        $analyticsProcessingComponent.ComponentId = [Guid]::NewGuid()

        $queryProcessingComponent = New-Object QueryProcessingComponent
        $queryProcessingComponent.ServerName = $env:COMPUTERNAME
        $queryProcessingComponent.ComponentId = [Guid]::NewGuid()

        Mock Start-SPEnterpriseSearchServiceInstance { return $null }
        Mock New-SPEnterpriseSearchTopology { return @{} }
        Mock New-SPEnterpriseSearchAdminComponent { return @{} }
        Mock New-SPEnterpriseSearchCrawlComponent { return @{} }
        Mock New-SPEnterpriseSearchContentProcessingComponent { return @{} }
        Mock New-SPEnterpriseSearchAnalyticsProcessingComponent { return @{} }
        Mock New-SPEnterpriseSearchQueryProcessingComponent { return @{} }        
        Mock New-SPEnterpriseSearchIndexComponent { return @{} }
        Mock Set-SPEnterpriseSearchTopology { return @{} }
        Mock Remove-SPEnterpriseSearchComponent { return $null }

        Context "No search topology has been applied" {
            Mock Get-SPEnterpriseSearchComponent {
                return @{}
            }

            It "returns false values from the get method" {
                $result = Get-TargetResource @testParams
                $result.Admin | Should Be $false
                $result.Crawler | Should Be $false
                $result.ContentProcessing | Should Be $false
                $result.AnalyticsProcessing | Should Be $false
                $result.QueryProcessing | Should Be $false
            }

            It "returns false from the test method" {
                Test-TargetResource @testParams | Should Be $false
            }

            It "sets the desired topology for the current server" {
                Set-TargetResource @testParams
            }
        }

        Context "No search topology exist and the search service instance isnt running" {
            Mock Get-SPEnterpriseSearchComponent {
                return @{}
            }
            $Global:xSharePointSearchRoleInstanceCalLCount = 0
            Mock Get-SPEnterpriseSearchServiceInstance  {
                if ($Global:xSharePointSearchRoleInstanceCalLCount -eq 2) {
                    $Global:xSharePointSearchRoleInstanceCalLCount = 0
                    return @{
                        Status = "Online"
                    }
                } else {
                    $Global:xSharePointSearchRoleInstanceCalLCount++
                    return @{
                        Status = "Offline"
                    }
                }
            }

            It "sets the desired topology for the current server and starts the search service instance" {
                Set-TargetResource @testParams
                Assert-MockCalled Start-SPEnterpriseSearchServiceInstance
            }

        }

        Context "A search topology has been applied but it is not correct" {

            Mock Get-SPEnterpriseSearchServiceInstance  {
                return @{
                    Server = @{
                        Address = $env:COMPUTERNAME
                    }
                    Status = "Online"
                }
            }
        
            It "adds a missing admin component" {
                Mock Get-SPEnterpriseSearchComponent {
                    return @($crawlComponent, $contentProcessingComponent, $analyticsProcessingComponent, $queryProcessingComponent)
                }
                Set-TargetResource @testParams
                Assert-MockCalled New-SPEnterpriseSearchAdminComponent
            }

            It "adds a missing crawl component" {
                Mock Get-SPEnterpriseSearchComponent {
                    return @($adminComponent, $contentProcessingComponent, $analyticsProcessingComponent, $queryProcessingComponent)
                }
                Set-TargetResource @testParams
                Assert-MockCalled New-SPEnterpriseSearchCrawlComponent
            }

            It "adds a missing content processing component" {
                Mock Get-SPEnterpriseSearchComponent {
                    return @($adminComponent, $crawlComponent, $analyticsProcessingComponent, $queryProcessingComponent)
                }
                Set-TargetResource @testParams
                Assert-MockCalled New-SPEnterpriseSearchContentProcessingComponent
            }

            It "adds a missing analytics processing component" {
                Mock Get-SPEnterpriseSearchComponent {
                    return @($adminComponent, $crawlComponent, $contentProcessingComponent, $queryProcessingComponent)
                }
                Set-TargetResource @testParams
                Assert-MockCalled New-SPEnterpriseSearchAnalyticsProcessingComponent
            }

            It "adds a missing query processing component" {
                Mock Get-SPEnterpriseSearchComponent {
                    return @($adminComponent, $crawlComponent, $contentProcessingComponent, $analyticsProcessingComponent)
                }
                Set-TargetResource @testParams
                Assert-MockCalled New-SPEnterpriseSearchQueryProcessingComponent
            }

            $testParams = @{
                ServiceAppName = "Search Service Application"
                Admin = $false
                Crawler = $false
                ContentProcessing = $false
                AnalyticsProcessing = $false
                QueryProcessing = $false
                Ensure = "Absent"
                FirstPartitionIndex = "0"
                FirstPartitionDirectory = "C:\ExamplePath"
                FirstPartitionServers = $env:COMPUTERNAME
            }
            
            Mock Get-SPEnterpriseSearchComponent {
                return @($adminComponent, $crawlComponent, $contentProcessingComponent, $analyticsProcessingComponent, $queryProcessingComponent)
            }

            It "Removes components that shouldn't be on this server" {
                Set-TargetResource @testParams
                Assert-MockCalled Remove-SPEnterpriseSearchComponent -Times 5
            }

            
        }

        Context "The correct topology on this server exists" {
            Mock Get-SPEnterpriseSearchComponent {
                return @($adminComponent, $crawlComponent, $contentProcessingComponent, $analyticsProcessingComponent, $queryProcessingComponent)
            }

            Mock Get-SPEnterpriseSearchServiceInstance  {
                return @{
                    Server = @{
                        Address = $env:COMPUTERNAME
                    }
                    Status = "Online"
                }
            }

            $testParams = @{
                ServiceAppName = "Search Service Application"
                Admin = $true
                Crawler = $true
                ContentProcessing = $true
                AnalyticsProcessing = $true
                QueryProcessing = $true
                Ensure = "Present"
                FirstPartitionIndex = "0"
                FirstPartitionDirectory = "C:\ExamplePath"
                FirstPartitionServers = $env:COMPUTERNAME
            }

            It "returns true from the test method" {
                Test-TargetResource @testParams -Verbose | Should Be $true
            }
        }
    }
}