<#
.SYNOPSIS
    Génère un rapport HTML complet sur Active Directory.
.DESCRIPTION
    Ce script PowerShell génère un rapport HTML détaillé incluant :
    - Nombre total d'utilisateurs (actifs/désactifs)
    - Nombre total de groupes et d'OUs
    - Top 10 des groupes avec le plus de membres
    - Liste des utilisateurs dont le mot de passe n'expire jamais
    - Liste des utilisateurs avec des mots de passe expirés
    - Statistiques par département
.EXAMPLE
    .\report_AD_complete.ps1
    Génère le rapport HTML complet et l'exporte vers le chemin par défaut.

    .\report_AD_complete.ps1 -ExportPath "C:\Reports\rapport_complet.html"
    Génère le rapport et l'exporte vers le fichier spécifié.

    .\report_AD_complete.ps1 -NoExport
    Affiche uniquement les résultats sans exporter en HTML.
.PARAMETER ExportPath
    Chemin complet du fichier HTML d'export. (facultatif, par défaut: C:\Reports\report_AD_complete_YYYYMMDD_HHMMSS.html)
.PARAMETER NoExport
    Si spécifié, n'exporte pas les résultats en HTML, affiche uniquement à l'écran. (facultatif)
.NOTES
    Auteur: Julien BABIN
    Date: 02/02/2026
    Version: 1.0
    Dépendances: Module ActiveDirectory, Droits de lecture AD
#>

