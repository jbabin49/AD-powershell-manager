<#
.SYNOPSIS
    Récupération des informations sur les Unités d'Organisation (OU) dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de récupérer et d'afficher les informations sur les Unités d'Organisation (OU) dans Active Director.
.EXAMPLE
    .\infos_AD_OU.ps1
    Exécute le script pour afficher toutes les OUs dans le domaine Active Directory.

    .\infos_AD_OU.ps1 -OuName "Service_IT"
    Exécute le script pour afficher les informations de l'OU "Service_IT". 
    Possible de spécifier plusieurs OUs en les séparant par une virgule.

    .\infos_AD_OU.ps1 -OuName "Service_IT" -Properties "Name,DistinguishedName,Description"
    Exécute le script pour afficher les propriétés spécifiées de l'OU "Service_IT".

    .\infos_AD_OU.ps1 -OuName "Service_IT" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)"
    Exécute le script pour afficher le nombre d'objets spécifiés par -Objects dans l'OU "Service_IT" avec le scope de recherche défini par -SearchScope.
    - OneLevel : Recherche uniquement dans l'OU spécifiée.
    - Subtree : Recherche dans l'OU spécifiée et toutes ses sous-OUs.

    .\infos_AD_OU.ps1 -OuName "Service_IT" -Properties "Name,DistinguishedName,Description" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)"
    Exécute le script pour afficher le nombre d'objets spécifiés par -Objects dans l'OU "Service_IT" avec le scope de recherche défini par -SearchScope et les propriétés spécifiées avec -Properties.
    - OneLevel : Recherche uniquement dans l'OU spécifiée.
    - Subtree : Recherche dans l'OU spécifiée et toutes ses sous-OUs.

    .\infos_AD_OU.ps1 -FilePath "C:\ous_to_check.csv" (ou -FilePath "C:\ous_to_check.csv" -Properties "Name,DistinguishedName,Description" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)")
    Exécute le script et affiche les informations de toutes les OUs listées dans un fichier CSV.
    Le fichier doit avoir au moins la colonne: OuName (facultatif : Properties, Objects, SearchScope).
    Les paramètres Properties, Objects et SearchScope peuvent définis dans le fichier CSV pour afficher des informations différentes pour chaque OU ou en paramètre du script pour afficher les mêmes informations pour toutes les OUs.
    Si -Count est utilisé en paramètre du script, Objects et SearchScope doivent être définis dans le fichier CSV ou en paramètre du script. 
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les OUs à vérifier. 
    Le fichier doit avoir au moins la colonne: OuName (facultatif : Properties, Objects, SearchScope).
.PARAMETER OuName
    Le nom de l'Unité d'Organisation (OU) à rechercher. (obligatoire)
    Possible de spécifier plusieurs OUs en les séparant par une virgule.
.PARAMETER Properties
    Les propriétés à récupérer pour chaque OU. Par défaut, seules les propriétés "Name", "DistinguishedName" et "Description" sont récupérées. (facultatif)
    Séparer les noms de propriétés par des virgules.
.PARAMETER Count
    Indique au script qu'il doit afficher le nombre d'objets dans chaque OU définie. (facultatif)
.PARAMETER Objects
    Le type d'objets à compter dans chaque OU. Valeurs possibles : "Users", "Groups", "Computers", "OU". (obligatoire si -Count est spécifié)
