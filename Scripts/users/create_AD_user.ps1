<#
.SYNOPSIS
    Création d'utilisateurs dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de créer de nouveaux utilisateurs dans Active Directory avec des propriétés spécifiées telles que le nom, le prénom, le login, l'adresse e-mail, le titre et l'unité organisationnelle.
.EXAMPLE
    $securePass = Read-Host "Mot de passe" -AsSecureString
    .\create_AD_user.ps1 -Prenom "John" -Nom "Doe" -Login "jdoe" -Email "john.doe@example.com" -Titre "Manager" -OU "OU=Users" -Manager "jsmith" -Departement "Developpement" -Groupe "GRP_Developpement" -Password $securePass -Enable "true" 
    Exécute le script pour créer un nouvel utilisateur avec les propriétés spécifiées.
    
    .\create_AD_user.ps1 -FilePath "C:\users.csv"
    Exécute le script et crée tous les utilisateurs à partir d'un fichier CSV.
.PARAMETER Prenom
    Le prénom de l'utilisateur au format "Prénom". (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Nom
    Le nom de l'utilisateur au format "Nom". (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Login
    Le nom d'utilisateur (login) pour l'utilisateur au format "login". (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Email
    L'adresse e-mail de l'utilisateur au format "email". (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Titre
    Le titre ou poste de l'utilisateur au format "Titre". (facultatif)
.PARAMETER OU
    L'unité organisationnelle où l'utilisateur sera créé au format "OU=Users" (facultatif, l'OU est générée automatiquement à partir du département si non spécifié)
.PARAMETER Manager
    Le login du manager de l'utilisateur au format "login". (facultatif, "manager" par défaut)
.PARAMETER Departement
    Le département de l'utilisateur au format "Département". (facultatif, "Utilisateurs" par défaut) 
.PARAMETER Groupe
    Les groupes auxquels l'utilisateur sera ajouté, séparés par des virgules. (facultatif)
.PARAMETER Password
    Le mot de passe de l'utilisateur en tant que SecureString. (facultatif) 
    Si non spécifié, un mot de passe par défaut sera utilisé ("TempP@ssw0rd123456!").
    Exemple: $securePass = Read-Host "Mot de passe" -AsSecureString
    L'option pour que l'utilisateur change son mot de passe à la prochaine connexion est activée par défaut pour des raisons de sécurité.
.PARAMETER Enable
    Indique si le compte utilisateur doit être activé ou non. (facultatif, par défaut true)
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les utilisateurs à créer. Le fichier doit avoir au moins les colonnes: Prenom, Nom, Login, Email, Titre, OU, (Manager, Departement, Groupe, Password sont facultatifs). (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Prenom,
    [string]$Nom,
    [string]$Login,
    [string]$Email,
    [string]$Titre,
    [string]$OU,
    [string]$Manager,
    [string]$Departement,
    [string]$Groupe,
    [SecureString]$Password,
    [bool]$Enable = $true,
    [string]$FilePath
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function define_logfile {
    param (
        [string]$Prenom,
        [string]$Nom
    )
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $logDir = "C:\logs\user_creation"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    $logFileName = "$($Prenom.ToLower()).$($Nom.ToLower())_$dateStr.log"
    return Join-Path -Path $logDir -ChildPath $logFileName
}

Function log_message {
    param (
        [string]$Message,
        [string]$LogFile
    )
    if ($LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $Message"
        Add-Content -Path $LogFile -Value $logEntry
    }
}

Function get_OU_by_department {
    param (
        [string]$Departement
    )
    # Mapper les départements aux OUs
    $ouMap = @{
        "Developpement" = "Developpement"
        "Infrastructure" = "Infrastructure"
        "Informatique"  = "Informatique"
        "Support"       = "Support"
        "Recrutement"   = "Recrutement"
        "RH"            = "RH"
        "Commercial"    = "Commercial"
        "B2B"           = "B2B"
        "B2C"           = "B2C"
        "Marketing"     = "Marketing"
        "Comptabilite"  = "Comptabilite"
        "Communication" = "Communication"
        "IT"            = "Developpement"
    }
    return $ouMap[$Departement]
}

Function get_group_by_department {
    param (
        [string]$Departement
    )
    # Mapper les départements aux groupes
    $groupMap = @{
        "Developpement" = "GRP_Developpement"
        "Infrastructure" = "GRP_Infrastructure"
        "Informatique"  = "GRP_Informatique"
        "Support"       = "GRP_Support"
        "Recrutement"   = "GRP_Recrutement"
        "RH"            = "GRP_RH"
        "Commercial"    = "GRP_Commercial"
        "B2B"           = "GRP_B2B"
        "B2C"           = "GRP_B2C"
        "Marketing"     = "GRP_Marketing"
        "Comptabilite"  = "GRP_Comptabilite"
        "Communication" = "GRP_Communication"
        "IT"            = "GRP_Developpement"
    }
    return $groupMap[$Departement]
}

Function send_welcome_email {
    param (
        [string]$Prenom,
        [string]$Nom,
        [string]$Login,
        [string]$Email,
        [string]$Titre,
        [string]$Departement,
        [string]$Manager,
        [string]$LogFile
    )
    
    $welcomeMessage = @"

===========================================
EMAIL DE BIENVENUE
===========================================

Bonjour $Prenom $Nom,

Bienvenue chez TechSecure ! Nous sommes ravis de vous accueillir au sein de notre équipe en tant que $Titre dans le département $Departement.

Votre compte a été créé avec les informations suivantes :
- Login : $Login
- E-mail : $Email
- Mot de passe temporaire : TempP@ssw0rd123456!

Ce mot de passe est temporaire et vous serez invité à le changer lors de votre première connexion.

N'hésitez pas à contacter votre manager $Manager pour toute question.

Cordialement,
L'équipe TechSecure

===========================================
"@

    try {
        Write-Host $welcomeMessage -ForegroundColor Cyan
        log_message -Message "Email de bienvenue envoyé à $Login." -LogFile $LogFile
    } catch {
        log_message -Message "Erreur lors de l'envoi de l'email à ${Login}: $_" -LogFile $LogFile
        throw "Erreur lors de l'envoi de l'email à ${Login}: $_"
    }
}

Function add_user_to_groups {
    param (
        [string]$Login,
        [string]$Groupe,
        [string]$LogFile
    )
    
    if (-not $Groupe) {
        return
    }
    
    $groupList = $Groupe -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($group in $groupList) {
        $groupName = $group.Trim()
        try {
            Add-ADGroupMember -Identity $groupName -Members $Login -ErrorAction Stop
            log_message -Message "L'utilisateur '$Login' a été ajouté au groupe '$groupName'." -LogFile $LogFile
        } catch {
            log_message -Message "Erreur lors de l'ajout de '$Login' au groupe '$groupName': $_" -LogFile $LogFile
            throw "Erreur lors de l'ajout de '$Login' au groupe '$groupName': $_"
        }
    }
}


Function create_AD_user {
    param (
        [string]$Prenom,
        [string]$Nom,
        [string]$Login,
        [string]$Email,
        [string]$Titre,
        [string]$OU,
        [string]$Manager,
        [string]$Departement,
        [string]$Groupe,
        [SecureString]$Password,
        [bool]$Enable,
        [string]$LogFile
    )

    # Vérifier les paramètres obligatoires
    if (-not $Prenom) {
        throw "Erreur: Le paramètre Prenom est obligatoire."
    }
    if (-not $Nom) {
        throw "Erreur: Le paramètre Nom est obligatoire."
    }
    if (-not $Login) {
        throw "Erreur: Le paramètre Login est obligatoire."
    }
    if (-not $Email) {
        throw "Erreur: Le paramètre Email est obligatoire."
    }
    if (-not $OU) {
        throw "Erreur: Le paramètre OU est obligatoire."
    }

    # Utiliser un mot de passe par défaut si aucun n'est fourni
    if (-not $Password) {
        $Password = ConvertTo-SecureString "TempP@ssw0rd123456!" -AsPlainText -Force
        $logMessage += "`n`n Aucun mot de passe spécifié pour l'utilisateur $Prenom $Nom. Utilisation du mot de passe par défaut."
    }

    # Vérifier la présence de Département
    if (-not $Departement) {
        $Departement = "Utilisateurs"
        $logMessage += "`n`n Aucun département spécifié pour l'utilisateur $Prenom $Nom. Attribution par défaut au département 'Utilisateurs'."
    }

    # Vérifier la présence de Manager
    if (-not $Manager) {
        $Manager = "manager"
        $logMessage += "`n`nAucun manager spécifié pour l'utilisateur $Prenom $Nom. Assignation par défaut au manager 'manager'."
    }

    # Vérifier la présence de Titre
    if (-not $Titre) {
        $Titre = ""
        $logMessage += "`n`n Aucun titre spécifié pour l'utilisateur $Prenom $Nom. Le champ titre sera laissé vide."
    }

    # Vérifier la présence de Groupe
    if (-not $Groupe) {
        $Groupe = "GRP_Tous_Utilisateurs"
        $logMessage += "`n`n Aucun groupe spécifié pour l'utilisateur $Prenom $Nom. L'utilisateur sera ajouté au groupe par défaut 'GRP_Tous_Utilisateurs'."
    }

    # Vérifier que l'utilisateur n'existe pas déjà
    $userExists = Get-ADUser -Filter "SamAccountName -eq '$Login'" -ErrorAction SilentlyContinue
    if ($userExists) {
        throw "Erreur: L'utilisateur '$Login' existe déjà dans Active Directory."
    }

    # Vérifier que l'UPN n'existe pas déjà
    $dnsRoot = (Get-ADDomain).DNSRoot
    $upn = "$Login@$dnsRoot"
    $upnExists = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -ErrorAction SilentlyContinue
    if ($upnExists) {
        throw "Erreur: L'UPN '$upn' existe déjà dans Active Directory."
    }
    
    # Extraire le nom de l'OU (ex: de "OU=Developpement" ou "OU=Developpement,OU=Informatique" extraire "Developpement")
    $ouName = $OU -replace "^OU=", "" -replace ",OU=.*", "" -replace ",DC=.*", ""
    
    # Chercher l'OU par son nom dans toute l'arborescence
    $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchScope Subtree -ErrorAction SilentlyContinue

    # Si il y a plusieurs OUs avec le même nom, demander à l'utilisateur de choisir laquelle il veut utiliser
    if ($ouExists.Count -gt 1) {
        Write-Host "Plusieurs OUs nommées '$ouName' ont été trouvées. Veuillez choisir celle à utiliser :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ouExists.Count; $i++) {
            Write-Host "[$i] $($ouExists[$i].DistinguishedName)"
        }
        $choice = Read-Host "Entrez le numéro correspondant à l'OU souhaitée"
        if ($choice -ge 0 -and $choice -lt $ouExists.Count) {
            $fullOU = $ouExists[$choice].DistinguishedName
        } else {
            throw "Erreur: Choix invalide. Opération annulée."
        }
    } else {
        if ($ouExists) {
            $fullOU = $ouExists.DistinguishedName
        } else {
            throw "Erreur: L'OU '$ouName' n'existe pas dans Active Directory."
        }
    }
        
    $logMessage += "`n`nChemin complet de l'OU: $fullOU"

    # Vérifier que le manager existe si un manager est spécifié
    $managerExists = Get-ADUser -Filter "SamAccountName -eq '$Manager'" -ErrorAction SilentlyContinue
    if (-not $managerExists) {
        throw "Erreur: Le manager '$Manager' n'existe pas dans Active Directory."
    }

    # Vérifier que les groupes existent, sinon utiliser GRP_Tous_Utilisateurs
    $groupList = $Groupe -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    $validGroups = @()
    foreach ($group in $groupList) {
        $groupExists = Get-ADGroup -Filter "SamAccountName -eq '$($group.Trim())'" -ErrorAction SilentlyContinue
        if (-not $groupExists) {
            Write-Host "Avertissement: Le groupe '$($group.Trim())' n'existe pas. L'utilisateur sera ajouté au groupe 'GRP_Tous_Utilisateurs'." -ForegroundColor Yellow
            $logMessage += "`nAvertissement: Le groupe '$($group.Trim())' n'existe pas. L'utilisateur a été ajouté au groupe 'GRP_Tous_Utilisateurs'."
            $validGroups += 'GRP_Tous_Utilisateurs'
        } else {
            $validGroups += $group.Trim()
        }
    }
    $Groupe = ($validGroups | Select-Object -Unique) -join ','

    # Créer le nouvel utilisateur dans Active Directory
    New-ADUser `
        -GivenName $Prenom `
        -Surname $Nom `
        -Name "$Prenom $Nom" `
        -SamAccountName $Login `
        -UserPrincipalName "$Login@$(Get-ADDomain).DNSRoot" `
        -EmailAddress $Email `
        -Title $Titre `
        -Path $fullOU `
        -AccountPassword $Password `
        -Enabled $Enable `
        -ChangePasswordAtLogon $true `
        -Manager $Manager `
        -Department $Departement

    $logMessage += "`nUtilisateur '$Prenom $Nom' créé avec succès dans Active Directory avec les informations suivantes :"
    $logMessage += "`nPrénom: $Prenom"
    $logMessage += "`nNom: $Nom"
    $logMessage += "`nLogin: $Login"
    $logMessage += "`nE-mail: $Email"
    $logMessage += "`nTitre: $Titre"
    $logMessage += "`nDépartement: $Departement"
    if ($Manager) {
        $logMessage += "`nManager: $Manager"
    } else {
        $logMessage += "`nManager: (non spécifié)"
    }
    $logMessage += "`nGroupe(s): $Groupe"
    $logMessage += "`nOU: $fullOU"
    $logMessage += "`nActivé: $Enable"
    
    # Ajouter l'utilisateur aux groupes spécifiés
    add_user_to_groups -Login $Login -Groupe $Groupe -LogFile $LogFile
    
    # Envoyer l'email de bienvenue
    send_welcome_email -Prenom $Prenom -Nom $Nom -Login $Login -Email $Email -Titre $Titre -Departement $Departement -Manager $Manager -LogFile $LogFile
    
    # Enregistrer le message final dans le log
    log_message -Message $logMessage -LogFile $LogFile
    
    return $logMessage
    return $Password
}

Function verify_and_create_OU {
    param (
        [string]$OU
    )
    # Extraire le nom simple de l'OU (sans "OU=" et sans le DN complet)
    $ouName = $OU -replace '^OU=','' -replace ',.*',''
    
    # Chercher l'OU par son nom dans toute l'arborescence
    $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchScope Subtree -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $ouExists) {
        Write-Host "L'OU '$ouName' n'existe pas. Voulez-vous la créer ? (O/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -ne 'O' -and $response -ne 'o') {
            Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Création de l'OU '$ouName'..." -ForegroundColor Yellow
            try {
                New-ADOrganizationalUnit -Name $ouName -Path (Get-ADDomain).DistinguishedName
                Write-Host "Unité organisationnelle '$ouName' créée avec succès." -ForegroundColor Green
            }
            catch {
                Write-Host "L'OU '$ouName' existe déjà." -ForegroundColor Blue
            }
        }
    }
}

# Si un fichier CSV est spécifié, créer des utilisateurs à partir du fichier
if ($FilePath) {
    # Créer des utilisateurs à partir d'un fichier CSV
    if (-not (Test-Path $FilePath)) {
        Write-Host "Erreur: Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }
    
    # Verfier que le fichier contient les colonnes nécessaires
    $requiredColumns = @("Prenom", "Nom", "Login", "Email", "OU")
    $csvHeader = (Get-Content -Path $FilePath -First 1).Split(',')
    foreach ($col in $requiredColumns) {
        if ($csvHeader -notcontains $col) {
            Write-Host "Erreur: La colonne '$col' est manquante dans le fichier CSV." -ForegroundColor Red
            exit 1
        }
        else {
            $containedColumns = $true
        }
    }

    if (-not $containedColumns) {
        exit 1
    }
    else {
        $users = Import-Csv -Path $FilePath -Delimiter ','
        $successCount = 0
        $errorCount = 0
        
        foreach ($user in $users) {
            $prenom = $user.Prenom.Trim()
            $nom = $user.Nom.Trim()
            $login = $user.Login.Trim()
            $email = $user.Email.Trim()
            $titre = if ($user.Titre) { $user.Titre.Trim() } else { $null }
            $departement = if ($user.Departement) { $user.Departement.Trim() } else { $null }
            $manager = if ($user.Manager) { $user.Manager.Trim() } else { $null }
            $groupe = if ($user.Groupe) { $user.Groupe.Trim() } else { $null }
            $ou = if ($user.OU) { $user.OU.Trim() } else { $null }
            $password = $user.Password

            # Générer l'OU à partir du département si non spécifiée
            if (-not $ou -and $departement) {
                $ouGenerated = get_OU_by_department -Departement $departement
                if ($ouGenerated) {
                    $ou = $ouGenerated
                }
            }

            # Générer le groupe à partir du département si non spécifié
            if (-not $groupe -and $departement) {
                $groupeGenerated = get_group_by_department -Departement $departement
                if ($groupeGenerated) {
                    $groupe = $groupeGenerated
                }
            }

            if (-not $password) {
                $password = ConvertTo-SecureString "TempP@ssw0rd123456!" -AsPlainText -Force 
            } else {
                $password = ConvertTo-SecureString $password -AsPlainText -Force
            }

            # Créer le fichier de log pour cet utilisateur
            $logFile = define_logfile -Prenom $prenom -Nom $nom
            log_message -Message "Script démarré pour $prenom $nom" -LogFile $logFile

            # Vérifier et créer l'OU si nécessaire
            verify_and_create_OU -OU $ou

            # Construire les paramètres dynamiquement
            $params = @{
                Prenom = $prenom
                Nom = $nom
                Login = $login
                Email = $email
                OU = $ou
                Password = $password
                Enable = $Enable
                LogFile = $logFile
            }
            if ($titre) { $params['Titre'] = $titre }
            if ($departement) { $params['Departement'] = $departement }
            if ($manager) { $params['Manager'] = $manager }
            if ($groupe) { $params['Groupe'] = $groupe }

            try {
                create_AD_user @params
                
                Write-Host "'$prenom $nom' créé." -ForegroundColor Green
                log_message -Message "Utilisateur '$prenom $nom' créé avec succès." -LogFile $logFile
                $successCount++
            }
            catch {
                Write-Host "Erreur pour '$prenom $nom': $_" -ForegroundColor Red
                log_message -Message "Erreur lors de la création de '$prenom $nom': $_" -LogFile $logFile
                $errorCount++
            }
            finally {
                log_message -Message "Script terminé pour $prenom $nom" -LogFile $logFile
            }
        }
        
        # Afficher un résumé final
        if ($successCount -gt 0) {
            Write-Host "`nRésumé: $successCount utilisateur(s) créé(s) avec succès" -ForegroundColor Green
        }
        if ($errorCount -gt 0) {
            Write-Host "$errorCount utilisateur(s) en erreur" -ForegroundColor Red
        }
    }
}
else { #Sinon, créer un seul utilisateur avec les paramètres fournis
    if (-not $Prenom -or -not $Nom) {
        Write-Host "Erreur: Les paramètres Prenom et Nom sont obligatoires." -ForegroundColor Red
        exit 1
    }

    # Générer le login si non fourni (première lettre du prénom + nom)
    if (-not $Login) {
        $Login = (($Prenom.Substring(0, 1)) + $Nom).ToLower()
    }

    # Générer l'email si non fourni
    if (-not $Email) {
        $Email = "$($Prenom.ToLower()).$($Nom.ToLower())@techsecure.com"
    }

    # Générer l'OU à partir du département si non spécifiée
    if (-not $OU -and $Departement) {
        $ouGenerated = get_OU_by_department -Departement $Departement
        if ($ouGenerated) {
            $OU = $ouGenerated
        }
    }

    # Générer le groupe à partir du département si non spécifié
    if (-not $Groupe -and $Departement) {
        $groupeGenerated = get_group_by_department -Departement $Departement
        if ($groupeGenerated) {
            $Groupe = $groupeGenerated
        }
    }

    # Si OU n'est toujours pas définie, utiliser une OU par défaut
    if (-not $OU) {
        $OU = "Utilisateurs"
    }

    # Créer le fichier de log pour cet utilisateur
    $logFile = define_logfile -Prenom $Prenom -Nom $Nom
    log_message -Message "Script démarré pour $Prenom $Nom" -LogFile $logFile

    # Vérifier et créer l'OU si nécessaire
    verify_and_create_OU -OU $OU

    # Utiliser un mot de passe par défaut si aucun n'est fourni
    if (-not $Password) {
        $Password = ConvertTo-SecureString "TempP@ssw0rd123456!" -AsPlainText -Force
    }

    # Construire les paramètres dynamiquement
    $params = @{
        Prenom = $Prenom
        Nom = $Nom
        Login = $Login
        Email = $Email
        OU = $OU
        Password = $Password
        Enable = $Enable
        LogFile = $logFile
    }
    if ($Titre) { $params['Titre'] = $Titre }
    if ($Departement) { $params['Departement'] = $Departement }
    if ($Manager) { $params['Manager'] = $Manager }
    if ($Groupe) { $params['Groupe'] = $Groupe }

    try {
        create_AD_user @params
        
        Write-Host "'$Prenom $Nom' créé avec succès." -ForegroundColor Green
        Write-Host "Login: $Login"
        Write-Host "Email: $Email"
        log_message -Message "Utilisateur '$Prenom $Nom' créé avec succès." -LogFile $logFile
        exit 0
    }
    catch {
        Write-Host "Erreur lors de la création: $_" -ForegroundColor Red
        log_message -Message "Erreur lors de la création: $_" -LogFile $logFile
        exit 1
    }
    finally {
        log_message -Message "Script terminé pour $Prenom $Nom" -LogFile $logFile
    }
}