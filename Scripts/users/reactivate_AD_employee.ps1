<#
.SYNOPSIS
    Réactive un employé dans Active Directory.
.DESCRIPTION
    Ce script réactive un employé dans Active Directory en activant son compte, en le déplaçant vers une nouvelle unité organisationnelle (OU),
    en l'ajoutant à des groupes spécifiés et en réinitialisant son mot de passe.
    Il ajoute également une note dans son profil avec la date de réactivation et logge toutes les actions.
.EXAMPLE
    .\reactivate_AD_employee.ps1 -Login "jdoe"
    Réactive l'employé avec le login "jdoe" en mode interactif.

    .\reactivate_AD_employee.ps1 -Login "jdoe" -OU "Developpement" -Groupes "GRP_Developpement,GRP_Tous_Utilisateurs"
    Réactive l'employé directement avec les paramètres spécifiés.
.PARAMETER Login
    Le login de l'employé à réactiver dans Active Directory. (obligatoire)
.PARAMETER OU
    Le nom de l'unité organisationnelle où déplacer l'utilisateur. (facultatif, demandé en mode interactif)
.PARAMETER Groupes
    Les groupes à ajouter à l'utilisateur, séparés par des virgules. (facultatif, demandé en mode interactif)
.PARAMETER LogFilePath
    Le chemin du fichier journal où les actions seront enregistrées. (facultatif)
    Par défaut, un fichier journal est créé dans le répertoire "C:\logs\user_reactivation".
.NOTES
    Auteur: Julien Babin
    Date de création: 02/02/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Login,
    [string]$OU,
    [string]$Groupes,
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

Function add_user_to_groups {
    param (
        [string]$Login,
        [string]$Groupes,
        [string]$LogFilePath
    )
    
    if (-not $Groupes -or $Groupes.Trim() -eq '') {
        Write-Host "Aucun groupe spécifié." -ForegroundColor Yellow
        return
    }
    
    $groupList = $Groupes -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    Write-Host "Ajout de l'utilisateur aux groupes..." -ForegroundColor Yellow
    $addedCount = 0
    
    foreach ($groupName in $groupList) {
        try {
            $groupName = $groupName.Trim()
            # Vérifier que le groupe existe
            $groupExists = Get-ADGroup -Filter "SamAccountName -eq '$groupName'" -ErrorAction Stop
            
            if ($groupExists) {
                Add-ADGroupMember -Identity $groupName -Members $Login -ErrorAction Stop
                Write-Host "  - Ajouté au groupe: $groupName" -ForegroundColor Green
                log_Action -Message "Utilisateur '$Login' ajouté au groupe '$groupName'." -LogFilePath $LogFilePath
                $addedCount++
            }
        } catch {
            Write-Host "  - Erreur lors de l'ajout au groupe '$groupName': $_" -ForegroundColor Red
            log_Action -Message "Erreur lors de l'ajout de '$Login' au groupe '$groupName': $_" -LogFilePath $LogFilePath
        }
    }
    
    Write-Host "Utilisateur ajouté à $addedCount groupe(s)." -ForegroundColor Cyan
    log_Action -Message "Utilisateur '$Login' ajouté à $addedCount groupe(s)." -LogFilePath $LogFilePath
}

