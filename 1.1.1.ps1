<#
.SYNOPSIS
    Tests CIS Control 1.1.1: Ensure Administrative accounts are cloud-only.

.DESCRIPTION
    Connects to Microsoft Graph, enumerates privileged directory roles, 
    and identifies which admin accounts are:
    
      - Hybrid-synced from on-prem

    Any admin accounts that are directory-synced are NON-COMPLIANT with CIS 1.1.1.

.NOTES
    Author: Nate Spencer (or your preferred name)
    Control: CIS 1.1.1
#>

1. Connect to Microsoft Graph using Connect-MgGraph -Scopes 
"RoleManagement.Read.Directory","User.Read.All" 

2. Run the following PowerShell script: 
$DirectoryRoles = Get-MgDirectoryRole 
# Get privileged role IDs 
$PrivilegedRoles = $DirectoryRoles | Where-Object { 
$_.DisplayName -like "*Administrator*" -or $_.DisplayName -eq "Global 
Reader" 
} 
# Get the members of these various roles 
$RoleMembers = $PrivilegedRoles | ForEach-Object { Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id } | 
Select-Object Id -Unique 
# Retrieve details about the members in these roles 
$PrivilegedUsers = $RoleMembers | ForEach-Object { 
Get-MgUser -UserId $_.Id -Property UserPrincipalName, DisplayName, Id, 
OnPremisesSyncEnabled 
} 
$PrivilegedUsers | Where-Object { $_.OnPremisesSyncEnabled -eq $true } |  
ft DisplayName,UserPrincipalName,OnPremisesSyncEnabled 
3. The script will output any hybrid users that are also members of privileged roles. 
If nothing returns, then no users with that criteria exist. 
