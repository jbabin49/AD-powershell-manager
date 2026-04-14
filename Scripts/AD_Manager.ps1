<#
.SYNOPSIS
    Gestionnaire interactif Active Directory avec menu principal.
.DESCRIPTION
    Interface de menu interactif proposant un accès centralisé à tous les scripts de gestion Active Directory.
    Permet de gérer les utilisateurs, groupes, OUs, imports/exports et consulter des rapports.
.EXAMPLE
    .\AD_Manager.ps1
    Lance le menu interactif principal.
.NOTES
    Auteur: Julien BABIN
    Date: 03/02/2026
    Version: 1.0
    Dépendances: ActiveDirectory, scripts de gestion AD
#>

param ()

# Importer le module Active Directory
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Variables globales
$scriptsPath = Split-Path -Parent $PSCommandPath
$logDir = "C:\logs\AD_Manager"
$logFile = $null

# Créer le répertoire de logs s'il n'existe pas
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Définir le fichier log
Function define_logfile {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "AD_Manager_$dateStr.log"
    return Join-Path -Path $logDir -ChildPath $logFileName
}

# Fonction de logging
Function log_message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    if ($logFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logFile -Value $logEntry
    }
}

# Fonction pour afficher le menu
Function show_menu {
    Clear-Host
    Write-Host "
╔══════════════════════════════════════════════════════════════╗
║         GESTIONNAIRE ACTIVE DIRECTORY - TechSecure           ║
╚══════════════════════════════════════════════════════════════╝
" -ForegroundColor Cyan

    Write-Host "UTILISATEURS" -ForegroundColor Yellow
    Write-Host "  1. Créer un utilisateur"
    Write-Host "  2. Rechercher un utilisateur"
    Write-Host "  3. Modifier un utilisateur"
    Write-Host "  4. Désactiver un utilisateur"
    Write-Host "  5. Supprimer un utilisateur"
    
    Write-Host "`nGROUPES" -ForegroundColor Yellow
    Write-Host "  6. Créer un groupe"
    Write-Host "  7. Ajouter un membre à un groupe"
    Write-Host "  8. Retirer un membre d'un groupe"
    Write-Host "  9. Lister les membres d'un groupe"
    
    Write-Host "`nIMPORT/EXPORT" -ForegroundColor Yellow
    Write-Host "  10. Importer des utilisateurs depuis CSV"
    Write-Host "  11. Exporter tous les utilisateurs en CSV"
    
    Write-Host "`nRAPPORTS" -ForegroundColor Yellow
    Write-Host "  12. Rapport des utilisateurs inactifs"
    Write-Host "  13. Rapport des groupes"
    Write-Host "  14. Audit complet"
    
    Write-Host "`nAUTRES" -ForegroundColor Yellow
    Write-Host "  15. Réinitialiser un mot de passe"
    Write-Host "  16. Quitter"
    
    Write-Host "`n" -NoNewline
}

# Fonction pour valider le choix de l'utilisateur
Function get_user_choice {
    do {
        Write-Host "Sélectionnez une option (1-16): " -ForegroundColor Cyan -NoNewline
        $choice = Read-Host
        if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt 16) {
            Write-Host "Erreur: Veuillez entrer un nombre entre 1 et 16." -ForegroundColor Red
        } else {
            return [int]$choice
        }
    } while ($true)
}

# Fonction pour appeler un script
Function invoke_script {
    param (
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [string]$Description = ""
    )
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "Erreur: Le script '$ScriptPath' n'existe pas." -ForegroundColor Red
        log_message -Message "ERREUR: Script non trouvé: $ScriptPath" -Level "ERROR"
        pause
        return $false
    }
    
    try {
        log_message -Message "Exécution: $Description - $ScriptPath"
        Write-Host "`n" -BackgroundColor Blue -ForegroundColor White
        
        if ($Parameters.Count -gt 0) {
            & $ScriptPath @Parameters -ErrorAction Stop
        } else {
            & $ScriptPath -ErrorAction Stop
        }
        
        log_message -Message "Succès: $Description"
        Write-Host "`n`nAppuyez sur une touche pour revenir au menu..." -ForegroundColor Green
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $true
    } catch {
        Write-Host "`nErreur lors de l'exécution: $_" -ForegroundColor Red
        log_message -Message "ERREUR lors de l'exécution: $_" -Level "ERROR"
        Write-Host "`nAppuyez sur une touche pour revenir au menu..." -ForegroundColor Red
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return $false
    }
}

