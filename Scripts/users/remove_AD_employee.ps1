<#
.SYNOPSIS
    Retire un employé d'Active Directory.
.DESCRIPTION
    Ce script retire un employé d'Active Directory en désactivant son compte, en déplaçant son compte vers une unité organisationnelle (OU) spécifique pour les comptes inactifs.
    Il réinitialise également le mot de passe de l'utilisateur avant la désactivation et ajoute une note dans son profil avec la date de désactivation.
    Il logge toutes les actions effectuées dans un fichier journal et demande une confirmation avant de procéder aux actions critiques.
.ExAMPLE
    .\remove_AD_employee.ps1 -Login "jdoe" -LogFilePath "C:\Logs\AD_Removals.log"
    Retire l'employé avec le login "jdoe" et enregistre les actions dans le fichier journal spécifié (facultatif, fichier journal créé par défaut).
.PARAMETER Login
    Le login de l'employé à retirer d'Active Directory.
.PARAMETER LogFilePath
    Le chemin du fichier journal où les actions seront enregistrées. (facultatif)
    Par défaut, un fichier journal est créé dans le répertoire "C:\Logs" au format "prenom.nom_yyyyMMdd_HHmmss.log".
.NOTES
    Auteur: Julien Babin
    Date de création: 02-02-2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD 
#>

