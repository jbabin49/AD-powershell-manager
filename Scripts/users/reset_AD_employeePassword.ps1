<#
.SYNOPSIS
    Réinitialise le mot de passe d'un employé dans Active Directory.
.DESCRIPTION
    Ce script réinitialise le mot de passe d'un utilisateur Active Directory en générant un nouveau mot de passe aléatoire sécurisé.
    Il force l'utilisateur à changer son mot de passe à la prochaine connexion et déverrouille le compte si nécessaire.
    Le nouveau mot de passe est affiché pour transmission sécurisée.
.EXAMPLE
    .\reset_AD_employeePassword.ps1 -Login "jdoe"
    Réinitialise le mot de passe de l'utilisateur "jdoe" et affiche le nouveau mot de passe.

    .\reset_AD_employeePassword.ps1 -Login "jdoe" -LogFilePath "C:\Logs\password_reset.log"
    Réinitialise le mot de passe et enregistre l'action dans le fichier journal spécifié.
.PARAMETER Login
    Le login (SamAccountName) de l'employé dont réinitialiser le mot de passe. (obligatoire)
.PARAMETER LogFilePath
    Le chemin du fichier journal où les actions seront enregistrées. (facultatif)
    Par défaut, un fichier journal est créé dans le répertoire "C:\logs\password_reset".
.NOTES
    Auteur: Julien Babin
    Date de création: 02/02/2026
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
    if (-not $LogFilePath) {
        return
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Add-Content -Path $LogFilePath -Value $logEntry
}

Function generate_SecurePassword {
    param (
        [int]$Length = 14
    )
    
    $uppercase = @('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z')
    $lowercase = @('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z')
    $numbers = @('0','1','2','3','4','5','6','7','8','9')
    $special = @('!','@','#','$','%','&','*','+','=','?')
    
    $password = @()
    
    # Garantir au moins un caractère de chaque type
    $password += $uppercase | Get-Random
    $password += $lowercase | Get-Random
    $password += $numbers | Get-Random
    $password += $special | Get-Random
    
    # Compléter le reste du mot de passe aléatoirement
    $allChars = $uppercase + $lowercase + $numbers + $special
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars | Get-Random
    }
    
    # Mélanger les caractères
    $password = $password | Sort-Object { Get-Random }
    
    return -join $password
}

Function Reset-EmployeePassword {
    param (
        [string]$Login,
        [string]$LogFilePath
    )

    # Récupérer l'utilisateur AD
    $user = Get-ADUser -Filter { SamAccountName -eq $Login } -Properties DisplayName, GivenName, Surname, LockedOut, Enabled -ErrorAction SilentlyContinue

    if (-not $user) {
        Write-Host "Erreur: Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
        log_Action -Message "Tentative de réinitialisation du mot de passe de '$Login' - Utilisateur non trouvé." -LogFilePath $LogFilePath
        return
    }

    # Afficher les informations de l'utilisateur
    $displayName = if ($user.DisplayName) { $user.DisplayName } else { "$($user.GivenName) $($user.Surname)" }
    Write-Host "`nUtilisateur trouvé: $displayName" -ForegroundColor Cyan
    Write-Host "Statut: $(if ($user.Enabled) { 'Activé' } else { 'Désactivé' })" -ForegroundColor $(if ($user.Enabled) { 'Green' } else { 'Yellow' })
    Write-Host "Verrouillé: $(if ($user.LockedOut) { 'Oui' } else { 'Non' })" -ForegroundColor $(if ($user.LockedOut) { 'Red' } else { 'Green' })
    
    # Demander confirmation
    $confirmation = Read-Host "`nÊtes-vous sûr de vouloir réinitialiser le mot de passe (y/n)?"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
        return
    }

    try {
        # Générer un nouveau mot de passe sécurisé
        Write-Host "`nGénération du nouveau mot de passe..." -ForegroundColor Yellow
        $newPassword = generate_SecurePassword -Length 14
        $securePassword = ConvertTo-SecureString -AsPlainText $newPassword -Force

        # Réinitialiser le mot de passe
        Set-ADAccountPassword -Identity $user.SamAccountName -NewPassword $securePassword -Reset -ErrorAction Stop
        log_Action -Message "Mot de passe réinitialisé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath
        Write-Host "Mot de passe réinitialisé avec succès." -ForegroundColor Green

        # Forcer le changement à la prochaine connexion
        Set-ADUser -Identity $user.SamAccountName -ChangePasswordAtLogon $true -ErrorAction Stop
        log_Action -Message "Changement de mot de passe à la prochaine connexion activé pour '$Login'." -LogFilePath $LogFilePath
        Write-Host "Changement de mot de passe à la prochaine connexion: Activé" -ForegroundColor Green

        # Déverrouiller le compte si verrouillé
        if ($user.LockedOut) {
            Write-Host "`nDéverrouillage du compte..." -ForegroundColor Yellow
            Unlock-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
            log_Action -Message "Compte déverrouillé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath
            Write-Host "Compte déverrouillé avec succès." -ForegroundColor Green
        }

        # Activer le compte si désactivé
        if (-not $user.Enabled) {
            Write-Host "Activation du compte..." -ForegroundColor Yellow
            Enable-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
            log_Action -Message "Compte activé pour l'utilisateur '$Login'." -LogFilePath $LogFilePath
            Write-Host "Compte activé avec succès." -ForegroundColor Green
        }

        # Afficher le nouveau mot de passe
        Write-Host "`n"
        Write-Host ("="*60) -ForegroundColor Cyan
        Write-Host "     NOUVEAU MOT DE PASSE À COMMUNIQUER À L'UTILISATEUR" -ForegroundColor Yellow
        Write-Host ("="*60) -ForegroundColor Cyan
        Write-Host "`nUtilisateur: $displayName" -ForegroundColor White
        Write-Host "Login: $Login" -ForegroundColor White
        Write-Host "Nouveau mot de passe: $newPassword" -ForegroundColor Green -BackgroundColor Black
        Write-Host "`nCe mot de passe doit être changé à la première connexion." -ForegroundColor Yellow
        Write-Host ("="*60) -ForegroundColor Cyan
        Write-Host "`n"

        log_Action -Message "Réinitialisation du mot de passe complétée pour l'utilisateur '$displayName' (Login: $Login). Nouveau mot de passe: $newPassword" -LogFilePath $LogFilePath
        
    } catch {
        Write-Host "Erreur lors de la réinitialisation du mot de passe: $_" -ForegroundColor Red
        log_Action -Message "Erreur lors de la réinitialisation du mot de passe de '$Login': $_" -LogFilePath $LogFilePath
        throw
    }
}

# Valider les paramètres obligatoires
if (-not $Login) {
    Write-Host "Erreur: Le paramètre Login est obligatoire." -ForegroundColor Red
    Write-Host "`nUtilisation: .\Reset-EmployeePassword.ps1 -Login 'nomutilisateur'" -ForegroundColor Yellow
    exit 1
}

# Initialiser le fichier log si non fourni
if (-not $LogFilePath) {
    $logDir = "C:\logs\password_reset"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $LogFilePath = Join-Path -Path $logDir -ChildPath "password_reset_$dateStr.log"
}

# Exécuter la réinitialisation du mot de passe avec gestion d'erreur
try {
    Reset-EmployeePassword -Login $Login -LogFilePath $LogFilePath
    exit 0
} catch {
    Write-Host "Erreur critique: $_" -ForegroundColor Red
    exit 1
}