# Fonction pour demander une confirmation
Function get_confirmation {
    param (
        [string]$Message = "Êtes-vous sûr?"
    )
    Write-Host "$Message (O/N): " -ForegroundColor Yellow -NoNewline
    $response = Read-Host
    return ($response -eq 'O' -or $response -eq 'o')
}

# Fonction pour obtenir un input utilisateur
Function get_user_input {
    param (
        [string]$Prompt,
        [bool]$Required = $false,
        [bool]$IsPassword = $false
    )
    
    do {
        if ($IsPassword) {
            $userInput = Read-Host "$Prompt" -AsSecureString
            if ($userInput.Length -eq 0 -and -not $Required) {
                return $null
            }
            if ($userInput.Length -eq 0 -and $Required) {
                Write-Host "Ce champ est obligatoire." -ForegroundColor Red
                continue
            }
            return $userInput
        } else {
            $userInput = Read-Host "$Prompt"
            if (-not $userInput -and -not $Required) {
                return $null
            }
            if (-not $userInput -and $Required) {
                Write-Host "Ce champ est obligatoire." -ForegroundColor Red
                continue
            }
            return $userInput.Trim()
        }
    } while ($true)
}

# Fonction pour les menus spécifiques
Function menu_create_user {
    Clear-Host
    Write-Host "=== CRÉER UN UTILISATEUR ===" -ForegroundColor Cyan
    
    $prenom = get_user_input -Prompt "Prénom" -Required $true
    $nom = get_user_input -Prompt "Nom" -Required $true
    $titre = get_user_input -Prompt "Titre/Poste"
    $departement = get_user_input -Prompt "Département"
    $manager = get_user_input -Prompt "Manager (login)"
    
    $params = @{
        Prenom = $prenom
        Nom = $nom
    }
    
    if ($titre) { $params['Titre'] = $titre }
    if ($departement) { $params['Departement'] = $departement }
    if ($manager) { $params['Manager'] = $manager }
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\add_AD_newEmployee.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters $params -Description "Création d'utilisateur"
}

Function menu_search_user {
    Clear-Host
    Write-Host "=== RECHERCHER UN UTILISATEUR ===" -ForegroundColor Cyan
    
    $login = get_user_input -Prompt "Entrez le login ou l'email de l'utilisateur" -Required $true
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "infos\infos_AD_users.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Recherche d'utilisateur"
}

Function menu_modify_user {
    Clear-Host
    Write-Host "=== MODIFIER UN UTILISATEUR ===" -ForegroundColor Cyan
    
    $login = get_user_input -Prompt "Login de l'utilisateur à modifier" -Required $true
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\modify_AD_user.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Modification d'utilisateur"
}