Function reactivate_AD_employee {
    param (
        [string]$Login,
        [string]$OU,
        [string]$Groupes,
        [string]$LogFilePath
    )

    # Récupérer l'utilisateur AD
    $user = Get-ADUser -Filter { SamAccountName -eq $Login } -Properties DisplayName, GivenName, Surname, Info, Enabled -ErrorAction SilentlyContinue

    if (-not $user) {
        Write-Host "Erreur: Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
        log_Action -Message "Tentative de réactivation de l'utilisateur '$Login' - Utilisateur non trouvé." -LogFilePath $LogFilePath
        return
    }

    # Afficher les informations de l'utilisateur
    $displayName = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)" }
    Write-Host "`nUtilisateur trouvé: $displayName" -ForegroundColor Cyan
    Write-Host "Statut actuel: $(if ($user.Enabled) { 'Activé' } else { 'Désactivé' })" -ForegroundColor $(if ($user.Enabled) { 'Green' } else { 'Yellow' })
    
    # Demander confirmation avant de procéder
    $confirmation = Read-Host "Êtes-vous sûr de vouloir réactiver cet utilisateur (y/n)?"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    # Demander l'OU si non fournie
    if (-not $OU) {
        Write-Host "`nOUs disponibles:" -ForegroundColor Cyan
        Get-ADOrganizationalUnit -Filter * -SearchScope Subtree | Select-Object -First 10 Name | ForEach-Object { Write-Host "  - $($_.Name)" }
        Write-Host "  ... (plus d'OUs disponibles)" -ForegroundColor Gray
        $OU = Read-Host "`nEntrez le nom de l'OU de destination"
    }

    # Demander les groupes si non fournis
    if (-not $Groupes) {
        Write-Host "`nGroupes disponibles (exemples):" -ForegroundColor Cyan
        Get-ADGroup -Filter * | Select-Object -First 10 Name | ForEach-Object { Write-Host "  - $($_.Name)" }
        Write-Host "  ... (plus de groupes disponibles)" -ForegroundColor Gray
        $Groupes = Read-Host "`nEntrez les groupes à ajouter (séparés par des virgules, laisser vide pour ignorer)"
    }

    # Générer un nouveau mot de passe temporaire
    $tempPassword = "NewTemp_$(Get-Random -Minimum 10000 -Maximum 99999)!Aa"

    try {
        # Réinitialiser le mot de passe
        Write-Host "`nRéinitialisation du mot de passe..." -ForegroundColor Yellow
        Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword (ConvertTo-SecureString -AsPlainText $tempPassword -Force) -Reset -ErrorAction Stop
        Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Host "Mot de passe réinitialisé avec succès." -ForegroundColor Green
        Write-Host "Nouveau mot de passe temporaire: $tempPassword" -ForegroundColor Cyan
        log_Action -Message "Mot de passe réinitialisé pour l'utilisateur '$Login'. Nouveau mot de passe: $tempPassword" -LogFilePath $LogFilePath

        # Activer le compte utilisateur
        Write-Host "Activation du compte..." -ForegroundColor Yellow
        Enable-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
        Write-Host "Compte activé avec succès." -ForegroundColor Green
        log_Action -Message "Compte activé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath

        # Déplacer l'utilisateur vers la nouvelle OU
        Write-Host "Recherche de l'OU '$OU'..." -ForegroundColor Yellow
        $targetOU = find_OU_by_name -OuName $OU
        Write-Host "OU trouvée: $targetOU" -ForegroundColor Cyan
        
        # Rafraîchir l'utilisateur pour obtenir le DN correct
        $user = Get-ADUser -Filter { SamAccountName -eq $Login } -ErrorAction Stop
        
        Write-Host "Déplacement de l'utilisateur vers la nouvelle OU..." -ForegroundColor Yellow
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU -ErrorAction Stop
        Write-Host "Déplacement effectué avec succès." -ForegroundColor Green
        log_Action -Message "Utilisateur '$Login' déplacé vers l'OU '$targetOU'." -LogFilePath $LogFilePath

        # Ajouter l'utilisateur aux groupes spécifiés
        if ($Groupes) {
            add_user_to_groups -Login $Login -Groupes $Groupes -LogFilePath $LogFilePath
        }

        # Mettre à jour les notes avec la date de réactivation
        $dateNow = Get-Date -Format "yyyy-MM-dd"
        $currentNotes = $user.Info
        
        if ($currentNotes -match "Désactivé le" -or $currentNotes -match "désactivé le") {
            $newNotes = "$currentNotes | Réactivé le $dateNow"
            Write-Host "Note ajoutée: Réactivé le $dateNow" -ForegroundColor Cyan
        } else {
            $newNotes = if ($currentNotes) { "$currentNotes | Activé le $dateNow" } else { "Activé le $dateNow" }
            Write-Host "Note ajoutée: Activé le $dateNow" -ForegroundColor Cyan
        }
        
        Set-ADUser -Identity $user.SamAccountName -Replace @{Info=$newNotes} -ErrorAction Stop
        log_Action -Message "Notes mises à jour pour l'utilisateur '$Login': $newNotes" -LogFilePath $LogFilePath

        Write-Host "`nUtilisateur '$displayName' réactivé avec succès." -ForegroundColor Green
        Write-Host "N'oubliez pas de communiquer le nouveau mot de passe à l'utilisateur: $tempPassword" -ForegroundColor Yellow
        log_Action -Message "Utilisateur '$displayName' (Login: $Login) complètement réactivé." -LogFilePath $LogFilePath
    } catch {
        Write-Host "Erreur lors de la réactivation de l'utilisateur: $_" -ForegroundColor Red
        log_Action -Message "Erreur lors de la réactivation de '$Login': $_" -LogFilePath $LogFilePath
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
    $logDir = "C:\logs\user_reactivation"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFilePath = Join-Path -Path $logDir -ChildPath "reactivation_log_$dateStr.log"
}

# Appeler la fonction de réactivation avec gestion d'erreur
try {
    reactivate_AD_employee -Login $Login -OU $OU -Groupes $Groupes -LogFilePath $LogFilePath
    exit 0
} catch {
    Write-Host "Erreur critique: $_" -ForegroundColor Red
    exit 1
}
