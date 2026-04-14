<#
.SYNOPSIS
    Interface interactive pour créer un nouvel employé dans Active Directory.
.DESCRIPTION
    Script d'interface interactive qui demande les informations de l'utilisateur et appelle create_AD_user.ps1.
.EXAMPLE
    .\add_AD_newEmployee.ps1 -Auto
    Mode interactif avec prompts pour chaque paramètre.

    .\add_AD_newEmployee.ps1 -Prenom "John" -Nom "Doe" -Titre "Développeur" -Departement "Developpement" -Manager "jsmith"
    Crée directement l'utilisateur sans prompts.
.PARAMETER Prenom
    Prénom de l'employé à créer. (obligatoire en mode non interactif)
.PARAMETER Nom
    Nom de l'employé à créer. (obligatoire en mode non interactif)
.PARAMETER Titre
    Titre/Poste de l'employé à créer. (obligatoire en mode non interactif)
.PARAMETER Departement
    Département de l'employé à créer. (obligatoire en mode non interactif)
.PARAMETER Manager
    Login du manager de l'employé à créer. (facultatif) 
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les employés à créer. Le fichier doit avoir les colonnes: Prenom, Nom, Titre, Departement, (Manager est facultatif). (facultatif)
.PARAMETER Auto
    Si spécifié, le script fonctionne en mode interactif avec des prompts pour chaque paramètre. (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date: 01/02/2026
    Version: 1.0
    Dépendances: create_AD_user.ps1
#>

param (
    [string]$Prenom,
    [string]$Nom,
    [string]$Titre,
    [string]$Departement,
    [string]$Manager,
    [string]$FilePath,
    [switch]$Auto
)

# Fonction pour appeler create_AD_user.ps1 avec un fichier CSV
Function invoke_CreateUserWithCSV {
    param (
        [string]$CsvFilePath
    )
    
    if (-not (Test-Path $CsvFilePath)) {
        Write-Host "Erreur: Le fichier '$CsvFilePath' n'existe pas." -ForegroundColor Red
        exit 1
    }
    
    $createUserScript = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath "create_AD_user.ps1"
    try {
        & $createUserScript -FilePath $CsvFilePath -ErrorAction Stop
    } catch {
        Write-Host "Erreur: $_" -ForegroundColor Red
        exit 1
    }
}

# Si un fichier CSV est spécifié, l'utiliser directement
if ($FilePath) {
    invoke_CreateUserWithCSV -CsvFilePath $FilePath
    exit 0
}

# Si les paramètres obligatoires ne sont pas fournis, mode interactif
if (-not $Prenom -or -not $Nom -or -not $Titre -or -not $Departement) {
    Write-Host "`nCréation d'employés dans Active Directory" -ForegroundColor Cyan
    Write-Host "=========================================`n"
    $csvChoice = Read-Host "Avez-vous un fichier CSV pour créer plusieurs employés ? (O/N)"

    if ($csvChoice -eq 'O' -or $csvChoice -eq 'o') {
        $csvPath = Read-Host "Entrez le chemin du fichier CSV"
        invoke_CreateUserWithCSV -CsvFilePath $csvPath
        exit 0
    }

    # Mode interactif - création d'un seul utilisateur
    Write-Host "`nMode création individuelle" -ForegroundColor Yellow
    if (-not $Prenom) { $Prenom = Read-Host "Entrez le prénom" }
    if (-not $Nom) { $Nom = Read-Host "Entrez le nom" }
    if (-not $Titre) { $Titre = Read-Host "Entrez le titre/poste" }
    if (-not $Departement) { $Departement = Read-Host "Entrez le département" }
    if (-not $Manager) { $Manager = Read-Host "Entrez le login du manager (laisser vide si non applicable)" }
}

# Nettoyer les espaces des paramètres
$Prenom = $Prenom.Trim()
$Nom = $Nom.Trim()
$Titre = $Titre.Trim()
$Departement = $Departement.Trim()
if ($Manager) { $Manager = $Manager.Trim() }

# Validation des paramètres obligatoires
if (-not $Prenom -or -not $Nom -or -not $Titre -or -not $Departement) {
    Write-Host "Erreur: Les paramètres Prenom, Nom, Titre et Departement sont obligatoires." -ForegroundColor Red
    exit 1
}

# Appeler create_AD_user.ps1 pour effectuer la création
$createUserScript = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath "create_AD_user.ps1"

# Construire les paramètres dynamiquement
$scriptParams = @{
    Prenom = $Prenom
    Nom = $Nom
    Titre = $Titre
    Departement = $Departement
}

# Ajouter Manager seulement s'il n'est pas vide
if ($Manager -and $Manager -ne '') {
    $scriptParams['Manager'] = $Manager
}

try {
    & $createUserScript @scriptParams -ErrorAction Stop
    if ($LASTEXITCODE -ne 0) {
        throw "Le script de création a échoué avec le code de sortie $LASTEXITCODE"
    }
    Write-Host "`nUtilisateur créé avec succès." -ForegroundColor Green
} catch {
    Write-Host "`nErreur lors de la création: $_" -ForegroundColor Red
    exit 1
}