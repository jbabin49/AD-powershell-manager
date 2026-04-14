<#
.SYNOPSIS
    Modification des propriétés d'un utilisateur dans Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de modifier diverses propriétés d'un utilisateur dans Active Directory, telles que le nom, l'adresse e-mail, le titre et le statut du compte.
.EXAMPLE
    .\modify_AD_user.ps1 -Login "jdoe" -Email "jdoe@example.com"
    Exécute le script pour modifier l'adresse e-mail de l'utilisateur avec le login spécifié.
.PARAMETER Login
    Le nom d'utilisateur (login) de l'utilisateur à modifier. (obligatoire)
.PARAMETER {Email|Title|Description|Enable|City|Country|HomeDirectory|HomePhone|OfficePhone}
    La nouvelle valeur pour la propriété spécifiée (Email, Title, Description, Enable, City, Country, HomeDirectory, HomePhone, OfficePhone). (au moins une doit être spécifiée)
.NOTES
    Auteur: Julien BABIN
    Date de création: 30/01/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$Login,
    [string]$Email,
    [string]$Title,
    [string]$Description,
    [string]$City,
    [string]$Country,
    [string]$HomeDirectory,
    [string]$HomePhone,
    [string]$OfficePhone,
    [bool]$Enable
)

# Importer le module Active Directory
Import-Module ActiveDirectory

# Vérifier que le paramètre Login est fourni
if (-not $Login) {
    Write-Host "Le paramètre 'Login' est obligatoire." -ForegroundColor Red
    exit 1
}
else {
    # Récupérer l'utilisateur
    $user = Get-ADUser -Filter {SamAccountName -eq $Login}
    # Vérifier si l'utilisateur existe
    try {
        if (-not $user) {
            Write-Host "Utilisateur avec le login '$Login' non trouvé dans Active Directory." -ForegroundColor Red
            exit 1
        }

        # Construire un tableau de propriétés à modifier
        $setParams = @{ Identity = $user }
        if ($Email) { $setParams['EmailAddress'] = $Email }
        if ($Title) { $setParams['Title'] = $Title }
        if ($Description) { $setParams['Description'] = $Description }
        if ($City) { $setParams['City'] = $City }
        if ($Country) { $setParams['Country'] = $Country }
        if ($HomeDirectory) { $setParams['HomeDirectory'] = $HomeDirectory }
        if ($HomePhone) { $setParams['HomePhone'] = $HomePhone }
        if ($OfficePhone) { $setParams['OfficePhone'] = $OfficePhone }
        if ($PSBoundParameters.ContainsKey('Enable')) { $setParams['Enabled'] = $Enable }
        
        # Vérifier qu'au moins une propriété est à modifier
        if ($setParams.Count -eq 1) {
            Write-Host "Aucune propriété à modifier spécifiée." -ForegroundColor Yellow
            exit 1
        }
        else {
            # Mettre à jour l'utilisateur
            Set-ADUser @setParams
            Write-Host "Utilisateur '$Login' mis à jour avec succès." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Erreur lors de la mise à jour de l'utilisateur '$Login'." -ForegroundColor Red
        exit 1
    }
}