<#
.SYNOPSIS
    Tests CIS Control 1.1.1: Ensure Administrative accounts are cloud-only.

.DESCRIPTION
    Connects to Microsoft Graph, enumerates privileged directory roles, 
    and identifies which admin accounts are:
      - Cloud-only
      - Hybrid-synced from on-prem

    Any admin accounts that are directory-synced are NON-COMPLIANT with CIS 1.1.1.

.NOTES
    Author: Nate Spencer (or your preferred name)
    Control: CIS 1.1.1
#>

param(
    [string[]] $AdminRolesToCheck = @(
        "Global Administrator",
        "Privileged Role Administrator",
        "Security Administrator",
        "Exchange Administrator",
        "SharePoint Administrator",
        "Teams Administrator",
        "User Administrator",
        "Helpdesk Administrator",
        "Conditional Access Administrator"
    ),
    [string] $ExportPath = ".\CIS_1.1.1_AdminAccounts.csv"
)

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Directory.Read.All"
Select-MgProfile -Name "beta"  # or v1.0 if preferred, OnPrem props still work

Write-Host "Retrieving directory roles..." -ForegroundColor Cyan
$allRoles = Get-MgDirectoryRole -All
$targetRoles = $allRoles | Where-Object { $_.DisplayName -in $AdminRolesToCheck }

if (-not $targetRoles) {
    Write-Warning "No matching directory roles found. Check your role names."
    return
}

$result = @()

foreach ($role in $targetRoles) {
    Write-Host "Processing role: $($role.DisplayName)" -ForegroundColor Yellow

    # Get all members of this directory role
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All

    foreach ($member in $members) {
        # We only care about user objects (skip service principals, groups, etc.)
        if ($member.'@odata.type' -eq "#microsoft.graph.user") {
            $user = Get-MgUser -UserId $member.Id -Property `
                "id,displayName,userPrincipalName,onPremisesSyncEnabled,onPremisesImmutableId,userType"

            $isHybrid = $false
            if ($user.OnPremisesSyncEnabled -eq $true -or
                -not [string]::IsNullOrEmpty($user.OnPremisesImmutableId)) {
                $isHybrid = $true
            }

            $result += [pscustomobject]@{
                RoleName               = $role.DisplayName
                DisplayName            = $user.DisplayName
                UserPrincipalName      = $user.UserPrincipalName
                OnPremisesSyncEnabled  = $user.OnPremisesSyncEnabled
                OnPremisesImmutableId  = $user.OnPremisesImmutableId
                UserType               = $user.UserType
                IsCloudOnly            = -not $isHybrid
                IsHybridSynced        = $isHybrid
            }
        }
    }
}

if (-not $result) {
    Write-Warning "No admin users found in the specified roles."
    return
}

Write-Host ""
Write-Host "===== CIS 1.1.1 – Admin Account Summary =====" -ForegroundColor Cyan

# All admin accounts
$result | Sort-Object RoleName, UserPrincipalName | Format-Table `
    RoleName, DisplayName, UserPrincipalName, IsCloudOnly, IsHybridSynced

Write-Host ""
Write-Host "===== NON-COMPLIANT (Hybrid-Synced Admin Accounts) =====" -ForegroundColor Red

$nonCompliant = $result | Where-Object { $_.IsHybridSynced -eq $true }

if ($nonCompliant) {
    $nonCompliant | Sort-Object RoleName, UserPrincipalName | Format-Table `
        RoleName, DisplayName, UserPrincipalName, OnPremisesSyncEnabled, OnPremisesImmutableId
} else {
    Write-Host "✅ No hybrid-synced admin accounts found. CIS 1.1.1 PASSED." -ForegroundColor Green
}

Write-Host ""
Write-Host "Exporting results to: $ExportPath" -ForegroundColor Cyan
$result | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8

Write-Host "Done." -ForegroundColor Green
