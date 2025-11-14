
---

## 🧾 PowerShell script: `Check-BreakGlass-CAExclusion.ps1`

```powershell
<#
.SYNOPSIS
Checks that a specified Break Glass group is excluded from all Conditional Access policies.

.DESCRIPTION
This script:
1. Connects to Microsoft Graph with the required scopes.
2. Retrieves all Conditional Access policies.
3. Finds which policies have the Break Glass group in conditions.users.excludeGroups.
4. Compares counts and reports:
   - Whether the group is excluded from ALL policies.
   - Which policies are missing the exclusion.

.PARAMETER BreakGlassGroupId
The object ID (GUID) of the Break Glass group in Entra ID.

.EXAMPLE
.\Check-BreakGlass-CAExclusion.ps1 -BreakGlassGroupId "00000000-0000-0000-0000-000000000000"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BreakGlassGroupId
)

# ---------------------------
# Step 1 – Connect to Graph
# ---------------------------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

# Make sure the Microsoft.Graph module is installed:
# Install-Module Microsoft.Graph -Scope CurrentUser
Import-Module Microsoft.Graph -ErrorAction Stop

Connect-MgGraph -Scopes "Policy.Read.All","Directory.Read.All"
Select-MgProfile -Name beta

Write-Host "Connected to Microsoft Graph." -ForegroundColor Green

# --------------------------------------
# Step 2 – Get all Conditional Access policies
# --------------------------------------
Write-Host "Retrieving Conditional Access policies..." -ForegroundColor Cyan

$policies = Get-MgIdentityConditionalAccessPolicy -All

if (-not $policies) {
    Write-Host "No Conditional Access policies found." -ForegroundColor Yellow
    return
}

$allPolicyCount = $policies.Count
Write-Host "Total policies found: $allPolicyCount" -ForegroundColor Green

# -------------------------------------------------
# Step 3 – Find policies that exclude Break Glass
# -------------------------------------------------
Write-Host "Checking which policies exclude the Break Glass group ($BreakGlassGroupId)..." -ForegroundColor Cyan

$policiesWithExclusion = $policies | Where-Object {
    $_.conditions.users.excludeGroups -contains $BreakGlassGroupId
}

$excludedPolicyCount = $policiesWithExclusion.Count

Write-Host "Policies excluding Break Glass group: $excludedPolicyCount" -ForegroundColor Green

# -------------------------------------------------
# Step 4 – Compare & report compliance
# -------------------------------------------------
if ($allPolicyCount -eq $excludedPolicyCount) {
    Write-Host ""
    Write-Host "✅ Break Glass group is excluded from ALL Conditional Access policies." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Break Glass group is NOT excluded from all Conditional Access policies." -ForegroundColor Red
    Write-Host "The following policies are missing the Break Glass exclusion:" -ForegroundColor Yellow

    $nonCompliantPolicies = $policies | Where-Object {
        $_.conditions.users.excludeGroups -notcontains $BreakGlassGroupId
    }

    $nonCompliantPolicies |
        Select-Object Id, DisplayName |
        Format-Table -AutoSize
}

# Optional: output a simple object for CI/logging
[PSCustomObject]@{
    TotalPolicies                 = $allPolicyCount
    PoliciesExcludingBreakGlass   = $excludedPolicyCount
    FullyCompliant                = ($allPolicyCount -eq $excludedPolicyCount)
}
