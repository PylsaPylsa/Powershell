# PushAgent
Wrapper voor PsExec om ManageEngine Patch Manager Plus agent te pushen naar alle Windows Servers op het domein. Vanwege de licentievoorwaarden dient PsExec los te worden gedownload vanaf het Microsoft Download Center.

##Instructies
1. PushAgent.ps1 in map plaatsen.
2. Download [PsExec van Microsoft](https://docs.microsoft.com/en-us/sysinternals/downloads/psexec) en plaats PsExec64.exe in dezelfde map.
3. Maak een nieuwe map aan met de naam ManageEnginePMA in dezelfde map en plaats hierin de Agent-installer.
4. PushAgent.ps1 met kladblok of ISE openen en de volgende zaken aanpassen:
   -  De waarde van $Organisatie in het eerste deel van de titel van de installer (Voor Contoso_Agent.exe dus "Contoso").
   -  De waarde van $Sysvolpath moet de SYSVOL van het domein zijn.
5. PushAgent.ps1 opslaan
6. Rechtsklikken op PushAgent.ps1 en uitvoeren met Powershell.
7. Het script kopieert de bestanden voor de installatie naar SYSVOL. Als deze al bestaan wordt gevraagd om door te gaan met de bestaande bestanden in SYSVOL of om ze opnieuw te laten plaatsen door het script. Als deze nog niet bestaan zal het script deze aanmaken.
8. Het script zoekt naar Windows Servers in de Active Directory en vraagt bevestiging om de installatie te starten naar de servers die worden getoond. 
   - Voor omgevingen met meerdere Domain Controllers op meerdere locaties kan het even duren voordat alles is gerepliceerd naar de lokale SYSVOL. Wacht in dat geval tot de replicatie voltooid is voordat je de installatie accepteert en aftrapt.
9. Het script pusht nu de agent naar alle servers. Wacht tot deze is voltooid.
10. Aan het einde wordt gevraagd of je de installatiebestanden in SYSVOL wil opruimen. Doe dit als je deze niet meer wil gebruiken.
11. Het script werkt NIET voor de server vanaf waar het wordt gedraaid. Voer de installer op deze server handmatig uit en doorloop de stappen.