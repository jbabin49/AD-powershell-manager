<#
.SYNOPSIS
    Récupération des informations des groupes dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de récupérer et d'afficher les informations des groupes spécifiques dans Active Directory en utilisant leurs noms.
.EXAMPLE
    .\infos_AD_groups.ps1 -Group "IT_Group"
    Exécute le script pour récupérer les informations du groupe spécifié (nombre de membres, noms des membres avec le titre et les autres groupes dont ils sont membres).
    .\infos_AD_groups.ps1 -Group "IT_Group, HR_Group"
    Exécute le script pour récupérer les informations de plusieurs groupes dont les noms sont spécifiés, séparés par des virgules.
.PARAMETER Group
    Le nom du/des groupe(s) dont les informations doivent être récupérées. (obligatoire)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Group
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Vérifier que le paramètre Group est fourni
if (-not $Group) {
    Write-Host "Le paramètre 'Group' est obligatoire." -ForegroundColor Red
    exit 1
}

# Séparer les groupes si plusieurs sont spécifiés
$Groups = $Group -split ",\s*"
foreach ($grp in $Groups) {
    # Récupérer le groupe
    $groupData = Get-ADGroup -Filter "Name -eq '$($grp.Trim())'"
    if (-not $groupData) {
        Write-Host "Groupe '$grp' non trouvé dans Active Directory." -ForegroundColor Red
        continue
    }

    # Récupérer les membres du groupe
    $members = Get-ADGroupMember -Identity $groupData.DistinguishedName -Recursive

    # Afficher les informations du groupe
    Write-Host "Groupe: $($groupData.Name)" -ForegroundColor Cyan
    Write-Host "Nombre de membres: $($members.Count)" -ForegroundColor Cyan

    foreach ($member in $members) {
        if ($member.objectClass -eq 'user') {
            $user = Get-ADUser -Identity $member.DistinguishedName -Properties Title, MemberOf
            $memberOfGroups = ($user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }) -join ", "
            Write-Host " - Membre: $($user.SamAccountName), Titre: $($user.Title), Groupes: $memberOfGroups"
        } elseif ($member.objectClass -eq 'group') {
            Write-Host " - Membre: $($member.Name) (Groupe)"
        }
    }
    Write-Host "`n"
}