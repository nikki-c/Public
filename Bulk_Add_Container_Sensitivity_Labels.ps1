######################################################################################################
# Bulk update container sensitivity label to Sharepoint sites based on CSV input
# If the site has a Microsoft 365 Group behind it, the label will be placed on the Microsoft 365 Group
# CSV format: 2 columns URL, LabelID. Note must use the sensitivyt label guid
# Use PnP PowerShell. Requires V7 PowerShell
# Last updated 23 April 2023
######################################################################################################

#If required Install and register PnP PowerShell
Install-Module PnP.PowerShell
Import-Module PnP.PowerShell
Register-PnPManagementShellAccess

$orgName="<YOUR TENANT NAME>" 
$tenantURL = "https://$orgName.sharepoint.com"

$csvfile = "<CSV FILE PATH>"
$ExportLocation = "<CSV FILE PATH>"

#Connect to PnP PowerShell
Connect-PnPOnline -Url $tenantURL -Interactive

#Import CSV file
$sites = Import-CSV -path $csvfile  

# List
$List = @()

#For each site in the CSV
ForEach ($site in $sites) {
 
    #Get Parameters from CSV
    $SiteURL = $site.URL
    $LabelId = $site.LabelID  

    #Add sensitivity Label to site
    Set-PnPTenantSite -Identity $SiteURL -SensitivityLabel $LabelId 

    $label = Get-PnPSiteSensitivityLabel

    $Object = [PSCustomObject]@{
        URL = $site.URL
        Sensitivitylabel= $label.DisplayName
        }
    $List += $Object

    }

#Create the output report
$List | Export-CSV $exportLocation -NoTypeInformation

#Disconnect
Disconnect-PnPOnline
