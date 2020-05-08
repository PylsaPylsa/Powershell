# Push ManageEngine Patch Manager Plus Agent
Wrapper for PsExec to push the ManageEngine Patch Manager Plus agent to all Windows Servers on the domain. Due to licence restrictions, please download and add PsExec yourself from the Microsoft Download Center.

## Prerequisites
- Domain admin account or account that has sufficient administrative priviliges to do the install.
- Agent installer from ManageEngine Patch Manager Plus Portal. This script uses the .exe agent.

## Instructions
1. Place **PushAgent.ps1** in an empty directory that is on a server that is domain joined (e.g. management server or domain controller).
2. Download [PsExec from Microsoft](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) and put **PsExec64.exe** directory used in step 1.
3. In the same directory, create a new directory named **ManageEnginePMA** and copy your agent installed into it.
4. Edit **PushAgent.ps1**:
   -  The value of **$Organisatie** has to match the first part of the installer's name (e.g for Contoso_Agent.exe use value "Contoso").
   -  The value of **$Sysvolpath** has to match the full UNC SYSVOL location of the domain you're installing to (e.g. "\\contoso.local\SYSVOL\contoso.local"). We use SYSVOL because every server on the domain automatically has access to this share by default.
5. Save **PushAgent.ps1**.
6. Right click **PushAgent.ps1** and execute using Powershell.
7. The script will copy all necessary files to SYSVOL. If these already exist there, you will be prompted to purge or reuse the existing files.
8. The script will locate all domain-joined Windows Server based hosts in Active Directory and will ask to confirm the discovered list.
   - For environments with multiple domain controllers, please allow some time for SYSVOL replication to take place before continuing with the push.
   - Servers that have _\*xa*_ in their hostname will be added to the list of servers to skip as these are provisioned Citrix servers in our environments. Feel free to modify this filter as you see fit for your own nomenclature.
9. The script will now start pushing the agent to all servers. Wait for completion.
10. After pushing has finished, you will be prompted to purge the fils created in SYSVOL. You can accept this if you do not intend to used them again so your SYSVOL will stay nice and clean.
11. PsExec does **not work** for the server it is run from. Please install the agent on that server manually.