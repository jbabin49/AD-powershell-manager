<#
.SYNOPSIS
    Génère un rapport des comptes utilisateurs désactivés dans Active Directory.
.DESCRIPTION
    Ce script PowerShell liste tous les comptes utilisateurs désactivés. Il affiche : Login, Nom, OU et Date de désactivation si elle est présente dans la description pu les notes du compte.
    Les résultats peuvent être exportés en CSV.
.EXAMPLE
    .\report_AD_disabledUsers.ps1
    Affiche tous les comptes désactivés et exporte le rapport vers un CSV par défaut.

    .\report_AD_disabledUsers.ps1 -ExportPath "C:\Reports\disabled_users.csv"
    Affiche les comptes désactivés et exporte vers le fichier spécifié.

    .\report_AD_disabledUsers.ps1 -NoExport
    Affiche uniquement les résultats sans exporter en CSV.
.PARAMETER ExportPath
    Chemin complet du fichier CSV d'export. (facultatif, par défaut: C:\Reports\disabled_users_YYYYMMDD_HHMMSS.csv)
.PARAMETER NoExport
    Si spécifié, n'exporte pas les résultats en CSV, affiche uniquement à l'écran. (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date: 02/02/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits de lecture AD
#>

param (
    [string]$ExportPath,
    [switch]$NoExport
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function get_ou_from_dn {
    param (
        [string]$DistinguishedName
    )

    if (-not $DistinguishedName) {
        return $null
    }

    return ($DistinguishedName -replace '^CN=[^,]+,', '')
}

Function get_disable_date_from_description {
    param (
        [string]$Description
    )

    if (-not $Description) {
        return $null
    }

    $datePatterns = @(
        '\b\d{2}/\d{2}/\d{4}\b',
        '\b\d{4}-\d{2}-\d{2}\b',
        '\b\d{2}-\d{2}-\d{4}\b',
        '\b\d{4}/\d{2}/\d{2}\b'
    )

    foreach ($pattern in $datePatterns) {
        $match = [regex]::Match($Description, $pattern)
        if ($match.Success) {
            return $match.Value
        }
    }

    return $null
}

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
    $ExportPath = Join-Path -Path $reportDir -ChildPath "disabled_users_$dateStr.csv"
}

Write-Host "`nRecherche des comptes utilisateurs désactivés..." -ForegroundColor Cyan
Write-Host "===============================================`n"

try {
    $users = Get-ADUser -Filter { Enabled -eq $false } -Properties SamAccountName, Name, DistinguishedName, Description -ErrorAction Stop

    if (-not $users) {
        Write-Host "Aucun compte désactivé trouvé dans Active Directory." -ForegroundColor Green
        exit 0
    }

    $disabledUsers = foreach ($user in $users) {
        $ou = get_ou_from_dn -DistinguishedName $user.DistinguishedName
        $disableDate = get_disable_date_from_description -Description $user.Description

        [PSCustomObject]@{
            Login = $user.SamAccountName
            Nom = $user.Name
            OU = $ou
            DateDesactivation = if ($disableDate) { $disableDate } else { "N/A" }
        }
    }

    Write-Host "Nombre total de comptes désactivés: $($disabledUsers.Count)" -ForegroundColor Yellow
    Write-Host "`nListe des comptes désactivés:" -ForegroundColor Cyan
    $disabledUsers | Format-Table -AutoSize -Property Login, Nom, OU, DateDesactivation

    if (-not $NoExport) {
        try {
            $disabledUsers | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8 -Delimiter ";" -ErrorAction Stop
            Write-Host "`nRapport exporté avec succès vers: $ExportPath" -ForegroundColor Green
        } catch {
            Write-Host "`nErreur lors de l'export du rapport: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`nAucun export CSV effectué (option -NoExport spécifiée)." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Erreur lors de la récupération des comptes désactivés: $_" -ForegroundColor Red
    exit 1
}
