<#
.SYNOPSIS
    Génère un rapport des utilisateurs inactifs dans Active Directory.
.DESCRIPTION
    Ce script PowerShell liste tous les utilisateurs qui n'ont pas changé leur mot de passe depuis un nombre de jours spécifié (90 jours par défaut).
    Il affiche les informations suivantes : Login, Nom complet, Dernière modification du mot de passe, Nombre de jours depuis la modification.
    Les résultats sont triés par nombre de jours décroissant et peuvent être exportés en CSV.
.EXAMPLE
    .\report_AD_inactiveUsers.ps1
    Affiche tous les utilisateurs n'ayant pas changé leur mot de passe depuis plus de 90 jours et exporte le résultat vers un CSV par défaut.

    .\report_AD_inactiveUsers.ps1 -Days 60
    Affiche tous les utilisateurs n'ayant pas changé leur mot de passe depuis plus de 60 jours.

    .\report_AD_inactiveUsers.ps1 -Days 90 -ExportPath "C:\Reports\inactifs.csv"
    Affiche les utilisateurs inactifs depuis 90 jours et exporte vers le fichier spécifié.

    .\report_AD_inactiveUsers.ps1 -Days 90 -NoExport
    Affiche uniquement les résultats sans exporter en CSV.
.PARAMETER Days
    Nombre de jours d'inactivité (basé sur le dernier changement de mot de passe). (facultatif, 90 par défaut)
.PARAMETER ExportPath
    Chemin complet du fichier CSV d'export. (facultatif, par défaut: C:\Reports\inactive_users_YYYYMMDD_HHMMSS.csv)
.PARAMETER NoExport
    Si spécifié, n'exporte pas les résultats en CSV, affiche uniquement à l'écran. (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date: 02/02/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits de lecture AD
#>

param (
    [int]$Days = 90,
    [string]$ExportPath,
    [switch]$NoExport
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Définir le chemin d'export par défaut si non spécifié
if (-not $ExportPath -and -not $NoExport) {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportDir = "C:\Reports"
    if (-not (Test-Path -Path $reportDir)) {
        try {
            New-Item -ItemType Directory -Path $reportDir -ErrorAction Stop | Out-Null
            Write-Host "Répertoire de rapports créé: $reportDir" -ForegroundColor Green
        } catch {
            Write-Host "Erreur lors de la création du répertoire de rapports: $_" -ForegroundColor Red
            Write-Host "Utilisation du répertoire actuel." -ForegroundColor Yellow
            $reportDir = "."
        }
    }
    $ExportPath = Join-Path -Path $reportDir -ChildPath "inactive_users_$dateStr.csv"
}

Write-Host "`nRecherche des utilisateurs inactifs (mot de passe non changé depuis plus de $Days jours)..." -ForegroundColor Cyan
Write-Host "================================================================`n"

try {
    # Calculer la date limite
    $dateLimit = (Get-Date).AddDays(-$Days)
    
    # Récupérer tous les utilisateurs avec leurs propriétés
    $users = Get-ADUser -Filter * -Properties PasswordLastSet, DisplayName, Enabled -ErrorAction Stop
    
    if (-not $users) {
        Write-Host "Aucun utilisateur trouvé dans Active Directory." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Nombre total d'utilisateurs: $($users.Count)" -ForegroundColor Cyan
    
    # Filtrer les utilisateurs inactifs
    $inactiveUsers = @()
    
    foreach ($user in $users) {
        # Ignorer les utilisateurs sans date de changement de mot de passe (jamais connectés)
        if (-not $user.PasswordLastSet) {
            continue
        }
        
        # Vérifier si le mot de passe n'a pas été changé depuis plus de X jours
        if ($user.PasswordLastSet -lt $dateLimit) {
            $daysSinceChange = ((Get-Date) - $user.PasswordLastSet).Days
            
            $inactiveUsers += [PSCustomObject]@{
                Login = $user.SamAccountName
                NomComplet = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)" }
                DerniereModificationMotDePasse = $user.PasswordLastSet.ToString("dd/MM/yyyy HH:mm:ss")
                JoursDepuisModification = $daysSinceChange
                Actif = $user.Enabled
            }
        }
    }
    
    # Vérifier si des utilisateurs inactifs ont été trouvés
    if ($inactiveUsers.Count -eq 0) {
        Write-Host "Aucun utilisateur inactif trouvé (mot de passe changé dans les $Days derniers jours)." -ForegroundColor Green
        exit 0
    }
    
    # Trier par nombre de jours décroissant
    $inactiveUsers = $inactiveUsers | Sort-Object -Property JoursDepuisModification -Descending
    
    Write-Host "Nombre d'utilisateurs inactifs trouvés: $($inactiveUsers.Count)" -ForegroundColor Yellow
    Write-Host "`n================================================================`n"
    
    # Afficher les résultats
    Write-Host "Liste des utilisateurs inactifs:" -ForegroundColor Cyan
    $inactiveUsers | Format-Table -AutoSize -Property Login, NomComplet, DerniereModificationMotDePasse, JoursDepuisModification, Actif
    
    # Statistiques
    $activeInactive = ($inactiveUsers | Where-Object { $_.Actif -eq $true }).Count
    $disabledInactive = ($inactiveUsers | Where-Object { $_.Actif -eq $false }).Count
    
    Write-Host "`nStatistiques:" -ForegroundColor Cyan
    Write-Host "  - Comptes actifs inactifs: $activeInactive" -ForegroundColor Yellow
    Write-Host "  - Comptes désactivés inactifs: $disabledInactive" -ForegroundColor Gray
    Write-Host "  - Total: $($inactiveUsers.Count)" -ForegroundColor White
    
    # Exporter en CSV si demandé
    if (-not $NoExport) {
        try {
            $inactiveUsers | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ";" -ErrorAction Stop
            Write-Host "`nRapport exporté avec succès vers: $ExportPath" -ForegroundColor Green
        } catch {
            Write-Host "`nErreur lors de l'export du rapport: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`nAucun export CSV effectué (option -NoExport spécifiée)." -ForegroundColor Yellow
    }
    
    # Recommandations
    if ($activeInactive -gt 0) {
        Write-Host "`nRecommandation: Considérez la désactivation des comptes actifs inactifs pour des raisons de sécurité." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "Erreur lors de la récupération des utilisateurs: $_" -ForegroundColor Red
    exit 1
}
