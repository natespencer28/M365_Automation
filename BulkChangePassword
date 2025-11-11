Defin<#
.SYNOPSIS
    Bulk update passwords for M365 / Entra ID users from a CSV.

.DESCRIPTION
    Expects a CSV with the following columns:
        UserPrincipalName,Password

    Example row:
        amurphy@nathanielmspencergmail.onmicrosoft.com,Xq7!vR9b#T2pLf8$

    Requires:
        - Microsoft.Graph.Users module
        - Connect-MgGraph with appropriate permissions (e.g. User.ReadWrite.All)

Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All", "Directory.AccessAsUser.All"

#Define the path to the CSV file
$csvFilePath = "c:\temp\m365usersPass.csv"
 
#Load the CSV data into a variable
$csvData = Import-Csv -Path $csvFilePath
 
#Define force password change after sign in
$ForceChangePasswordNextSignIn = "true"
 
#Loop through each user in the CSV data and update their password
foreach ($user in $csvData) {
    $userPrincipalName = $user.UserPrincipalName
    $userPassword = $user.Password
 
   # Check if the user exists
    $existingUser = Get-MgUser -UserId $userPrincipalName -ErrorAction SilentlyContinue
 
    if ($null -ne $existingUser) {
        try {
            $params = @{
                PasswordProfile = @{
                    password                      = $userPassword
                    ForceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn
                }
            }
            Update-MgUser -UserId $UserPrincipalName -BodyParameter $params -ErrorAction Stop
 
            Write-Host "Password updated for user: $userPrincipalName" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to update password for user: $userPrincipalName" $_.Exception.Message -ForegroundColor Red
        }
    }
    else {
        Write-Host "User not found: $userPrincipalName" -ForegroundColor Yellow
    }
}