.PARAMETER SearchScope
    Le scope de recherche pour le comptage des objets. (obligatoire si -Count est spécifié)
    Valeurs possibles : 
    - "OneLevel" (recherche uniquement dans l'OU spécifiée) 
    - "Subtree" (recherche dans l'OU spécifiée et toutes ses sous-OUs).
.NOTES
    Auteur: Julien BABIN
    Date de création: 01/02/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$FilePath,
    [string]$OuName,
    [string]$Properties = "Name,DistinguishedName,Description",
    [switch]$Count,
    [string]$Objects,
    [string]$SearchScope
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function display_OU_Recursive {
    param (
        [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit]$OU,
        [string[]]$Properties,
        [string]$Objects,
        [int]$Level = 0
    )
    
    $indent = "  " * $Level
    
    # Afficher les propriétés de l'OU actuelle
    Write-Host "${indent}$("`n" + ("=" * (50 - $Level * 2)))"
    Write-Host "${indent}Niveau: $($Level + 1)" -ForegroundColor Yellow
    $OU | Select-Object -Property $Properties | Format-Table
    
    # Compter les objets dans cette OU (incluant les sous-OUs avec Subtree)
    switch ($Objects) {
        "Users" {
            $childUsers = Get-ADUser -Filter '*' -SearchBase $OU.DistinguishedName -SearchScope Subtree
            if ($null -eq $childUsers) {
                $childObjCount = 0
            } elseif ($childUsers -is [array]) {
                $childObjCount = $childUsers.Count
            } else {
                $childObjCount = 1
            }
            Write-Host "${indent}Nombre d'utilisateurs dans l'OU '$($OU.Name)' (Subtree): $childObjCount"
        }
        "Groups" {
            $childGroups = Get-ADGroup -Filter '*' -SearchBase $OU.DistinguishedName -SearchScope Subtree
            if ($null -eq $childGroups) {
                $childObjCount = 0
            } elseif ($childGroups -is [array]) {
                $childObjCount = $childGroups.Count
            } else {
                $childObjCount = 1
            }
            Write-Host "${indent}Nombre de groupes dans l'OU '$($OU.Name)' (Subtree): $childObjCount"
        }
        "Computers" {
            $childComputers = Get-ADComputer -Filter '*' -SearchBase $OU.DistinguishedName -SearchScope Subtree
            if ($null -eq $childComputers) {
                $childObjCount = 0
            } elseif ($childComputers -is [array]) {
                $childObjCount = $childComputers.Count
            } else {
                $childObjCount = 1
            }
            Write-Host "${indent}Nombre d'ordinateurs dans l'OU '$($OU.Name)' (Subtree): $childObjCount"
        }
        "OU" {
            $childOus = Get-ADOrganizationalUnit -Filter '*' -SearchBase $OU.DistinguishedName -SearchScope Subtree
            if ($null -eq $childOus) {
                $childObjCount = 0
            } elseif ($childOus -is [array]) {
                $childObjCount = $childOus.Count
            } else {
                $childObjCount = 1
            }
            Write-Host "${indent}Nombre d'OUs dans l'OU '$($OU.Name)' (Subtree): $childObjCount"
        }
    }
    
    # Récursivement afficher les sous-OUs
    $subOUs = Get-ADOrganizationalUnit -Filter '*' -SearchBase $OU.DistinguishedName -SearchScope OneLevel -ErrorAction SilentlyContinue
    
    if ($subOUs) {
        if ($subOUs -is [array]) {
            foreach ($subOU in $subOUs) {
                display_OU_Recursive -OU $subOU -Properties $Properties -Objects $Objects -Level ($Level + 1)
            }
        } else {
            display_OU_Recursive -OU $subOUs -Properties $Properties -Objects $Objects -Level ($Level + 1)
        }
    }
}

Function get_AD_OU_info {
    param (
        [string]$OuName,
        [string[]]$Properties,
        [switch]$Count,
        [string]$Objects,
        [string]$SearchScope
    )

    #Vérifier si la nouvelle OU existe en cherchant par nom d'OU
    $domainDN = (Get-ADDomain).DistinguishedName
    
    # Extraire le nom de l'OU (la partie avant la première virgule si c'est un chemin)
    $ouName = $OuName -replace "^OU=", "" -replace ",.*$", ""
    
    # Rechercher l'OU par son nom dans l'arborescence du domaine
    $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domainDN -SearchScope Subtree -ErrorAction SilentlyContinue

    # Vérifier si l'OU existe
    if (-not $ou) {
        Write-Host "L'OU '$OuName' spécifiée n'existe pas dans Active Directory." -ForegroundColor Red
        return
    } elseif ($ou -is [array]) {
        # S'il y a plusieurs OUs avec le même nom, demander à l'utilisateur de choisir
        Write-Host "`nPlusieurs OUs avec le nom '$ouName' ont été trouvées:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $ou.Count; $i++) {
            Write-Host "$($i + 1). $($ou[$i].DistinguishedName)" -ForegroundColor Cyan
        }
        
        # Demander à l'utilisateur de sélectionner une OU
        $validSelection = $false
        while (-not $validSelection) {
            $choice = Read-Host "Veuillez sélectionner le numéro de l'OU à utiliser (1-$($ou.Count))"
            if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $ou.Count) {
                $ou = $ou[[int]$choice - 1]
                $validSelection = $true
                Write-Host "OU sélectionnée: $($ou.DistinguishedName)" -ForegroundColor Green
            } else {
                Write-Host "Sélection invalide. Veuillez entrer un numéro entre 1 et $($ou.Count)." -ForegroundColor Red
            }
        }
    }

    # Afficher les propriétés spécifiées
    $ou | Select-Object -Property $Properties | Format-Table

    # Si le paramètre Count est spécifié, compter les objets dans l'OU
    if ($Count) {
        if (-not $Objects) {
            Write-Host "Le paramètre -Objects doit être spécifié lorsque -Count est utilisé." -ForegroundColor Red
            return
        }
        if (-not $SearchScope) {
            Write-Host "Le paramètre -SearchScope doit être spécifié lorsque -Count est utilisé." -ForegroundColor Red
            return
        }

        # Déterminer le scope de recherche
        if ($SearchScope -eq "OneLevel") {
            $searchScopeEnum = [Microsoft.ActiveDirectory.Management.ADSearchScope]::OneLevel
        } elseif ($SearchScope -eq "Subtree") {
            $searchScopeEnum = [Microsoft.ActiveDirectory.Management.ADSearchScope]::Subtree
        } else {
            Write-Host "Le paramètre -SearchScope doit être 'OneLevel' ou 'Subtree'." -ForegroundColor Red
            return
        }

        # Compter les objets selon le type spécifié
        switch ($Objects) {
            "Users" {
                $users = Get-ADUser -Filter '*' -SearchBase $ou.DistinguishedName -SearchScope $searchScopeEnum
                if ($null -eq $users) {
                    $objCount = 0
                } elseif ($users -is [array]) {
                    $objCount = $users.Count
                } else {
                    $objCount = 1
                }
                Write-Host "Nombre d'utilisateurs dans l'OU '$OuName': $objCount"
            }
            "Groups" {
                $groups = Get-ADGroup -Filter '*' -SearchBase $ou.DistinguishedName -SearchScope $searchScopeEnum
                if ($null -eq $groups) {
                    $objCount = 0
                } elseif ($groups -is [array]) {
                    $objCount = $groups.Count
                } else {
                    $objCount = 1
                }
                Write-Host "Nombre de groupes dans l'OU '$OuName': $objCount"
            }
            "Computers" {
                $computers = Get-ADComputer -Filter '*' -SearchBase $ou.DistinguishedName -SearchScope $searchScopeEnum
                if ($null -eq $computers) {
                    $objCount = 0
                } elseif ($computers -is [array]) {
                    $objCount = $computers.Count
                } else {
                    $objCount = 1
                }
                Write-Host "Nombre d'ordinateurs dans l'OU '$OuName': $objCount"
            }
            "OU" {
                $ous = Get-ADOrganizationalUnit -Filter '*' -SearchBase $ou.DistinguishedName -SearchScope $searchScopeEnum
                if ($null -eq $ous) {
                    $objCount = 0
                } elseif ($ous -is [array]) {
                    $objCount = $ous.Count
                } else {
                    $objCount = 1
                }
                Write-Host "Nombre d'OUs dans l'OU '$OuName': $objCount"
            }
            default {
                Write-Host "Le paramètre -Objects doit être 'Users', 'Groups', 'Computers' ou 'OU'." -ForegroundColor Red
                return
            }
        }

        # Si SearchScope est Subtree et Count est spécifié, afficher récursivement les sous-OUs
        if ($SearchScope -eq "Subtree") {
            $childOUs = Get-ADOrganizationalUnit -Filter '*' -SearchBase $ou.DistinguishedName -SearchScope OneLevel -ErrorAction SilentlyContinue
            
            if ($childOUs) {
                Write-Host "`n--- Sous-OUs de '$($ou.Name)' ---`n" -ForegroundColor Cyan
                
                if ($childOUs -is [array]) {
                    foreach ($childOU in $childOUs) {
                        display_OU_Recursive -OU $childOU -Properties $Properties -Objects $Objects -Level 1
                    }
                } else {
                    display_OU_Recursive -OU $childOUs -Properties $Properties -Objects $Objects -Level 1
                }
            }
        }
    }
}

