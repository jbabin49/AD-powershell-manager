<#
.SYNOPSIS
    Suppression d'un utilisateur dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de supprimer un utilisateur spécifique dans Active Directory en utilisant son nom d'utilisateur (login).
.EXAMPLE
    .\delete_AD_user.ps1 -Login "jdoe"
    Exécute le script pour supprimer l'utilisateur avec le login spécifié.
    .\delete_AD_user.ps1 -Login "jdoe, jsmith, mbrown"
    Exécute le script pour supprimer plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules.
.PARAMETER Login
    Le nom d'utilisateur (login) de l'utilisateur à supprimer. (obligatoire)
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

#Demander la confirmation avant de supprimer l'utilisateur
$confirmation = Read-Host "Êtes-vous sûr de vouloir supprimer l'utilisateur avec le login '$Login'? (O/N)"
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

    # Supprimer l'utilisateur
    Remove-ADUser -Identity $user

    Write-Host "Utilisateur avec le login '$Login' a été supprimé avec succès." -ForegroundColor Green
}
catch {
    Write-Host "Une erreur s'est produite lors de la suppression de l'utilisateur: $_" -ForegroundColor Red
    exit 1
}