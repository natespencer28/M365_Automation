# Determine Id of GA role using the immutable RoleTemplateId value. 
$GlobalAdminRole = Get-MgDirectoryRole -Filter "RoleTemplateId eq '62e90394
69f5-4237-9190-012177145e10'" 
$RoleMembers = Get-MgDirectoryRoleMember -DirectoryRoleId $GlobalAdminRole.Id 
 
$GlobalAdmins = [System.Collections.Generic.List[Object]]::new() 
foreach ($object in $RoleMembers) { 
    $Type = $object.AdditionalProperties.'@odata.type' 
    # Check for and process role assigned groups 
    if ($Type -eq '#microsoft.graph.group') { 
        $GroupId = $object.Id 
        $GroupMembers = (Get-MgGroupMember -GroupId 
$GroupId).AdditionalProperties 
 
        foreach ($member in $GroupMembers) { 
            if ($member.'@odata.type' -eq '#microsoft.graph.user') { 
                $GlobalAdmins.Add([PSCustomObject][Ordered]@{ 
                        DisplayName       = $member.displayName 
                        UserPrincipalName = $member.userPrincipalName 
                    }) 
            }  
        } 
    } elseif ($Type -eq '#microsoft.graph.user') { 
        $DisplayName = $object.AdditionalProperties.displayName 
        $UPN = $object.AdditionalProperties.userPrincipalName 
        $GlobalAdmins.Add([PSCustomObject][Ordered]@{ 
                DisplayName       = $DisplayName 
                UserPrincipalName = $UPN 
            }) 
    }  
} 
 
$GlobalAdmins = $GlobalAdmins | select DisplayName,UserPrincipalName -Unique  
Write-Host "*** There are" $GlobalAdmins.Count "Global Administrators in the 
organization." 
