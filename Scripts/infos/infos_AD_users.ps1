<#
.SYNOPSIS
    Collecte et affiche des informations sur les utilisateurs dans Active Directory.
.DESCRIPTION
    Ce script PowerShell récupère et affiche diverses informations sur les utilisateurs dans Active Directory, telles que les noms, les adresses e-mail, les départements et les statuts des comptes.
.EXAMPLE
    .\infos_user.ps1 -Names "John,Doe,Jane"
    Exécute le script et affiche les informations des utilisateurs dans Active Directory.
    .\infos_user.ps1 -Names *
    Exécute le script et affiche les informations de tous les utilisateurs dans Active Directory.
    .\infos_user.ps1 -Login "jdoe,asmith"
    Exécute le script et affiche les informations des utilisateurs avec les logins spécifiés dans Active Directory.
    .\infos_user.ps1 -Login "*"
    Exécute le script et affiche les informations de tous les utilisateurs dans Active Directory.
    .\infos_user.ps1 -FirstLetter "J, B"
    Exécute le script et affiche les informations des utilisateurs dont le nom commence par la lettre spécifiée.
    .\infos_user.ps1 -Titre "Administrateur"
    Exécute le script et affiche les informations des utilisateurs avec le mot spécifié dans leur titre dans Active Directory.
    .\infos_user.ps1 -Count
    Exécute le script et affiche le nombre total d'utilisateurs dans Active Directory.
.PARAMETER Names
    Une liste de noms d'utilisateurs séparés par des virgules pour lesquels récupérer les informations.
    Ou * pour tous les utilisateurs.
.PARAMETER Login
    Une liste de logins d'utilisateurs séparés par des virgules pour lesquels récupérer les informations.
    Ou * pour tous les utilisateurs.
.PARAMETER FirstLetter
    La première lettre des noms d'utilisateurs pour lesquels récupérer les informations.
.PARAMETER Titre
    Un mot ou une phrase dans le titre des utilisateurs pour lesquels récupérer les informations.
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Names,
    [string]$Login,
    [string]$FirstLetter,
    [string]$Titre,
    [switch]$Count
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Convertir la chaîne de noms en tableau
$nameArray = $Names -split ','

# Récupérer les informations des utilisateurs spécifiés
if ($Names) {
    if ($Names -eq '*') {
        $users = Get-ADUser -Filter * -Properties Name, EmailAddress, Title, Enabled, MemberOf | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
    }
    elseif ($Names -and $Names -ne '*') {
        $users = @()
        foreach ($name in $nameArray) {
            $user = Get-ADUser -Filter {Name -like $name} -Properties Name, EmailAddress, Title, Enabled, MemberOf | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
            if ($user) {
                $users += $user
            } else {
                Write-Host "Utilisateur '$name' non trouvé dans Active Directory." -ForegroundColor Red
            }
        }
    }
}
elseif ($Login) {
    if ($Login -eq '*') {
        $users = Get-ADUser -Filter * -Properties Name, EmailAddress, Title, Enabled | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
    }
    elseif ($Login -and $Login -ne '*') {
        $loginArray = $Login -split ','
        $users = @()
        foreach ($login in $loginArray) {
            $user = Get-ADUser -Filter {SamAccountName -eq $login} -Properties Name, EmailAddress, Title, Enabled, MemberOf | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
            if ($user) {
                $users += $user
            } else {
                Write-Host "Utilisateur avec le login '$login' non trouvé dans Active Directory." -ForegroundColor Red
            }
        }
    }
}
elseif ($FirstLetter) {
    $firstLetterArray = $FirstLetter -split ','
    $users = @()
    foreach ($letter in $firstLetterArray) {
        $letter = $letter.Trim()
        $filteredUsers = Get-ADUser -Filter "Surname -like '$letter*'" -Properties Name, EmailAddress, Title, Enabled, MemberOf | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
        if ($filteredUsers) {
            $users += $filteredUsers
        } else {
            Write-Host "Aucun utilisateur trouvé dont le nom commence par '$letter' dans Active Directory." -ForegroundColor Red
        }
    }
}
elseif ($Titre) {
    $titre = $Titre.Trim()
    $users = Get-ADUser -Filter "Title -like '*$titre*'" -Properties Name, EmailAddress, Title, Enabled, MemberOf | Select-Object -Property Name, EmailAddress, Title, Enabled, MemberOf
    if (-not $users) {
        Write-Host "Aucun utilisateur trouvé avec le titre contenant '$titre' dans Active Directory." -ForegroundColor Red
    }
}
elseif ($Count) {
    $userCount = (Get-ADUser -Filter *).Count
    $activeUserCount = (Get-ADUser -Filter {Enabled -eq $true}).Count
    $disabledUserCount = (Get-ADUser -Filter {Enabled -eq $false}).Count
    Write-Host "Nombre total d'utilisateurs dans Active Directory: $userCount" -ForegroundColor Cyan
    Write-Host "Nombre d'utilisateurs actifs: $activeUserCount" -ForegroundColor Green
    Write-Host "Nombre d'utilisateurs désactivés: $disabledUserCount" -ForegroundColor Red
    exit 0
}
else {
    Write-Host "Veuillez spécifier soit le paramètre 'Names' soit le paramètre 'Login'." -ForegroundColor Yellow
    exit 1
}

# Afficher les informations des utilisateurs
Write-Host "Informations des Utilisateurs dans Active Directory:" -ForegroundColor Cyan
Format-Table -InputObject $users -AutoSize

# Affichage dans une fenêtre graphique pour une meilleure lisibilité
#$users | Out-GridView -Title "Informations des Utilisateurs dans Active Directory"