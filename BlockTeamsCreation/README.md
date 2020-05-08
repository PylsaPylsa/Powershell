# BlockTeamsCreation
This script will block the creation of Office 365 groups (and thus Teams) for all users except the security group you specify. Please create the Office 365 Security Group beforehand and enter it when asked after running the script.

## Requirements
- Existing Security group on tenant (AAD or AD synced both work)
- Global Administrator role on tenant
- [AzureAD Powershell module](https://docs.microsoft.com/en-us/office365/enterprise/powershell/connect-to-office-365-powershell):
  -  `Install-Module -Name AzureAD`