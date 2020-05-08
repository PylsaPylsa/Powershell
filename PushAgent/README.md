1. Bestand op een managementserver plaatsen en uitpakken. (Dit heb je al gedaan, goed zo!)
2. In de uitgepakte map ManageEnginePMA de Agent-installer zetten.
3. PushAgent.ps1 met kladblok of ISE openen en de volgende zaken aanpassen:
   -  De waarde van $Organisatie in het eerste deel van de titel van de installer (Voor Contoso_Agent.exe dus "Contoso").
   -  De waarde van $Sysvolpath moet de SYSVOL van het domein zijn.
4. PushAgent.ps1 opslaan
5. Rechtsklikken op PushAgent.ps1 en uitvoeren met Powershell.
6. Het script kopieert de bestanden voor de installatie naar SYSVOL. Als deze al bestaan wordt gevraagd om door te gaan met de bestaande bestanden in SYSVOL of om ze opnieuw te laten plaatsen door het script. Als deze nog niet bestaan zal het script deze aanmaken.
7. Het script zoekt naar Windows Servers in de Active Directory en vraagt bevestiging om de installatie te starten naar de servers die worden getoond. 
   - Voor omgevingen met meerdere Domain Controllers op meerdere locaties kan het even duren voordat alles is gerepliceerd naar de lokale SYSVOL. Wacht in dat geval tot de replicatie voltooid is voordat je de installatie accepteert en aftrapt.
8. Het script pusht nu de agent naar alle servers. Wacht tot deze is voltooid.
9. Aan het einde wordt gevraagd of je de installatiebestanden in SYSVOL wil opruimen. Doe dit als je deze niet meer wil gebruiken.
10. Het script werkt NIET voor de server vanaf waar het wordt gedraaid. Voer de installer op deze server handmatig uit en doorloop de stappen.