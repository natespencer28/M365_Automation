<#
.SYNOPSIS
    Creates a new M365/Entra ID user based on (a "copy of") an existing user.

.DESCRIPTION
    Uses Microsoft Graph PowerShell SDK to:
      - Get a source/template user
      - Create a new cloud-only user with similar attributes
      - Optionally copy licenses
      - Optionally copy group memberships

.PARAMETER SourceUserPrincipalName
    UPN of the existing user to use as a template.

.PARAMETER NewUserPrincipalName
    UPN of the new user to create.

.PARAMETER Password
    Initial password for the new user.

.PARAMETER CopyLicenses
    If set, copies license assignments from the source user.

.PARAMETER CopyGroups
    If set, copies group membership from the source user.

.EXAMPLE
    .\New-MgClonedUserFromTemplate.ps1 `
        -SourceUserPrincipalName "template.user@contoso.com" `
        -NewUserPrincipalName "clone.user@contoso.com" `
        -Password "P@ssw0rd123!" `
        -CopyLicenses `
        -CopyGroups

.NOTES
    Requires Microsoft.Graph PowerShell module
    and appropriate Graph permissions:
        User.ReadWrite.All
        Directory.Read.All
        Group.ReadWrite.All
        Directory.ReadWrite.All (for license writes)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $SourceUserPrincipalName,

    [Parameter(Mandatory=$true)]
    [string] $NewUserPrincipalName,

    [Parameter(Mandatory=$true)]
    [string] $Password,

    [switch] $CopyLicenses,
    [switch] $CopyGroups
)

# 1. Connect to Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes `
    "User.ReadWrite.All", `
    "Directory.Read.All", `
    "Group.ReadWrite.All", `
    "Directory.ReadWrite.All"

Select-MgProfile -Name "v1.0"

# 2. Get source/template user
Write-Host "Getting source user: $SourceUserPrincipalName" -ForegroundColor Cyan
$sourceUser = Get-MgUser -UserId $SourceUserPrincipalName -Property `
    "id,displayName,givenName,surname,mailNickname,jobTitle,department,officeLocation,usageLocation,businessPhones,mobilePhone,city,state,country,postalCode,streetAddress"

if (-not $sourceUser) {
    throw "Source user '$SourceUserPrincipalName' not found."
}

# Basic pieces for new user
$givenName   = $sourceUser.GivenName
$surname     = $sourceUser.Surname
$displayName = "$($sourceUser.DisplayName) (Copy)"
$mailNickname = ($NewUserPrincipalName.Split("@")[0])

Write-Host "Creating new user: $NewUserPrincipalName" -ForegroundColor Yellow

# 3. Create new cloud-only user
$newUserParams = @{
    AccountEnabled    = $true
    DisplayName       = $displayName
    UserPrincipalName = $NewUserPrincipalName
    MailNickname      = $mailNickname
    GivenName         = $givenName
    Surname           = $surname
    JobTitle          = $sourceUser.JobTitle
    Department        = $sourceUser.Department
    OfficeLocation    = $sourceUser.OfficeLocation
    UsageLocation     = $sourceUser.UsageLocation
    City              = $sourceUser.City
    State             = $sourceUser.State
    Country           = $sourceUser.Country
    PostalCode        = $sourceUser.PostalCode
    StreetAddress     = $sourceUser.StreetAddress
    PasswordProfile   = @{
        ForceChangePasswordNextSignIn = $true
        Password                      = $Password
    }
}

$newUser = New-MgUser @newUserParams

Write-Host "New user created with Id: $($newUser.Id)" -ForegroundColor Green

# 4. Optionally copy licenses
if ($CopyLicenses) {
    Write-Host "Copying licenses from $SourceUserPrincipalName to $NewUserPrincipalName..." -ForegroundColor Cyan

    $licenseDetails = Get-MgUserLicenseDetail -UserId $sourceUser.Id
    $skuIds = $licenseDetails.SkuId

    if ($skuIds.Count -gt 0) {
        $assignParams = @{
            UserId                     = $newUser.Id
            AddLicenses                = @(
                @{ SkuId = $null } # will override below
            )
            RemoveLicenses             = @()
        }

        # Build AddLicenses array correctly
        $addLicenses = @()
        foreach ($sku in $skuIds) {
            $addLicenses += @{ SkuId = $sku }
        }
        $assignParams.AddLicenses = $addLicenses

        Set-MgUserLicense @assignParams | Out-Null

        Write-Host "Licenses copied." -ForegroundColor Green
    }
    else {
        Write-Host "Source user has no licenses to copy." -ForegroundColor Yellow
    }
}

# 5. Optionally copy group membership
if ($CopyGroups) {
    Write-Host "Copying group memberships..." -ForegroundColor Cyan

    $memberOf = Get-MgUserMemberOf -UserId $sourceUser.Id -All
    $groups = $memberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }

    foreach ($g in $groups) {
        $groupId = $g.Id
        try {
            Write-Host "Adding $NewUserPrincipalName to group: $($g.AdditionalProperties.displayName)" -ForegroundColor Yellow
            Add-MgGroupMember -GroupId $groupId -BodyParameter @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($newUser.Id)"
            }
        }
        catch {
            Write-Warning "Failed to add to group $($groupId): $($_.Exception.Message)"
        }
    }

    Write-Host "Group membership copy complete." -ForegroundColor Green
}

Write-Host "Done. New user '$NewUserPrincipalName' created based on '$SourceUserPrincipalName'." -ForegroundColor Green
