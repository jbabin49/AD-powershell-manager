<#
.SYNOPSIS
    Création de groupes de sécurité dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de créer de nouveaux groupes de sécurité dans Active Directory avec des propriétés spécifiées telles que le nom du groupe, la description, le type de groupe, la portée et les groupes desquels il est membre (domaine par défaut si non spécifié).
.EXAMPLE
    .\create_AD_group.ps1 -GroupName "IT_Support" -Description "Groupe de support informatique" -GroupScope "Global" -GroupCategory "Security" -MemberOfGroup "ParentGroup"
    Exécute le script pour créer un nouveau groupe de sécurité avec les propriétés spécifiées.
    .\create_AD_group.ps1 -FilePath "C:\groups.csv"
    Exécute le script et crée tous les groupes à partir d'un fichier CSV.
.PARAMETER GroupName
    Le nom du groupe de sécurité à créer. (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Description
    La description du groupe de sécurité. (facultatif)
.PARAMETER GroupScope
    La portée du groupe de sécurité (DomainLocal, Global, Universal). (obligatoire si FilePath n'est pas spécifié)
.PARAMETER GroupCategory
    Le type de groupe (Security ou Distribution). (obligatoire si FilePath n'est pas spécifié)
.PARAMETER MemberOfGroup
    Les groupes dont ce groupe sera membre. (facultatif, par défaut le groupe sera membre du domaine)
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les groupes à créer. Le fichier doit avoir au moins les colonnes: GroupName, GroupScope, GroupCategory, (MemberOfGroup est facultatif). (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$GroupName,
    [string]$Description,
    [string]$GroupScope,
    [string]$GroupCategory,
    [string]$MemberOfGroup,
    [string]$FilePath
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function create_AD_group {
    param (
        [string]$GroupName,
        [string]$Description,
        [string]$GroupScope,
        [string]$GroupCategory,
        [string]$MemberOfGroup
    )

    # Vérifier et ajouter le préfixe GRP_ si nécessaire au nom du groupe
    if ($GroupName -notmatch "^GRP_") {
        $GroupName = "GRP_$GroupName"
    }

    # Vérifier et ajouter le préfixe GRP_ aux groupes membres si nécessaire
    if ($MemberOfGroup) {
        $memberGroups = $MemberOfGroup -split '\s*,\s*'
        $MemberOfGroup = @()
        foreach ($group in $memberGroups) {
            $trimmedGroup = $group.Trim()
            if ($trimmedGroup) {
                if ($trimmedGroup -notmatch "^GRP_") {
                    $trimmedGroup = "GRP_$trimmedGroup"
                }
                $MemberOfGroup += $trimmedGroup
            }
        }
        $MemberOfGroup = $MemberOfGroup -join ','
    }

    # Construire un tableau de paramètres pour New-ADGroup
    $params = @{
        Name         = $GroupName
        GroupScope   = $GroupScope
        GroupCategory= $GroupCategory
    }
    if ($Description) {
        $params['Description'] = $Description
    }
    # Chercher l'OU "Groupes" pour y créer les groupes
    $groupsOU = Get-ADOrganizationalUnit -Filter "Name -eq 'Groupes'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($groupsOU) {
        $params['Path'] = $groupsOU.DistinguishedName
    } else {
        # Si l'OU n'existe pas, utiliser la racine du domaine
        $domain = (Get-ADDomain).DistinguishedName
        $params['Path'] = $domain
    }
    try {
        # Créer le groupe de sécurité
        New-ADGroup @params
        if ($MemberOfGroup) {
            $targetGroups = $MemberOfGroup -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
            foreach ($targetGroup in $targetGroups) {
                Add-ADGroupMember -Identity $targetGroup -Members $GroupName
            }
        }
        if ($MemberOfGroup) {
            $targetGroups = $MemberOfGroup -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
            foreach ($targetGroup in $targetGroups) {
                Add-ADGroupMember -Identity $targetGroup -Members $GroupName
            }
        }
        Write-Host "Groupe de sécurité '$GroupName' créé avec succès." -ForegroundColor Green
    }
    catch {
        Write-Host "Une erreur s'est produite lors de la création du groupe '$GroupName': $_" -ForegroundColor Red
    }
}

# Si un fichier CSV est spécifié, créer les groupes à partir du fichier
if ($FilePath) {
    if (-Not (Test-Path $FilePath)) {
        Write-Host "Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }

    $groups = Import-Csv -Path $FilePath
    foreach ($group in $groups) {
        create_AD_group -GroupName $group.GroupName `
                     -Description $group.Description `
                     -GroupScope $group.GroupScope `
                     -GroupCategory $group.GroupCategory `
                     -MemberOfGroup $group.MemberOfGroup
    }
}
else {
    # Vérifier que les paramètres obligatoires sont fournis
    if (-not $GroupName -or -not $GroupScope -or -not $GroupCategory) {
        Write-Host "Les paramètres 'GroupName', 'GroupScope' et 'GroupCategory' sont obligatoires si 'FilePath' n'est pas spécifié." -ForegroundColor Red
        exit 1
    }

    # Créer le groupe de sécurité avec les paramètres fournis
    create_AD_group -GroupName $GroupName `
                             -Description $Description `
                             -GroupScope $GroupScope `
                             -GroupCategory $GroupCategory `
                             -MemberOfGroup $MemberOfGroup
}