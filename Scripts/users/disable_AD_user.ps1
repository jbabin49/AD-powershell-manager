<#
.SYNOPSIS
    Désactivation d'utilisateurs dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de désactiver un/des utilisateur(s) spécifique(s) dans Active Directory en utilisant le nom d'utilisateur (login).
.EXAMPLE
    .\disable_AD_user.ps1 -Login "jdoe"
    Exécute le script pour désactiver l'utilisateur avec le login spécifié.
    .\disable_AD_user.ps1 -Login "jdoe, jsmith, mbrown"
    Exécute le script pour désactiver plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules.
.PARAMETER Login
    Le nom d'utilisateur (login) de l'utilisateur à désactiver. (obligatoire)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Login
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Vérifier que le paramètre Login est fourni
if (-not $Login) {
    Write-Host "Le paramètre 'Login' est obligatoire." -ForegroundColor Red
    exit 1
}

#Demander la confirmation avant de désactiver l'utilisateur
$confirmation = Read-Host "Êtes-vous sûr de vouloir désactiver l'utilisateur avec le login '$Login'? (O/N)"
if ($confirmation -ne 'O' -and $confirmation -ne 'o') {
    Write-Host "Opération annulée par l'utilisateur." -ForegroundColor Yellow
    exit 0
}

# Récupérer l'utilisateur
$user = Get-ADUser -Filter {SamAccountName -eq $Login}
# Vérifier si l'utilisateur existe
try {
    if (-not $user) {
        Write-Host "Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
        exit 1
    }

    # Désactiver l'utilisateur
    Disable-ADAccount -Identity $user

    Write-Host "Utilisateur avec le login '$Login' a été désactivé avec succès." -ForegroundColor Green
}
catch {
    Write-Host "Une erreur s'est produite lors de la désactivation de l'utilisateur: $_" -ForegroundColor Red
    exit 1
}