param (
    [string]$Login,
    [string]$LogFilePath
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function log_Action {
    param (
        [string]$Message,
        [string]$LogFilePath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Add-Content -Path $LogFilePath -Value $logEntry
}

Function find_OU_by_name {
    param (
        [string]$OuName
    )
    
    $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$OuName'" -SearchScope Subtree -ErrorAction SilentlyContinue
    
    if ($ouExists.Count -gt 1) {
        Write-Host "Plusieurs OUs nommées '$OuName' ont été trouvées. Veuillez choisir celle à utiliser :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ouExists.Count; $i++) {
            Write-Host "[$i] $($ouExists[$i].DistinguishedName)"
        }
        $choice = Read-Host "Entrez le numéro correspondant à l'OU souhaitée"
        if ($choice -ge 0 -and $choice -lt $ouExists.Count) {
            return $ouExists[$choice].DistinguishedName
        } else {
            throw "Erreur: Choix invalide."
        }
    } elseif ($ouExists) {
        return $ouExists.DistinguishedName
    } else {
        throw "Erreur: L'OU '$OuName' n'existe pas dans Active Directory."
    }
}

Function remove_user_from_all_groups {
    param (
        [string]$Login,
        [string]$LogFilePath
    )
    
    try {
        # Récupérer tous les groupes de l'utilisateur
        $userGroups = Get-ADUser -Identity $Login -Properties MemberOf -ErrorAction Stop | Select-Object -ExpandProperty MemberOf
        
        if ($userGroups) {
            Write-Host "Retrait de l'utilisateur de ses groupes..." -ForegroundColor Yellow
            $removedCount = 0
            
            foreach ($group in $userGroups) {
                try {
                    Remove-ADGroupMember -Identity $group -Members $Login -Confirm:$false -ErrorAction Stop
                    $groupName = ($group -split ',')[0] -replace '^CN='
                    Write-Host "  - Retiré du groupe: $groupName" -ForegroundColor Green
                    log_Action -Message "Utilisateur '$Login' retiré du groupe '$group'." -LogFilePath $LogFilePath
                    $removedCount++
                } catch {
                    $groupName = ($group -split ',')[0] -replace '^CN='
                    Write-Host "  - Erreur lors du retrait du groupe '$groupName': $_" -ForegroundColor Red
                    log_Action -Message "Erreur lors du retrait de '$Login' du groupe '$group': $_" -LogFilePath $LogFilePath
                }
            }
            
            Write-Host "Utilisateur retiré de $removedCount groupe(s)." -ForegroundColor Cyan
            log_Action -Message "Utilisateur '$Login' retiré de $removedCount groupe(s)." -LogFilePath $LogFilePath
        } else {
            Write-Host "L'utilisateur n'appartient à aucun groupe." -ForegroundColor Yellow
            log_Action -Message "Utilisateur '$Login' n'appartient à aucun groupe." -LogFilePath $LogFilePath
        }
    } catch {
        Write-Host "Erreur lors de la récupération des groupes: $_" -ForegroundColor Red
        log_Action -Message "Erreur lors de la récupération des groupes de '$Login': $_" -LogFilePath $LogFilePath
        throw
    }
}

Function remove_AD_employee {
    param (
        [string]$Login,
        [string]$LogFilePath
    )

    # Récupérer l'utilisateur AD
    $user = Get-ADUser -Filter { SamAccountName -eq $Login } -Properties DisplayName, GivenName, Surname, Info -ErrorAction SilentlyContinue

    if (-not $user) {
        Write-Host "Erreur: Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
        log_Action -Message "Tentative de retrait de l'utilisateur '$Login' - Utilisateur non trouvé." -LogFilePath $LogFilePath
        return
    }

    # Demander confirmation avant de procéder
    $displayName = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)" }
    Write-Host "`nUtilisateur trouvé: $displayName" -ForegroundColor Cyan
    $confirmation = Read-Host "Êtes-vous sûr de vouloir retirer cet utilisateur (y/n)?"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    # Générer un mot de passe temporaire
    $tempPassword = "RemovalTemp_$(Get-Random -Minimum 10000 -Maximum 99999)!"

    try {
        # Réinitialiser le mot de passe
        Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword (ConvertTo-SecureString -AsPlainText $tempPassword -Force) -Reset
        log_Action -Message "Mot de passe réinitialisé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath

        # Retirer l'utilisateur de tous ses groupes
        remove_user_from_all_groups -Login $Login -LogFilePath $LogFilePath

        # Ajouter une note dans les notes avec la date de désactivation
        $dateNow = Get-Date -Format "yyyy-MM-dd"
        $newNotes = if ($user.Info) { "$($user.Info) | Désactivé le $dateNow" } else { "Désactivé le $dateNow" }
        Set-ADUser -Identity $user.SamAccountName -Replace @{Info=$newNotes}
        log_Action -Message "Notes mises à jour pour l'utilisateur '$Login'." -LogFilePath $LogFilePath

        # Chercher l'OU Inactive et déplacer l'utilisateur
        Write-Host "Recherche de l'OU 'Inactive'..." -ForegroundColor Yellow
        $inactiveOU = find_OU_by_name -OuName "Inactive"
        Write-Host "OU trouvée: $inactiveOU" -ForegroundColor Cyan
        
        # Rafraichiir l'utilisateur pour obtenir le DN correct
        $user = Get-ADUser -Filter { SamAccountName -eq $Login } -ErrorAction Stop
        
        Write-Host "Déplacement de l'utilisateur vers Inactive..." -ForegroundColor Yellow
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $inactiveOU -ErrorAction Stop
        Write-Host "Déplacement effectué avec succès." -ForegroundColor Green
        log_Action -Message "Utilisateur '$Login' déplacé vers l'OU Inactive ($inactiveOU)." -LogFilePath $LogFilePath

        # Désactiver le compte utilisateur
        Disable-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
        log_Action -Message "Compte désactivé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath

        Write-Host "Utilisateur '$displayName' retiré avec succès." -ForegroundColor Green
        log_Action -Message "Utilisateur '$displayName' (Login: $Login) complètement retiré." -LogFilePath $LogFilePath
    } catch {
        Write-Host "Erreur lors du retrait de l'utilisateur: $_" -ForegroundColor Red
        log_Action -Message "Erreur lors du retrait de '$Login': $_" -LogFilePath $LogFilePath
        throw
    }
}

# Valider les paramètres obligatoires
if (-not $Login) {
    Write-Host "Erreur: Le paramètre Login est obligatoire." -ForegroundColor Red
    exit 1
}

# Initialiser le fichier log si non fourni
if (-not $LogFilePath) {
    $logDir = "C:\logs\user_removal"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFilePath = Join-Path -Path $logDir -ChildPath "removal_log_$dateStr.log"
}

# Appeler la fonction de suppression avec gestion d'erreur
try {
    remove_AD_employee -Login $Login -LogFilePath $LogFilePath
    exit 0
} catch {
    Write-Host "Erreur critique: $_" -ForegroundColor Red
    exit 1
}