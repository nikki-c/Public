#########################------------Microsoft 365 Groups, Teams and Sites Summary Report -------------##########################
## Uses PnP PowerShell 
## Reports on Groups, Teams and Sites access permissions
## Site info = Title, Description, URL, Template, Owner, Sensitivity label, Site sharing, Conditional access, File sharing links, Sensitivity label name
## Group info = Group id, Privacy, Group Type, Group owners, Allowed to add guests, Guest count
##################################################################################################################################  

#Update the file path of where you want the file to be stored
$exportLocation = "C:\Temp\Groups_Sites_Report.csv"

#Config Variables
$orgName="<>YOURDOMAIN"
$tenantURL = "https://$orgName.sharepoint.com"

#Connect to PNP Powershell with admin permissions. You must use -Interactive if you account uses MFA
Connect-PnPOnline -URL $tenantURL -Interactive

#Group List
$GroupList = @()

#Get all sites and groups  
$sitesandGroups = Get-PnPTenantSite 

#Get just communications sites = SITEPAGEPUBLISHING#0
$sites = $sitesandGroups| Where -Property Template -In ("SITEPAGEPUBLISHING#0") | Select URL

#Number of communications sites
$TotalSites = $sites.Count

#Reset counter
$i= 0;

$sites | ForEach-Object {
    
    #Connect to each site
    Connect-PnPOnline  -Url $_.URL -Interactive
    
    #Update counter
    $i++;
    Write-Progress -activity "Processing non group connected Site  $($_.Url)" -status "$i out of $TotalSites completed"

    #For each site get site properties
    $Site = Get-PnPTenantSite -Identity $_.URL |Select-Object GroupId, Title, URL, Description, Template, Owner, SharingCapability, ConditionalAccessPolicy, DefaultLinkPermission, DefaultSharingLinkType, OwnerEmail, sensitivitylabel

    $GroupObject = [PSCustomObject]@{
        GroupGuid =$Site.GroupId
        DisplayName = $Site.Title
        Description =$Site.Description
        SiteURL = $_.URL
        SiteTemplate = $Site.Template
        SiteOwneremail = $Site.OwnerEmail
        SiteSharingCapability = $Site.SharingCapability
        SensitivityLabelId = $site.sensitivitylabel
        SiteType = If($Site.Template -eq "GROUP#0"){"Group"} elseif ($Site.Template -eq "TEAMCHANNEL#1" -or $Site.Template -eq "TEAMCHANNEL#0"){"Team Channel"} else {"Site"}
        GroupType = "None"
        ConditionalAccessPolicy = $Site.ConditionalAccessPolicy
        DefaultLinkPermission = If ($Site.DefaultLinkPermission-ne "None"){$Site.DefaultLinkPermission} Else {"Default"}
        DefaultSharingLinkType = If ($Site.DefaultSharingLinkType -ne "None"){$Site.DefaultSharingLinkType} Else {"Default"}
        GroupPrivacy = "N/A"
        GroupOwners = "N/A"
        AllowAddGuests = "N/A"
        GuestCount = "N/A"
    }
    $GroupList += $GroupObject
  }  

#Get groups and teams = GROUP#0 (Team channel sites can be ignored)
$Groups = $sitesandGroups | Where -Property Template -In ("GROUP#0") | Select URL, GroupId

#Number of group connected sites
$TotalGroups = $Groups.Count

#Reset counter
$i= 0;

$Groups | ForEach-Object {

    #Connect to each site
    Connect-PnPOnline  -Url $_.URL -Interactive

    #Update counter
    $i++;
    Write-Progress -activity "Processing group connected site $($_.Url)" -status "$i out of $TotalGroups completed"


    #For each site get site properties
    $Site = Get-PnPTenantSite -Identity $_.URL |Select-Object GroupId, Title, URL, Description, Template, Owner, SharingCapability, ConditionalAccessPolicy, DefaultLinkPermission, DefaultSharingLinkType, OwnerEmail, sensitivitylabel
    
    #Get group info
    $Group = Get-PnPMicrosoft365Group -Identity $_.GroupId -IncludeOwners |Select-Object GroupId, DisplayName, Description, Visibility, MembershipRule, Owners
    
    #Get group type (group, team, yammer)
    $GroupType = (Get-PnPMicrosoft365GroupEndpoint -Identity $_.GroupId).Providername 
    
    #Get external guest settings. Only returns if it has been explicitly set for the group. If blank then it inherits the tenant wide settings (default guests allowed)
    $groupSettings = Get-PnPMicrosoft365GroupSettings -Identity $_.GroupId
    $allowToAddGuests = $groupSettings.Values | Where-Object {$_.Name -eq 'AllowToAddGuests'}

    #Get guest user count
    $GuestCount = (Get-PnPMicrosoft365GroupMember -Identity $_.GroupId | Where-Object UserType -eq Guest).Count

    #Write group info to object
    $GroupObject = [PSCustomObject]@{
        GroupGuid =$Site.GroupId
        DisplayName = $Group.DisplayName
        Description =$Group.Description
        SiteURL = $_.URL
        SiteTemplate = $Site.Template
        SiteOwneremail = $Site.OwnerEmail
        SiteSharingCapability = $Site.SharingCapability
        SensitivityLabelId = $site.sensitivitylabel
        SiteType = If($Site.Template -eq "GROUP#0"){"Group"} elseif ($Site.Template -eq "TEAMCHANNEL#1" -or $Site.Template -eq "TEAMCHANNEL#0"){"Team Channel"} else {"Site"}
        GroupType = if($GroupType -like "Yammer"){"Yammer"} elseif($GroupType -like "Microsoft Teams"){"Team"} else {"Outlook Group"}     
        ConditionalAccessPolicy = $Site.ConditionalAccessPolicy
        DefaultLinkPermission = If ($Site.DefaultLinkPermission-ne "None"){$Site.DefaultLinkPermission} Else {"Default"}
        DefaultSharingLinkType = If ($Site.DefaultSharingLinkType -ne "None"){$Site.DefaultSharingLinkType} Else {"Default"}
        GroupPrivacy = $Group.Visibility
        GroupOwners = ($Group.Owners).Email -join '; '
        AllowAddGuests = If ($allowToAddGuests.Value -ne $null){$allowToAddGuests.Value} Else {"Default"}
        GuestCount = $GuestCount

	}
    $GroupList += $GroupObject  
}

#Create the output report
$GroupList | Export-CSV $exportLocation -NoTypeInformation

#Disconnect
Disconnect-PnPOnline
