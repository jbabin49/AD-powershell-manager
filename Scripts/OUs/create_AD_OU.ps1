<#
.SYNOPSIS
    Création d'Unité d'Organisation (OU) dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de créer une nouvelle Unité d'Organisation (OU) dans Active Directory si elle n'existe pas déjà.
.EXAMPLE
    .\create_AD_OU.ps1 -OuName "Service_IT"
    Exécute le script pour créer l'OU "Service_IT" dans le domaine Active Directory.

    .\create_AD_OU.ps1 -OuName "Service_IT" -MemberOf "OU=Departments"
    Exécute le script pour créer l'OU "Service_IT" sous l'OU "Departments".

    .\create_AD_OU.ps1 -FilePath "C:\create_ou.csv"
    Exécute le script et crée toutes les OUs à partir d'un fichier CSV. Le fichier doit avoir les colonnes: OuName et MemberOf.

    .\create_AD_OU.ps1 -FilePath "C:\create_ou.csv" -MemberOf "OU=Departments"
    Exécute le script et crée toutes les OUs listées dans le fichier CSV sous l'OU "Departments".
    Le fichier doit contenir uniquement la colonne: OuName.
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les OUs à créer. Le fichier doit avoir au moins la colonne: OuName (MemberOf est facultatif).
.PARAMETER OuName
    Le nom de l'Unité d'Organisation (OU) à créer. (obligatoire)
.PARAMETER MemberOf
    L'OU parente sous laquelle l'OU sera créée. (facultatif, par défaut l'OU sera créée à la racine du domaine)
    OBLIGATOIRE : il faut écrire "OU=" avant le nom de l'/des OU(s) parente(s) et les séparer par des virgules si il y en a plusieurs.
.NOTES
    Auteur: Julien BABIN
    Date de création: 31/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$FilePath,
    [string]$OuName,
    [string]$MemberOf
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function verify_and_create_OU {
    param (
        [string]$OU,
        [string]$MemberOf
    )

    # Construire le DomainName complet de l'OU
    $domainDN = (Get-ADDomain).DistinguishedName
    
    # Déterminer le chemin parent (Path) pour la création
    if (-not $MemberOf) {
        # Pas d'OU parente spécifiée, créer à la racine du domaine
        $parentPath = $domainDN
    } else {
        # OU parente spécifiée
        if ($MemberOf -match ",DC=") {
            # Chemin complet fourni (contient DC=)
            $parentPath = $MemberOf
        } elseif ($MemberOf -match "^OU=") {
            # Format: OU=Parent1,OU=Parent2 (sans DC=)
            $parentPath = "$MemberOf,$domainDN"
        } else {
            # Format simple: Parent1 (chercher l'OU par son nom)
            $parentOU = Get-ADOrganizationalUnit -Filter "Name -eq '$MemberOf'" -ErrorAction SilentlyContinue
            if ($parentOU) {
                $parentPath = $parentOU.DistinguishedName
            } else {
                # Si l'OU n'existe pas, essayer en ajoutant OU=
                $parentPath = "OU=$MemberOf,$domainDN"
                Write-Host "Attention : L'OU parente '$MemberOf' n'a pas pu être trouvée. Utilisation du chemin par défaut: $parentPath" -ForegroundColor Yellow
            }
        }
    }
    
    # Construire le DN complet pour la vérification
    $fullOU = "OU=$OU,$parentPath"

    # Vérifier si l'OU existe déjà
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$fullOU'" -ErrorAction SilentlyContinue)) {
        # Créer l'OU
        try {
            New-ADOrganizationalUnit -Name $OU -Path $parentPath -ErrorAction Stop
            Write-Host "OU '$OU' créée." -ForegroundColor Green
        } catch {
            Write-Host "Erreur lors de la création de l'OU '$OU': $_" -ForegroundColor Red
        }
    } else {
        Write-Host "L'OU '$OU' existe déjà." -ForegroundColor Yellow
    }
}

if ($FilePath -and -not $MemberOf) {
    # Lire les OUs à partir du fichier CSV
    $ouList = Import-Csv -Path $FilePath
    foreach ($ou in $ouList) {
        $ouName = $ou.OuName
        $memberOf = $ou.MemberOf

        # Vérifier et créer l'OU
        verify_and_create_OU -OU $ouName -MemberOf $memberOf
    }
} elseif ($FilePath -and $MemberOf) {
    # Lire les OUs à partir du fichier CSV
    $ouList = Import-Csv -Path $FilePath
    foreach ($ou in $ouList) {
        $ouName = $ou.OuName
        # Vérifier et créer l'OU sous l'OU parente spécifiée
        verify_and_create_OU -OU $ouName -MemberOf $MemberOf
    }
} elseif ($OuName -and -not $MemberOf) {
    # Vérifier et créer l'OU spécifiée
    verify_and_create_OU -OU $OuName
} elseif ($OuName -and $MemberOf) {
    # Vérifier et créer l'OU spécifiée sous l'OU parente
    verify_and_create_OU -OU $OuName -MemberOf $MemberOf
}
else {
    Write-Host "Le paramètre 'OuName' ou 'FilePath' est obligatoire." -ForegroundColor Red
    exit 1
}