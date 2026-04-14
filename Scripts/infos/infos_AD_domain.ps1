<#
.SYNOPSIS
    Affichage des infos de l'Active Directory.
.DESCRIPTION
    Ce script PowerShell récupère et affiche diverses informations sur l'Active Directory, telles que les contrôleurs de domaine, les utilisateurs, les groupes et les unités organisationnelles.
.EXAMPLE
    .\infos_ad.ps1
    Exécute le script et affiche les informations de l'Active Directory.
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

# Importer le module Active Directory
Import-Module ActiveDirectory

# Récupérer les informations des contrôleurs de domaine
$domain = Get-ADDomain | Select-Object Name, DomainMode, DNSRoot
$domainControllers = Get-ADDomainController -Filter * | Select-Object Name, IPv4Address


# Afficher les informations des contrôleurs de domaine
Write-Host "Informations du Domaine Active Directory:" -ForegroundColor Cyan
Write-Host "Nom du Domaine:" -ForegroundColor Green -NoNewline
Write-Host " $($domain.Name)"
Write-Host "Niveau fonctionnel:" -ForegroundColor Blue -NoNewline
Write-Host " $($domain.DomainMode)"
Write-Host "Racine DNS:" -ForegroundColor Yellow -NoNewline
Write-Host " $($domain.DNSRoot)"
Write-Host "Contrôleurs de Domaine:" -ForegroundColor Magenta
Format-Table -InputObject $domainControllers -AutoSize