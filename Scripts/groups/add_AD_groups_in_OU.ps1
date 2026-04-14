<#
.SYNOPSIS
    Ajout de groupes dans une OU d'Active Directory.
.DESCRIPTION
    Ce script PowerShell permet d'ajouter des groupes dans une Unité d'Organisation (OU) spécifique dans Active Directory.
.EXAMPLE
    .\add_AD_groups_in_OU.ps1 -GroupNames "IT_Support","IT_Admins" -OuName "Service_IT" 
    Exécute le script pour ajouter les groupes "IT_Support" et "IT_Admins" dans l'OU "Service_IT".

    .\add_AD_groups_in_OU.ps1 -FilePath "C:\groups_to_add.csv"
    Exécute le script et ajoute tous les groupes à partir d'un fichier CSV. 
    Le fichier doit avoir les colonnes: GroupName, OuName.

    .\add_AD_groups_in_OU.ps1 -FilePath "C:\groups_to_add.csv" -OuName "Service_IT"
    Exécute le script et ajoute tous les groupes listés dans le fichier CSV dans l'OU spécifiée.
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les groupes à ajouter. (facultatif si GroupNames et OuName sont spécifiés)
    Le fichier doit avoir les colonnes: GroupName, OuName (si OuName n'est pas spécifié en paramètre).
    Le fichier peut aussi contenir uniquement la colonne GroupName si OuName est spécifié en paramètre.
.PARAMETER GroupNames
    Le(s) nom(s) des groupes à ajouter. Pour plusieurs groupes, séparer les noms par des virgules. (obligatoire si FilePath n'est pas spécifié)
.PARAMETER OuName
    Le nom de l'Unité d'Organisation (OU) dans laquelle ajouter les groupes. (obligatoire si FilePath n'est pas spécifié ou si le fichier ne contient pas la colonne OuName)
.NOTES
    Auteur: Julien BABIN
    Date de création: 31/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$FilePath,
    [string[]]$GroupNames,
    [string]$OuName
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function add_groups_to_OU {
    param (
        [string[]]$GroupNames,
        [string]$OuName
    )

    #Vérifier si la nouvelle OU existe en cherchant par nom d'OU
    $domainDN = (Get-ADDomain).DistinguishedName
    
    # Extraire le nom de l'OU (la partie avant la première virgule si c'est un chemin)
    $ouName = $OuName -replace "^OU=", "" -replace ",.*$", ""
    
    # Rechercher l'OU par son nom dans l'arborescence du domaine
    $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domainDN -SearchScope Subtree -ErrorAction SilentlyContinue

    # Vérifier si l'OU existe
    if (-not $ouExists) {
        Write-Host "L'OU '$OuName' spécifiée n'existe pas dans Active Directory." -ForegroundColor Red
        # Demander à l'utiliseur s'il veut créer l'OU
        $createOU = Read-Host "Voulez-vous créer l'OU '$OuName'? (O/N)"
        if ($createOU -eq "O" -or $createOU -eq "o") {
            # Demander le nom de l'OU parent pour la création de l'OU à l'utilisateur
            $parentOU = Read-Host "Veuillez entrer le nom de l'OU parent pour la création de l'OU '$OuName'"
            # Créer l'OU en utilisant la fonction verify_and_create_OU du script create_AD_OU.ps1
            #. .\OUs\create_AD_OU.ps1 chemin pour le repo
            . .\create_AD_OU.ps1
            verify_and_create_OU -OU $ouName -MemberOf $parentOU
            # Rechercher à nouveau l'OU après création
            $ouExists = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domainDN -SearchScope Subtree -ErrorAction SilentlyContinue
        } else {
            Write-Host "Opération annulée. Les groupes ne seront pas ajoutés." -ForegroundColor Yellow
            return
        }
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

    foreach ($groupName in $GroupNames) {
        # Verfier si le(s) groupe(s) existe(nt)
        $group = Get-ADGroup -Filter {Name -eq $groupName} -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Host "Le groupe '$groupName' n'existe pas dans Active Directory." -ForegroundColor Red
            continue
        }
        # Vérifier si le groupe existe déjà das l'OU cible sinon déplacer le groupe
        $groupDN = $group.DistinguishedName
        if ($groupDN -like "*$newOUPath") {
            Write-Host "Le groupe '$groupName' est déjà dans l'OU '$OuName'." -ForegroundColor Yellow
        } else {
            # Déplacer le groupe vers la nouvelle OU
            try {
                Move-ADObject -Identity $groupDN -TargetPath $newOUPath
                Write-Host "Le groupe '$groupName' a été ajouté à l'OU '$OuName' avec succès." -ForegroundColor Green
            }
            catch {
                Write-Host "Une erreur s'est produite lors de l'ajout du groupe '$groupName' à l'OU '$OuName': $_" -ForegroundColor Red
            }
        }
    }
}

# Si un fichier CSV est spécifié, ajouter les groupes à partir du fichier
if ($FilePath) {
    if (-Not (Test-Path $FilePath)) {
        Write-Host "Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }

    $groups = Import-Csv -Path $FilePath
    foreach ($group in $groups) {
        $groupName = $group.GroupName
        $ouName = $group.OuName

        if (-not $ouName) {
            if ($OuName) {
                $ouName = $OuName
            } else {
                Write-Host "L'OU pour le groupe '$groupName' n'est pas spécifiée dans le fichier ou en paramètre." -ForegroundColor Red
                continue
            }
        }

        # Ajouter le groupe à l'OU spécifiée
        add_groups_to_OU -GroupNames @($groupName) -OuName $ouName
    }
} elseif ($GroupNames -and $OuName) {
    # Diviser les noms de groupes s'ils sont séparés par des virgules
    if ($GroupNames.Count -eq 1 -and $GroupNames[0] -like "*,*") {
        $GroupNames = $GroupNames[0] -split "," | ForEach-Object { $_.Trim() }
    }
    # Ajouter les groupes à l'OU spécifiée
    add_groups_to_OU -GroupNames $GroupNames -OuName $OuName
} else {
    if (-not $GroupNames -or -not $OuName) {
        Write-Host "Les paramètres 'GroupNames' et 'OuName' sont obligatoires si 'FilePath' n'est pas spécifié." -ForegroundColor Red
        exit 1
    }
}