param (
    [string]$ExportPath,
    [switch]$NoExport
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function Get-PasswordPolicy {
    $policy = Get-ADDefaultDomainPasswordPolicy -ErrorAction SilentlyContinue
    return $policy
}

Function Get-UserPasswordStatus {
    param (
        [object]$User,
        [SecureString]$PasswordPolicy
    )
    
    try {
        $userFlags = $User.UserAccountControl
        
        # Vérifier le flag DONT_EXPIRE_PASSWORD (65536)
        if ($userFlags -band 65536) {
            return "N'expire jamais"
        }
        
        if ($User.PasswordLastSet) {
            $passwordAge = (Get-Date) - $User.PasswordLastSet
            $maxAge = $PasswordPolicy.MaxPasswordAge.Days
            
            if ($passwordAge.Days -gt $maxAge) {
                return "Expiré"
            } else {
                return "Valide"
            }
        } else {
            return "Jamais défini"
        }
    } catch {
        return "Erreur"
    }
}

Function generate_HTMLReport {
    param (
        [hashtable]$ReportData
    )
    
    $generationDate = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    
    # Construction des sections HTML
    $top10GroupsHtml = ""
    if ($ReportData.Top10Groups.Count -gt 0) {
        $top10GroupsHtml = "<table>`n<tr><th>Rang</th><th>Nom du Groupe</th><th>Nombre de Membres</th><th>Description</th></tr>`n"
        $i = 1
        foreach ($group in $ReportData.Top10Groups) {
            $top10GroupsHtml += "<tr><td>$i</td><td>$($group.Name)</td><td><strong>$($group.MemberCount)</strong></td><td>$($group.Description)</td></tr>`n"
            $i++
        }
        $top10GroupsHtml += "</table>"
    } else {
        $top10GroupsHtml = '<div class="no-data">Aucun groupe trouvé.</div>'
    }
    
    # Mots de passe n'expirant jamais
    $passwordNeverExpiresHtml = ""
    if ($ReportData.PasswordNeverExpires.Count -gt 0) {
        $count = $ReportData.PasswordNeverExpires.Count
        $passwordNeverExpiresHtml = "<div class='warning'>`n⚠️ <strong>Attention :</strong> $count utilisateur(s) ont un mot de passe qui n'expire jamais. À considérer pour des raisons de sécurité.`n</div>`n"
        $passwordNeverExpiresHtml += "<table>`n<tr><th>Login</th><th>Nom Complet</th><th>Email</th><th>Département</th><th>Titre</th></tr>`n"
        foreach ($user in $ReportData.PasswordNeverExpires) {
            $passwordNeverExpiresHtml += "<tr><td>$($user.SamAccountName)</td><td>$($user.Name)</td><td>$($user.EmailAddress)</td><td>$($user.Department)</td><td>$($user.Title)</td></tr>`n"
        }
        $passwordNeverExpiresHtml += "</table>"
    } else {
        $passwordNeverExpiresHtml = '<div class="success">✓ Aucun utilisateur avec mot de passe qui n''expire jamais.</div>'
    }
    
    # Mots de passe expirés
    $passwordExpiredHtml = ""
    if ($ReportData.PasswordExpired.Count -gt 0) {
        $count = $ReportData.PasswordExpired.Count
        $passwordExpiredHtml = "<div class='error'>`n❌ <strong>Attention :</strong> $count utilisateur(s) ont un mot de passe expiré. Action requise.`n</div>`n"
        $passwordExpiredHtml += "<table>`n<tr><th>Login</th><th>Nom Complet</th><th>Email</th><th>Dernier Changement</th><th>Jours Écoulés</th></tr>`n"
        foreach ($user in $ReportData.PasswordExpired) {
            $passwordExpiredHtml += "<tr><td>$($user.SamAccountName)</td><td>$($user.Name)</td><td>$($user.EmailAddress)</td><td>$($user.PasswordLastSetDate)</td><td><strong>$($user.DaysSinceLastSet)</strong></td></tr>`n"
        }
        $passwordExpiredHtml += "</table>"
    } else {
        $passwordExpiredHtml = '<div class="success">✓ Aucun utilisateur avec mot de passe expiré.</div>'
    }
    
    # Statistiques par département
    $departmentStatsHtml = ""
    if ($ReportData.DepartmentStats.Count -gt 0) {
        foreach ($dept in $ReportData.DepartmentStats) {
            $departmentStatsHtml += "<div class='dept-stat'>`n"
            $departmentStatsHtml += "<strong>$($dept.Department)</strong><br/>`n"
            $departmentStatsHtml += "Utilisateurs actifs: <strong style='color: #28a745;'>$($dept.ActiveUsers)</strong> | `n"
            $departmentStatsHtml += "Utilisateurs désactivés: <strong style='color: #dc3545;'>$($dept.DisabledUsers)</strong> | `n"
            $departmentStatsHtml += "Total: <strong>$($dept.TotalUsers)</strong>`n"
            $departmentStatsHtml += "</div>`n"
        }
    } else {
        $departmentStatsHtml = '<div class="no-data">Aucune information de département.</div>'
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport Complet Active Directory</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            line-height: 1.6;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 30px;
        }
        
        section {
            margin-bottom: 40px;
            page-break-inside: avoid;
        }
        
        section h2 {
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-card h3 {
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 10px;
        }
        
        .stat-card .number {
            font-size: 2.5em;
            font-weight: bold;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
            background: white;
            border: 1px solid #ddd;
            border-radius: 5px;
            overflow: hidden;
        }
        
        table th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        
        table td {
            padding: 12px 15px;
            border-bottom: 1px solid #ddd;
        }
        
        table tr:nth-child(even) {
            background: #f8f9fa;
        }
        
        table tr:hover {
            background: #e8e9f3;
        }
        
        .no-data {
            text-align: center;
            color: #999;
            padding: 30px;
            font-style: italic;
        }
        
        .warning {
            background: #fff3cd;
            color: #856404;
            padding: 12px;
            border-radius: 4px;
            border-left: 4px solid #ffc107;
            margin-bottom: 15px;
        }
        
        .success {
            background: #d4edda;
            color: #155724;
            padding: 12px;
            border-radius: 4px;
            border-left: 4px solid #28a745;
            margin-bottom: 15px;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 12px;
            border-radius: 4px;
            border-left: 4px solid #dc3545;
            margin-bottom: 15px;
        }
        
        footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #999;
            border-top: 1px solid #ddd;
        }
        
        .dept-stat {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }
        
        .dept-stat strong {
            color: #667eea;
        }
        
        @media print {
            body {
                background: white;
                padding: 0;
            }
            .container {
                box-shadow: none;
            }
            section {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 Rapport Complet Active Directory</h1>
            <p>Généré le $generationDate</p>
        </header>
        
        <div class="content">
            <!-- SECTION STATISTIQUES GLOBALES -->
            <section>
                <h2>📈 Statistiques Globales</h2>
                <div class="stats-grid">
                    <div class="stat-card">
                        <h3>Utilisateurs Actifs</h3>
                        <div class="number">$($ReportData.UsersActive)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Utilisateurs Désactivés</h3>
                        <div class="number">$($ReportData.UsersDisabled)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Total Utilisateurs</h3>
                        <div class="number">$($ReportData.UsersTotal)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Groupes</h3>
                        <div class="number">$($ReportData.GroupsTotal)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Unités Organisationnelles</h3>
                        <div class="number">$($ReportData.OUTotal)</div>
                    </div>
                    <div class="stat-card">
                        <h3>Départements</h3>
                        <div class="number">$($ReportData.DepartmentsTotal)</div>
                    </div>
                </div>
            </section>
            
            <!-- SECTION TOP 10 GROUPES -->
            <section>
                <h2>👥 Top 10 Groupes avec le Plus de Membres</h2>
                $top10GroupsHtml
            </section>
            
            <!-- SECTION MOTS DE PASSE QUI N'EXPIRENT JAMAIS -->
            <section>
                <h2>🔓 Utilisateurs avec Mots de Passe qui N'Expirent Jamais</h2>
                $passwordNeverExpiresHtml
            </section>
            
            <!-- SECTION MOTS DE PASSE EXPIRÉS -->
            <section>
                <h2>⏰ Utilisateurs avec Mots de Passe Expirés</h2>
                $passwordExpiredHtml
            </section>
            
            <!-- SECTION STATISTIQUES PAR DÉPARTEMENT -->
            <section>
                <h2>🏢 Statistiques par Département</h2>
                $departmentStatsHtml
            </section>
        </div>
        
        <footer>
            <p>Rapport généré par le script PowerShell de gestion Active Directory</p>
            <p>TechSecure - $(Get-Date -Format 'yyyy')</p>
        </footer>
    </div>
</body>
</html>
"@

    return $html
}

# Définir le chemin d'export par défaut
if (-not $ExportPath -and -not $NoExport) {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportDir = "C:\Reports"
    if (-not (Test-Path -Path $reportDir)) {
        try {
            New-Item -ItemType Directory -Path $reportDir -ErrorAction Stop | Out-Null
            Write-Host "Répertoire de rapports créé: $reportDir" -ForegroundColor Green
        } catch {
            Write-Host "Erreur lors de la création du répertoire: $_" -ForegroundColor Red
            $reportDir = "."
        }
    }
    $ExportPath = Join-Path -Path $reportDir -ChildPath "report_AD_complete_$dateStr.html"
}

Write-Host "`nGénération du rapport complet Active Directory..." -ForegroundColor Cyan
Write-Host "==================================================`n"

try {
    # RÉCUPÉRATION DES DONNÉES
    Write-Host "Récupération des données..." -ForegroundColor Yellow
    
    # Utilisateurs
    $allUsers = Get-ADUser -Filter * -Properties Department, Title, EmailAddress, PasswordLastSet, UserAccountControl -ErrorAction Stop
    $usersActive = $allUsers | Where-Object { $_.Enabled -eq $true }
    $usersDisabled = $allUsers | Where-Object { $_.Enabled -eq $false }
    
    # Groupes
    $allGroups = Get-ADGroup -Filter * -Properties Members -ErrorAction Stop
    
    # OUs
    $allOUs = Get-ADOrganizationalUnit -Filter * -ErrorAction Stop
    
    # Politique de mot de passe
    $passwordPolicy = Get-PasswordPolicy
    
    Write-Host "Données récupérées: $($allUsers.Count) utilisateurs, $($allGroups.Count) groupes, $($allOUs.Count) OUs" -ForegroundColor Green
    
    # TRAITEMENT DES DONNÉES
    Write-Host "Traitement des données..." -ForegroundColor Yellow
    
    # Top 10 des groupes
    $top10Groups = $allGroups | 
        Select-Object Name, Description, @{Name="MemberCount"; Expression={ ($_.Members).Count }} | 
        Sort-Object -Property MemberCount -Descending | 
        Select-Object -First 10
    
    # Utilisateurs avec mots de passe qui n'expirent jamais
    $passwordNeverExpires = $allUsers | Where-Object { 
        ($_.UserAccountControl -band 65536) -eq 65536 
    } | Select-Object SamAccountName, Name, EmailAddress, Department, Title
    
    # Utilisateurs avec mots de passe expirés
    $passwordExpired = @()
    foreach ($user in $allUsers) {
        $status = Get-UserPasswordStatus -User $user -PasswordPolicy $passwordPolicy
        if ($status -eq "Expiré") {
            $passwordExpired += [PSCustomObject]@{
                SamAccountName = $user.SamAccountName
                Name = $user.Name
                EmailAddress = $user.EmailAddress
                PasswordLastSetDate = if ($user.PasswordLastSet) { $user.PasswordLastSet.ToString("dd/MM/yyyy") } else { "N/A" }
                DaysSinceLastSet = if ($user.PasswordLastSet) { ((Get-Date) - $user.PasswordLastSet).Days } else { "N/A" }
            }
        }
    }
    
    # Statistiques par département
    $departments = $allUsers | Where-Object { $_.Department } | Group-Object -Property Department
    $departmentStats = @()
    
    foreach ($dept in $departments) {
        $activeInDept = ($dept.Group | Where-Object { $_.Enabled -eq $true }).Count
        $disabledInDept = ($dept.Group | Where-Object { $_.Enabled -eq $false }).Count
        
        $departmentStats += [PSCustomObject]@{
            Department = $dept.Name
            ActiveUsers = $activeInDept
            DisabledUsers = $disabledInDept
            TotalUsers = $dept.Count
        }
    }
    
    # Ajouter les utilisateurs sans département
    $usersNoDept = $allUsers | Where-Object { -not $_.Department }
    if ($usersNoDept.Count -gt 0) {
        $activeNoDept = ($usersNoDept | Where-Object { $_.Enabled -eq $true }).Count
        $disabledNoDept = ($usersNoDept | Where-Object { $_.Enabled -eq $false }).Count
        
        $departmentStats += [PSCustomObject]@{
            Department = "(Non défini)"
            ActiveUsers = $activeNoDept
            DisabledUsers = $disabledNoDept
            TotalUsers = $usersNoDept.Count
        }
    }
    
    # Tri par département
    $departmentStats = $departmentStats | Sort-Object -Property Department
    
    # Construction du hashtable de données
    $reportData = @{
        UsersActive = $usersActive.Count
        UsersDisabled = $usersDisabled.Count
        UsersTotal = $allUsers.Count
        GroupsTotal = $allGroups.Count
        OUTotal = $allOUs.Count
        DepartmentsTotal = ($departments | Measure-Object).Count
        Top10Groups = $top10Groups
        PasswordNeverExpires = $passwordNeverExpires
        PasswordExpired = $passwordExpired
        DepartmentStats = $departmentStats
    }
    
    # GÉNÉRATION DU RAPPORT
    Write-Host "Génération du rapport HTML..." -ForegroundColor Yellow
    $htmlContent = generate_HTMLReport -ReportData $reportData
    
    # AFFICHAGE RÉSUMÉ
    Write-Host "`n════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "RÉSUMÉ DU RAPPORT" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Utilisateurs actifs: $($reportData.UsersActive)" -ForegroundColor Green
    Write-Host "Utilisateurs désactivés: $($reportData.UsersDisabled)" -ForegroundColor Yellow
    Write-Host "Total utilisateurs: $($reportData.UsersTotal)" -ForegroundColor White
    Write-Host "Nombre de groupes: $($reportData.GroupsTotal)" -ForegroundColor White
    Write-Host "Nombre d'OUs: $($reportData.OUTotal)" -ForegroundColor White
    Write-Host "Mots de passe n'expirant jamais: $($reportData.PasswordNeverExpires.Count)" -ForegroundColor Red
    Write-Host "Mots de passe expirés: $($reportData.PasswordExpired.Count)" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    # EXPORT HTML
    if (-not $NoExport) {
        $htmlContent | Out-File -FilePath $ExportPath -Encoding UTF8 -ErrorAction Stop
        Write-Host "✓ Rapport exporté avec succès vers: $ExportPath" -ForegroundColor Green
    } else {
        Write-Host "✓ Rapport généré (aucun export effectué)." -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Erreur lors de la génération du rapport: $_" -ForegroundColor Red
    exit 1
}
