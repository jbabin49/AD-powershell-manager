<#
.SYNOPSIS
    Modification de l'OU d'un utilisateur dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de modifier l'Unité d'Organisation (OU) d'un utilisateur dans Active Directory en le déplaçant vers une nouvelle OU spécifiée.
.EXAMPLE
    .\modify_AD_user_OU.ps1 -Login "jdoe" -NewOU "Service_IT"
    Exécute le script pour déplacer l'utilisateur avec le login spécifié vers la nouvelle OU.

    .\modify_AD_user_OU.ps1 -Login "jdoe, jsmith" -NewOU "Service_IT"
    Exécute le script pour déplacer plusieurs utilisateurs avec les logins spécifiés vers la nouvelle OU.

    .\modify_AD_user_OU.ps1 -FilePath "C:\users_move.csv"
    Exécute le script et déplace tous les utilisateurs vers leurs nouvelles OUs à partir d'un fichier CSV. 
    Le fichier doit avoir les colonnes: Login, NewOU.
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les utilisateurs à déplacer. 
    Le fichier doit avoir les colonnes: Login, NewOU. (facultatif si Login et NewOU sont spécifiés)
.PARAMETER Login
    Le(s) nom(s) d'utilisateur (login) de l'utilisateur à déplacer. 
    Pour plusieurs utilisateurs, séparer les logins par des virgules. (obligatoire si FilePath n'est pas spécifié)
.PARAMETER NewOU
    La nouvelle Unité d'Organisation (OU) vers laquelle déplacer l'utilisateur. (obligatoire si FilePath n'est pas spécifié)
.NOTES
    Auteur: Julien BABIN
    Date de création: 31/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$FilePath,
    [string]$Login,
    [string]$NewOU
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Fonction pour déplacer un utilisateur vers une nouvelle OU
Function move_AD_user {
    param (
        [string]$Login,
        [string]$NewOU
    )

    # Récupérer l'utilisateur
    $user = Get-ADUser -Filter {SamAccountName -eq $Login}
    # Vérifier si l'utilisateur existe
    if (-not $user) {
        Write-Host "Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
        return
    }

    #Vérifier si la nouvelle OU existe en cherchant par nom d'OU
    $domainDN = (Get-ADDomain).DistinguishedName
    
    # Extraire le nom de l'OU (la partie avant la première virgule si c'est un chemin)
    $ouName = $NewOU -replace "^OU=", "" -replace ",.*$", ""
    
    # Rechercher l'OU par son nom dans l'arborescence du domaine
    $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domainDN -SearchScope Subtree -ErrorAction SilentlyContinue

    # Vérifier si l'OU existe
    if (-not $ouExists) {
        Write-Host "L'OU '$NewOU' spécifiée n'existe pas dans Active Directory." -ForegroundColor Red
        return
    } elseif ($ouExists -is [array]) {
        # S'il y a plusieurs OUs avec le même nom, demander à l'utilisateur de choisir
        Write-Host "`nPlusieurs OUs avec le nom '$ouName' ont été trouvées:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ouExists.Count; $i++) {
            Write-Host "$($i + 1). $($ouExists[$i].DistinguishedName)" -ForegroundColor Cyan
        }
        
        # Demander à l'utilisateur de sélectionner une OU
        $validSelection = $false
        while (-not $validSelection) {
            $choice = Read-Host "Veuillez sélectionner le numéro de l'OU à utiliser (1-$($ouExists.Count))"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $ouExists.Count) {
                $newOUPath = $ouExists[[int]$choice - 1].DistinguishedName
                $validSelection = $true
                Write-Host "OU sélectionnée: $newOUPath" -ForegroundColor Green
            } else {
                Write-Host "Sélection invalide. Veuillez entrer un numéro entre 1 et $($ouExists.Count)." -ForegroundColor Red
            }
        }
    } else {
        $newOUPath = $ouExists.DistinguishedName
    }

    # Déplacer l'utilisateur vers la nouvelle OU
    try {
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $newOUPath
        Write-Host "Utilisateur '$Login' déplacé vers l'OU '$newOUPath' avec succès." -ForegroundColor Green
    } catch {
        Write-Host "Erreur lors du déplacement de l'utilisateur '$Login': $_" -ForegroundColor Red
    }
}

# Si un fichier CSV est spécifié, déplacer les utilisateurs à partir du fichier
if ($FilePath) {
    if (-Not (Test-Path $FilePath)) {
        Write-Host "Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }

    # Importer les utilisateurs à partir du fichier CSV
    $userList = Import-Csv -Path $FilePath

    # Vérifier que les colonnes Login et NewOU existent dans le CSV
    if (-not $userList | Where-Object { $_.Login -and $_.NewOU }) {
        Write-Host "Le fichier CSV doit contenir les colonnes 'Login' et 'NewOU'." -ForegroundColor Red
        exit 1
    }

    # Si les deux colonnes Login et NewOU sont présentes
    if ($userList.Login -and $userList.NewOU) {
        # Vérifier que chaque entrée a les deux colonnes
        foreach ($entry in $userList) {
            if (-not $entry.Login -or -not $entry.NewOU) {
                Write-Host "Chaque entrée du fichier CSV doit contenir à la fois 'Login' et 'NewOU'." -ForegroundColor Red
                exit 1
            }
        }
        # Déplacer les utilisateurs vers leurs nouvelles OU respectives
        foreach ($user in $userList) {
            $login = $user.Login
            $newOU = $user.NewOU
            move_AD_user -Login $login -NewOU $newOU
        }
    # Si seule la colonne Login est présente
    } elseif ($userList.Login -and -not $userList.NewOU) {
        # Vérifier que le paramètre NewOU est fourni
        if (-not $NewOU) {
            Write-Host "Le paramètre 'NewOU' est obligatoire lorsque le fichier CSV ne contient pas la colonne 'NewOU'." -ForegroundColor Red
            exit 1
        }
        # Déplacer les utilisateurs vers la nouvelle OU spécifiée
        foreach ($user in $userList) {
            $login = $user.Login
            move_AD_user -Login $login -NewOU $NewOU
        }
    }
# Si les paramètres Login et NewOU sont spécifiés
} elseif ($Login -and $NewOU) {
    # Traiter plusieurs logins séparés par des virgules
    $logins = $Login -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($singleLogin in $logins) {
        move_AD_user -Login $singleLogin -NewOU $NewOU
    }
} else {
    Write-Host "Veuillez spécifier soit le paramètre 'FilePath', soit les paramètres 'Login' et 'NewOU'." -ForegroundColor Red
    exit 1
}