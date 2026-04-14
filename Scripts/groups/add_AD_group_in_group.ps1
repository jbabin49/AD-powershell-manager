<#
.SYNOPSIS
    Ajoute un/des groupe(s) Active Directory en tant que membre(s) d'un/d' autre(s) groupe(s) AD.
.DESCRIPTION
    Ce script permet d'ajouter un ou plusieurs groupes Active Directory en tant que membres d'un ou plusieurs autres groupes AD. 
    Il prend en charge l'ajout de plusieurs groupes en une seule exécution.
.EXAMPLE
    .\add_AD_group_in_group.ps1 -MemberGroups "GroupeMembre1, GroupeMembre2" -TargetGroups "GroupeCible1, GroupeCible2"
    Ajoute "GroupeMembre1" et "GroupeMembre2" en tant que membres de "GroupeCible1" et "GroupeCible2".

    .\add_AD_group_in_group.ps1 -FilePath "C:\chemin\vers\groupes.csv"
    Ajoute les groupes listés dans le fichier "groupes.csv" en tant que membres des groupes cibles spécifiés dans le fichier.
    Colonnes obligatoires dans le fichier : MemberGroup, TargetGroup

    .\add_AD_group_in_group.ps1 -Filepath "C:\chemin\vers\groupes.txt" -TargetGroups "GroupeCible1, GroupeCible2"
    Ajoute les groupes listés dans le fichier texte en tant que membres de "GroupeCible1" et "GroupeCible2".
    Colonnes obligatoires dans le fichier : MemberGroup uniquement. Utiliser TargetGroups pour spécifier les groupes cibles.
.PARAMETER FilePath
    Spécifie le chemin vers un fichier texte contenant les noms des groupes AD à ajouter en tant que membres, un par ligne.
    Colonnes obligatoires : MemberGroup, TargetGroup
    Si les groupes cibles sont spécifiés via le paramètre TargetGroups, seule la colonne MemberGroup est requise.
.PARAMETER MemberGroups
    Spécifie le ou les groupes AD à ajouter en tant que membres.
.PARAMETER TargetGroups
    Spécifie le ou les groupes AD cibles auxquels les groupes membres seront ajoutés.
.NOTES
    Auteur: Julien BABIN
    Date de création: 31/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param(
    [string]$FilePath,
    [string[]]$MemberGroups,
    [string[]]$TargetGroups
)

Import-Module ActiveDirectory

function add_groups_to_target {
    param (
        [string[]]$Members,
        [string[]]$Targets
    )

    foreach ($target in $Targets) {
        foreach ($member in $Members) {
            try {
                Add-ADGroupMember -Identity $target -Members $member -ErrorAction Stop
                Write-Host "Le groupe '$member' a été ajouté avec succès au groupe '$target'." -ForegroundColor Green
            } catch {
                Write-Host "Erreur lors de l'ajout du groupe '$member' au groupe '$target': $_" -ForegroundColor Red
            }
        }
    }
}

if ($FilePath) {
    if (Test-Path $FilePath) {
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        if ($extension -eq ".csv") {
            $data = Import-Csv -Path $FilePath
            foreach ($entry in $data) {
                $memberGroup = $entry.MemberGroup
                $targetGroup = if ($TargetGroups) { $TargetGroups } else { $entry.TargetGroup }
                add_groups_to_target -Members @($memberGroup) -Targets @($targetGroup)
            }
        } elseif ($extension -eq ".txt") {
            $memberGroupsFromFile = Get-Content -Path $FilePath
            add_groups_to_target -Members $memberGroupsFromFile -Targets $TargetGroups
        } else {
            Write-Host "Format de fichier non pris en charge. Utilisez un fichier .csv ou .txt." -ForegroundColor Red
        }
    } else {
        Write-Host "Le fichier spécifié n'existe pas: $FilePath" -ForegroundColor Red
    }
} elseif ($MemberGroups -and $TargetGroups) {
    add_groups_to_target -Members $MemberGroups -Targets $TargetGroups
} else {
    Write-Host "Veuillez spécifier soit un chemin de fichier, soit des groupes membres et cibles." -ForegroundColor Red
}