if ($FilePath) {
    if (-Not (Test-Path $FilePath)) {
        Write-Host "Le fichier '$FilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }

    # Importer les données du fichier CSV
    $ous = Import-Csv -Path $FilePath

    # Si Count est spécifié en paramètre, vérifier que Objects et SearchScope sont définis dans le fichier ou en paramètres
    if ($Count) {
        foreach ($ou in $ous) {
            if (-not $ou.Objects -and -not $Objects) {
                Write-Host "Le paramètre 'Objects' doit être spécifié dans le fichier ou en paramètre du script lorsque 'Count' est utilisé." -ForegroundColor Red
                exit 1
            }
            if (-not $ou.SearchScope -and -not $SearchScope) {
                Write-Host "Le paramètre 'SearchScope' doit être spécifié dans le fichier ou en paramètre du script lorsque 'Count' est utilisé." -ForegroundColor Red
                exit 1
            }
        }
        # Vérifier quelles colonnes sont présentes dans le fichier CSV
        foreach ($ou in $ous) {
            $ouName = $ou.OuName
            $objects = if ($ou.Objects) { $ou.Objects } else { $Objects }
            $searchScope = if ($ou.SearchScope) { $ou.SearchScope } else { $SearchScope }
            # Si Properties n'est pas défini dans le fichier CSV ou en paramètre du script, utiliser "Name,DistinguishedName,Description" par défaut
            $properties = if ($ou.Properties) { $ou.Properties -split "," | ForEach-Object { $_.Trim() } } else { $Properties -split "," | ForEach-Object { $_.Trim() } }

            # Récupérer les informations de l'OU
            get_AD_OU_info -OuName $ouName -Properties $properties -Count -Objects $objects -SearchScope $searchScope

            # Ajouter une ligne vide entre chaque OU pour une meilleure lisibilité
            Write-Host ""
        }
    } else {
        # Récupérer les informations de chaque OU dans le fichier CSV
        foreach ($ou in $ous) {
            $ouName = $ou.OuName
            $properties = if ($ou.Properties) { $ou.Properties -split "," | ForEach-Object { $_.Trim() } } else { $Properties -split "," | ForEach-Object { $_.Trim() } }

            # Récupérer les informations de l'OU
            if (-not $properties) {
                get_AD_OU_info -OuName $ouName -Properties $properties
            } else {
                get_AD_OU_info -OuName $ouName -Properties $properties
            }

            # Ajouter une ligne vide entre chaque OU pour une meilleure lisibilité
            Write-Host ""
        }
    }
} elseif ($OuName) {
    # Diviser les noms d'OUs s'ils sont séparés par des virgules
    if ($OuName -like "*,*") {
        $ouNames = $OuName -split "," | ForEach-Object { $_.Trim() }
    } else {
        $ouNames = @($OuName)
    }

    # Vérifier si Count est spécifié en paramètre, Objects et SearchScope doivent être définis
    if ($Count) {
        if (-not $Objects) {
            Write-Host "Le paramètre -Objects doit être spécifié lorsque -Count est utilisé." -ForegroundColor Red
            exit 1
        }
        if (-not $SearchScope) {
            Write-Host "Le paramètre -SearchScope doit être spécifié lorsque -Count est utilisé." -ForegroundColor Red
            exit 1
        }
        foreach ($ouName in $ouNames) {
            # Récupérer les informations de l'OU
            $props = if ($Properties) { @($Properties -split "," | ForEach-Object { $_.Trim() }) } else { @("Name", "DistinguishedName", "Description") }
            get_AD_OU_info -OuName $ouName -Properties $props -Count -Objects $Objects -SearchScope $SearchScope

            # Ajouter une ligne vide entre chaque OU pour une meilleure lisibilité
            Write-Host ""
        }
    } else {
        foreach ($ouName in $ouNames) {
            # Récupérer les informations de l'OU
            get_AD_OU_info -OuName $ouName -Properties ($Properties -split "," | ForEach-Object { $_.Trim() })

            # Ajouter une ligne vide entre chaque OU pour une meilleure lisibilité
            Write-Host ""
        }
    }
} else {
    Write-Host "Les paramètres 'OuName' ou 'FilePath' sont obligatoires." -ForegroundColor Red
}