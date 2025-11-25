
$Caps = Get-MgIdentityConditionalAccessPolicy -All | 
    Where-Object { 
$_.SessionControls.ApplicationEnforcedRestrictions.IsEnabled } 
$CapReport = [System.Collections.Generic.List[Object]]::new()     
# Filter to policies with "Use app enforced restrictions" enabled 
 
# Loop through policies and generate a per policy report. 
foreach ($policy in $Caps) { 
    $Name = $policy.DisplayName 
    $Users = $policy.Conditions.Users.IncludeUsers 
    $Targets = $policy.Conditions.Applications.IncludeApplications 
    $ClientApps = $policy.Conditions.ClientAppTypes 
    $Restrictions = 
$policy.SessionControls.ApplicationEnforcedRestrictions.IsEnabled 
    $State = $policy.State 
 
    $CountPass = $Targets.count -eq 1 -and $ClientApps.count -eq 1 
    $Pass = $Targets -eq 'Office365' -and $ClientApps -eq 'browser' -and 
            $Restrictions -and $CountPass -and $State -eq 'enabled' 
 
    $obj = [PSCustomObject]@{ 
        DisplayName             = $Name 
        AuditState              = if ($Pass) { "PASS" } else { "FAIL" } 
        IncludeUsers            = $Users 
        IncludeApplications     = $Targets 
        ClientAppTypes          = $ClientApps 
        AppEnforcedRestrictions = $Restrictions 
        State                   = $State 
    } 
    $CapReport.Add($obj) 
} 
 
if ($Caps) { 
    $CapReport 
} else { 
    Write-Host "** FAIL **: There are no qualifying conditional access 
policies." 
} 