Function menu_disable_user {
    Clear-Host
    Write-Host "=== DÉSACTIVER UN UTILISATEUR ===" -ForegroundColor Cyan
    
    $login = get_user_input -Prompt "Login de l'utilisateur à désactiver" -Required $true
    
    if (get_confirmation -Message "Êtes-vous sûr de vouloir désactiver l'utilisateur '$login'?") {
        $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\disable_AD_user.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Désactivation d'utilisateur"
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

Function menu_delete_user {
    Clear-Host
    Write-Host "=== SUPPRIMER UN UTILISATEUR ===" -ForegroundColor Cyan
    
    $login = get_user_input -Prompt "Login de l'utilisateur à supprimer" -Required $true
    
    if (get_confirmation -Message "Êtes-vous ABSOLUMENT sûr de vouloir supprimer l'utilisateur '$login'? Cette action est irréversible.") {
        if (get_confirmation -Message "Confirmez la suppression de '$login'") {
            $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\delete_AD_user.ps1"
            invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Suppression d'utilisateur"
        }
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

Function menu_create_group {
    Clear-Host
    Write-Host "=== CRÉER UN GROUPE ===" -ForegroundColor Cyan
    
    $groupName = get_user_input -Prompt "Nom du groupe" -Required $true
    $scope = get_user_input -Prompt "Étendue (Global/Local/Universal) [par défaut: Global]"
    if (-not $scope) { $scope = "Global" }
    $category = get_user_input -Prompt "Catégorie (Security/Distribution) [par défaut: Security]"
    if (-not $category) { $category = "Security" }
    $description = get_user_input -Prompt "Description"
    
    $params = @{
        GroupName = $groupName
        GroupScope = $scope
        GroupCategory = $category
    }
    
    if ($description) { $params['Description'] = $description }
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "groups\create_AD_group.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters $params -Description "Création de groupe"
}

Function menu_add_member_to_group {
    Clear-Host
    Write-Host "=== AJOUTER UN MEMBRE À UN GROUPE ===" -ForegroundColor Cyan
    
    $groupName = get_user_input -Prompt "Nom du groupe" -Required $true
    $member = get_user_input -Prompt "Nom du membre (utilisateur ou groupe)" -Required $true
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "groups\add_AD_users_to_group.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters @{GroupName = $groupName; Member = $member} -Description "Ajout d'un membre à un groupe"
}

Function menu_remove_member_from_group {
    Clear-Host
    Write-Host "=== RETIRER UN MEMBRE D'UN GROUPE ===" -ForegroundColor Cyan
    
    $groupName = get_user_input -Prompt "Nom du groupe" -Required $true
    $member = get_user_input -Prompt "Nom du membre à retirer" -Required $true
    
    if (get_confirmation -Message "Êtes-vous sûr de vouloir retirer '$member' du groupe '$groupName'?") {
        $scriptPath = Join-Path -Path $scriptsPath -ChildPath "groups\remove_AD_member_from_group.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{GroupName = $groupName; Member = $member} -Description "Retrait d'un membre d'un groupe"
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

Function menu_list_group_members {
    Clear-Host
    Write-Host "=== LISTER LES MEMBRES D'UN GROUPE ===" -ForegroundColor Cyan
    
    $groupName = get_user_input -Prompt "Nom du groupe" -Required $true
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "infos\infos_AD_groups.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters @{GroupName = $groupName} -Description "Affichage des membres d'un groupe"
}

Function menu_import_users {
    Clear-Host
    Write-Host "=== IMPORTER DES UTILISATEURS DEPUIS CSV ===" -ForegroundColor Cyan
    
    $csvPath = get_user_input -Prompt "Chemin du fichier CSV" -Required $true
    
    if (-not (Test-Path $csvPath)) {
        Write-Host "Erreur: Le fichier '$csvPath' n'existe pas." -ForegroundColor Red
        pause
        return
    }
    
    Write-Host "`nAperçu du fichier:"
    Write-Host (Get-Content $csvPath | Select-Object -First 3 | Out-String)
    
    if (get_confirmation -Message "Procéder à l'import?") {
        $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\create_AD_user.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{FilePath = $csvPath} -Description "Import d'utilisateurs depuis CSV"
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

Function menu_export_users {
    Clear-Host
    Write-Host "=== EXPORTER LES UTILISATEURS EN CSV ===" -ForegroundColor Cyan
    
    $outputPath = get_user_input -Prompt "Chemin de sortie du fichier CSV [par défaut: C:\exports\users_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv]"
    
    if (-not $outputPath) {
        $exportDir = "C:\exports"
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir | Out-Null
        }
        $outputPath = Join-Path -Path $exportDir -ChildPath "users_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    }
    
    try {
        Write-Host "`nExportation en cours..." -ForegroundColor Yellow
        
        # Récupérer tous les utilisateurs AD
        $users = Get-ADUser -Filter * -Properties DisplayName, EmailAddress, Title, Department, Manager, Enabled, LastLogonDate | 
                 Select-Object @{Name='Login';Expression={$_.SamAccountName}},
                             @{Name='Nom';Expression={$_.Surname}},
                             @{Name='Prenom';Expression={$_.GivenName}},
                             DisplayName,
                             EmailAddress,
                             Title,
                             Department,
                             @{Name='Manager';Expression={(Get-ADUser -Identity $_.Manager -Properties Name -ErrorAction SilentlyContinue).Name}},
                             Enabled,
                             LastLogonDate
        
        if ($users) {
            $users | Export-Csv -Path $outputPath -Encoding UTF8 -NoTypeInformation
            Write-Host "✓ Export réussi: $outputPath" -ForegroundColor Green
            Write-Host "Nombre d'utilisateurs exportés: $($users.Count)" -ForegroundColor Green
            log_message -Message "Export des utilisateurs réussi: $outputPath ($($users.Count) utilisateurs)"
        } else {
            Write-Host "Aucun utilisateur trouvé." -ForegroundColor Yellow
        }
        
        pause
    } catch {
        Write-Host "Erreur lors de l'export: $_" -ForegroundColor Red
        log_message -Message "ERREUR lors de l'export des utilisateurs: $_" -Level "ERROR"
        pause
    }
}

Function menu_report_inactive_users {
    Clear-Host
    Write-Host "=== RAPPORT DES UTILISATEURS INACTIFS ===" -ForegroundColor Cyan
    
    $days = get_user_input -Prompt "Nombre de jours d'inactivité [par défaut: 30]"
    
    $params = @{}
    if ($days) { $params['Days'] = [int]$days }
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "infos\report_AD_inactiveUsers.ps1"
    invoke_script -ScriptPath $scriptPath -Parameters $params -Description "Rapport des utilisateurs inactifs"
}

Function menu_report_groups {
    Clear-Host
    Write-Host "=== RAPPORT DES GROUPES ===" -ForegroundColor Cyan
    
    $scriptPath = Join-Path -Path $scriptsPath -ChildPath "infos\report_AD_securityGroups.ps1"
    invoke_script -ScriptPath $scriptPath -Description "Rapport des groupes"
}

Function menu_report_complete {
    Clear-Host
    Write-Host "=== AUDIT COMPLET ===" -ForegroundColor Cyan
    
    Write-Host "Cet audit générera plusieurs rapports:" -ForegroundColor Yellow
    Write-Host "  - Rapport des utilisateurs"
    Write-Host "  - Rapport des groupes"
    Write-Host "  - Rapport des OUs"
    Write-Host "  - Rapport du domaine"
    Write-Host ""
    
    if (get_confirmation -Message "Procéder à l'audit complet?") {
        $scriptPath = Join-Path -Path $scriptsPath -ChildPath "infos\report_AD_complete.ps1"
        invoke_script -ScriptPath $scriptPath -Description "Audit complet"
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

Function menu_reset_password {
    Clear-Host
    Write-Host "=== RÉINITIALISER UN MOT DE PASSE ===" -ForegroundColor Cyan
    
    $login = get_user_input -Prompt "Login de l'utilisateur" -Required $true
    
    # Vérifier que l'utilisateur existe
    $user = Get-ADUser -Filter "SamAccountName -eq '$login'" -ErrorAction SilentlyContinue
    if (-not $user) {
        Write-Host "Erreur: L'utilisateur '$login' n'existe pas." -ForegroundColor Red
        pause
        return
    }
    
    if (get_confirmation -Message "Êtes-vous sûr de vouloir réinitialiser le mot de passe de '$login'?") {
        $scriptPath = Join-Path -Path $scriptsPath -ChildPath "users\reset_AD_employeePassword.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Réinitialisation du mot de passe"
    } else {
        Write-Host "Opération annulée." -ForegroundColor Yellow
        pause
    }
}

# Fonction principale
Function main {
    # Initialiser le fichier log
    $script:logFile = define_logfile
    log_message -Message "========== DÉMARRAGE DU GESTIONNAIRE AD =========="
    
    while ($true) {
        show_menu
        $choice = get_user_choice
        
        switch ($choice) {
            1 { menu_create_user }
            2 { menu_search_user }
            3 { menu_modify_user }
            4 { menu_disable_user }
            5 { menu_delete_user }
            6 { menu_create_group }
            7 { menu_add_member_to_group }
            8 { menu_remove_member_from_group }
            9 { menu_list_group_members }
            10 { menu_import_users }
            11 { menu_export_users }
            12 { menu_report_inactive_users }
            13 { menu_report_groups }
            14 { menu_report_complete }
            15 { menu_reset_password }
            16 {
                log_message -Message "========== FERMETURE DU GESTIONNAIRE AD =========="
                Write-Host "`nAu revoir!" -ForegroundColor Green
                Write-Host "Le fichier log a été enregistré: $logFile" -ForegroundColor Cyan
                exit 0
            }
        }
    }
}

# Lancer le script principal
try {
    main
} catch {
    Write-Host "Erreur critique: $_" -ForegroundColor Red
    log_message -Message "ERREUR CRITIQUE: $_" -Level "ERROR"
    pause
    exit 1
}
