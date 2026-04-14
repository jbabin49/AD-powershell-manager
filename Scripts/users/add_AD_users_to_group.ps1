<#
.SYNOPSIS
    Ajout d'utilisateurs à un groupe dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet d'ajouter un ou plusieurs utilisateurs à un ou plusieurs groupes de sécurité spécifiques dans Active Directory en utilisant leurs noms d'utilisateur (logins).
    Il permet aussi d'ajouter les utilisateurs à des groupes à partir d'un fichier CSV.
    Il permet également d'ajouter les utilisateurs d'un groupe source à un groupe cible.
.EXAMPLE
    .\add_AD_users_to_group.ps1 -Login "jdoe" -Group "IT_Group"
    Exécute le script pour ajouter l'utilisateur avec le login spécifié au groupe spécifié
    .\add_AD_users_to_group.ps1 -Login "jdoe, jsmith" -Group "IT_Group, HR_Group"
    Exécute le script pour ajouter plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules, aux groupes spécifiés, séparés par des virgules.
    .\add_AD_users_to_group.ps1 -FilePath "C:\users_to_add.csv" -Group "IT_Group" <- facultatif si les groupes sont spécifiés dans le fichier CSV
    Exécute le script et ajoute les utilisateurs à partir d'un fichier CSV. Le fichier doit contenir au moins la colonne: Login (Group est facultatif si le paramètre Group est spécifié).
    .\add_AD_users_to_group.ps1 -SourceGroup "Source_Group" -TargetGroup "New_Group"
    Exécute le script pour ajouter tous les utilisateurs du groupe source au groupe cible.
    .\add_AD_users_to_group.ps1 -SourceGroup "Source_Group, Source_Group2" -TargetGroup "New_Group"
    Exécute le script pour ajouter tous les utilisateurs de plusieurs groupes source au groupe cible.
    .\add_AD_users_to_group.ps1 -SourceGroup "Source_Group" -TargetGroup "New_Group1, New_Group2"
    Exécute le script pour ajouter tous les utilisateurs du groupe source à plusieurs groupes cibles
.PARAMETER Login
    Le nom d'utilisateur (login) de l'/des utilisateur(s) à ajouter aux groupes. (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Group
    Le(s) groupe(s) de sécurité auquel/auxquels ajouter l'/les utilisateur(s). (obligatoire si FilePath n'est pas spécifié, facultatif si les groupes sont spécifiés dans le fichier CSV)
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les utilisateurs à ajouter aux groupes. Le fichier doit avoir au moins la colonne: Login (Group est facultatif si le paramètre Group est spécifié).
.PARAMETER SourceGroup
    Le groupe source dont les utilisateurs seront ajoutés au groupe cible. (obligatoire si TargetGroup est spécifié)
.PARAMETER TargetGroup
    Le groupe cible auquel les utilisateurs du groupe source seront ajoutés. (obligatoire si SourceGroup est spécifié)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Login,
    [string]$Group,
    [string]$FilePath,
    [string]$SourceGroup,
    [string]$TargetGroup
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function add_user_to_groups {
    param (
        [string]$UserLogin,
        [string[]]$Groups
    )

    # Séparer les groupes si plusieurs sont spécifiés
    $Groups = $Groups -split ",\s*"

    # Récupérer l' utilisateur
    $user = Get-ADUser -Filter {SamAccountName -eq $UserLogin}
    if (-not $user) {   
        Write-Host "Utilisateur avec le login '$UserLogin' non trouvé dans Active Directory." -ForegroundColor Red
        exit 1
    }

    foreach ($groupName in $Groups) {
        # Récupérer le(s) groupe(s)
        $group = Get-ADGroup -Identity $groupName
        if (-not $group) {   
            Write-Host "Groupe '$groupName' non trouvé dans Active Directory." -ForegroundColor Red
            continue
        }

        try {
            # Ajouter l'utilisateur au groupe
            Add-ADGroupMember -Identity $group -Members $user
            Write-Host "Utilisateur '$UserLogin' ajouté au groupe '$groupName' avec succès." -ForegroundColor Green
        }
        catch {
            Write-Host "Une erreur s'est produite lors de l'ajout de l'utilisateur '$UserLogin' au groupe '$groupName': $_" -ForegroundColor Red
        }
    }
}

# Ajouter des utilisateurs à partir d'un fichier CSV
if ($FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Host "Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }

    $csvData = Import-Csv -Path $FilePath
    foreach ($entry in $csvData) {
        $userLogin = $entry.Login
        $groups = $Group
        if ($entry.PSObject.Properties.Name -contains 'Group' -and $entry.Group) {
            $groups = $entry.Group
        }
        add_user_to_groups -UserLogin $userLogin -Groups $groups
    }
} elseif ($Login -and $Group) {
    $userLogins = $Login -split ",\s*"
    $groups = $Group
    foreach ($userLogin in $userLogins) {
        add_user_to_groups -UserLogin $userLogin -Groups $groups
    }
} elseif ($SourceGroup -and $TargetGroup) {
    # Faire un tableau des groupes source et cible
    $sourceGroups = $SourceGroup -split ",\s*"
    $targetGroups = $TargetGroup -split ",\s*"

    # Récupérer les utilisateurs de chaque groupe source
    foreach ($srcGroup in $sourceGroups) {
        $sourceGroup = Get-ADGroup -Identity $srcGroup
        if (-not $sourceGroup) {
            Write-Host "Groupe source '$srcGroup' non trouvé dans Active Directory." -ForegroundColor Red
            continue
        }

        # Ajouter chaque utilisateur du groupe source aux groupes cibles
        $members = Get-ADGroupMember -Identity $sourceGroup -Recursive | Where-Object { $_.objectClass -eq 'user' }
        foreach ($member in $members) {
            foreach ($tgtGroup in $targetGroups) {
                $targetGroup = Get-ADGroup -Identity $tgtGroup
                if (-not $targetGroup) {
                    Write-Host "Groupe cible '$tgtGroup' non trouvé dans Active Directory." -ForegroundColor Red
                    continue
                }
                try {
                    Add-ADGroupMember -Identity $targetGroup -Members $member
                    Write-Host "Utilisateur '$($member.SamAccountName)' ajouté au groupe '$tgtGroup' avec succès." -ForegroundColor Green
                }
                catch {
                    Write-Host "Une erreur s'est produite lors de l'ajout de l'utilisateur '$($member.SamAccountName)' au groupe '$tgtGroup': $_" -ForegroundColor Red
                }
            }
        }
    }
} else {
    Write-Host "Les paramètres requis ne sont pas fournis. Veuillez spécifier soit 'Login' et 'Group', soit 'FilePath', soit 'SourceGroup' et 'TargetGroup'." -ForegroundColor Red
    exit 1
}