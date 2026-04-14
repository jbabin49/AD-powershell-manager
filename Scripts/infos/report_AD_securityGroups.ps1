<#
.SYNOPSIS
    Génère un rapport détaillé des groupes de sécurité dans Active Directory.
.DESCRIPTION
    Ce script PowerShell liste tous les groupes de sécurité et génère un rapport détaillé incluant le nombre de membres,
    l'identification des groupes vides, et une liste complète des membres pour chaque groupe.
    Le rapport est exporté en HTML avec mise en forme CSS pour une meilleure présentation.
.EXAMPLE
    .\report_AD_securityGroups.ps1
    Affiche le résumé des groupes et exporte le rapport détaillé en HTML.

    .\report_AD_securityGroups.ps1 -ExportPath "C:\Reports\groupes.html"
    Exporte le rapport vers le fichier HTML spécifié.

    .\report_AD_securityGroups.ps1 -NoExport
    Affiche uniquement le résumé sans exporter en HTML.

    .\report_AD_securityGroups.ps1 -IncludeDistribution
    Inclut également les groupes de distribution (pas seulement les groupes de sécurité).
.PARAMETER ExportPath
    Chemin complet du fichier HTML d'export. (facultatif, par défaut: C:\Reports\security_groups_YYYYMMDD_HHMMSS.html)
.PARAMETER NoExport
    Si spécifié, affiche uniquement le résumé sans exporter en HTML. (facultatif)
.PARAMETER IncludeDistribution
    Si spécifié, inclut également les groupes de distribution. (facultatif)
.PARAMETER LogFilePath
    Le chemin du fichier journal où le rapport sera enregistré. (facultatif)
    Par défaut, un fichier journal est créé dans le répertoire "C:\logs\group_reports".
.NOTES
    Auteur: Julien BABIN
    Date: 02/02/2026
    Version: 1.1
    Dépendances: Module ActiveDirectory, Droits de lecture AD
#>

param (
    [string]$ExportPath,
    [switch]$NoExport,
    [switch]$IncludeDistribution,
    [string]$LogFilePath
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function define_logfile {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $logDir = "C:\logs\group_reports"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    $logFileName = "security_groups_report_$dateStr.log"
    return Join-Path -Path $logDir -ChildPath $logFileName
}

Function log_message {
    param (
        [string]$Message,
        [string]$LogFile
    )
    if ($LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] $Message"
        Add-Content -Path $LogFile -Value $logEntry
    }
}

# Initialiser le fichier de log si non spécifié
if (-not $LogFilePath) {
    $LogFilePath = define_logfile
}

log_message -Message "=== Script démarré: report_AD_securityGroups.ps1 ===" -LogFile $LogFilePath

# Définir le chemin d'export par défaut si non spécifié
if (-not $ExportPath -and -not $NoExport) {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportDir = "C:\Reports"
    if (-not (Test-Path -Path $reportDir)) {
        try {
            New-Item -ItemType Directory -Path $reportDir -ErrorAction Stop | Out-Null
            Write-Host "Répertoire de rapports créé: $reportDir" -ForegroundColor Green
            log_message -Message "Répertoire de rapports créé: $reportDir" -LogFile $LogFilePath
        } catch {
            Write-Host "Erreur lors de la création du répertoire de rapports: $_" -ForegroundColor Red
            Write-Host "Utilisation du répertoire actuel." -ForegroundColor Yellow
            log_message -Message "Erreur lors de la création du répertoire: $_" -LogFile $LogFilePath
            $reportDir = "."
        }
    }
    $ExportPath = Join-Path -Path $reportDir -ChildPath "security_groups_$dateStr.html"
}

Write-Host "`nGénération du rapport des groupes de sécurité..." -ForegroundColor Cyan
Write-Host "=================================================================`n"
log_message -Message "Début de la génération du rapport" -LogFile $LogFilePath

try {
    # Récupérer les groupes (de sécurité ou distribution selon le paramètre)
    if ($IncludeDistribution) {
        $groups = Get-ADGroup -Filter * -Properties Description, Member -ErrorAction Stop | Sort-Object Name
        $groupType = "sécurité ET distribution"
        log_message -Message "Récupération des groupes de sécurité ET de distribution" -LogFile $LogFilePath
    } else {
        $groups = Get-ADGroup -Filter { GroupCategory -eq 'Security' } -Properties Description, Member -ErrorAction Stop | Sort-Object Name
        $groupType = "sécurité"
        log_message -Message "Récupération des groupes de sécurité uniquement" -LogFile $LogFilePath
    }
    
    if (-not $groups) {
        Write-Host "Aucun groupe trouvé dans Active Directory." -ForegroundColor Yellow
        log_message -Message "Aucun groupe trouvé dans Active Directory" -LogFile $LogFilePath
        log_message -Message "=== Script terminé ===" -LogFile $LogFilePath
        exit 0
    }
    
    Write-Host "Nombre total de groupes: $($groups.Count)" -ForegroundColor Cyan
    log_message -Message "Nombre total de groupes trouvés: $($groups.Count)" -LogFile $LogFilePath
    
    # Traiter chaque groupe
    $groupsReport = @()
    $emptyGroups = 0
    $totalMembers = 0
    
    log_message -Message "`nTraitement des groupes..." -LogFile $LogFilePath
    
    foreach ($group in $groups) {
        $memberCount = if ($group.Member) { @($group.Member).Count } else { 0 }
        $totalMembers += $memberCount
        
        if ($memberCount -eq 0) {
            $emptyGroups++
        }
        
        log_message -Message "  - Groupe: $($group.Name) | Membres: $memberCount" -LogFile $LogFilePath
        
        # Récupérer les détails des membres
        $membersList = @()
        if ($group.Member -and $group.Member.Count -gt 0) {
            foreach ($memberDN in $group.Member) {
                try {
                    $member = Get-ADObject -Identity $memberDN -Properties DisplayName, SamAccountName, ObjectClass -ErrorAction Stop
                    $membersList += [PSCustomObject]@{
                        Name = if ($member.DisplayName) { $member.DisplayName } else { $member.Name }
                        Login = $member.SamAccountName
                        Type = $member.ObjectClass
                    }
                } catch {
                    $membersList += [PSCustomObject]@{
                        Name = "Erreur lecture"
                        Login = ""
                        Type = ""
                    }
                }
            }
            $membersList = $membersList | Sort-Object -Property Name
        }
        
        $groupsReport += [PSCustomObject]@{
            Nom = $group.Name
            SamAccountName = $group.SamAccountName
            Description = if ($group.Description) { $group.Description } else { "-" }
            NombreMembres = $memberCount
            Membres = $membersList
            Vide = ($memberCount -eq 0)
        }
    }
    
    # Trier par nombre de membres décroissant
    $groupsReport = $groupsReport | Sort-Object -Property NombreMembres -Descending
    
    # Afficher le résumé
    Write-Host "Résumé:" -ForegroundColor Cyan
    Write-Host "  - Total de groupes: $($groupsReport.Count)" -ForegroundColor White
    Write-Host "  - Groupes vides: $emptyGroups" -ForegroundColor Red
    Write-Host "  - Nombre total de memberships: $totalMembers" -ForegroundColor Green
    Write-Host "  - Moyenne de membres par groupe: $([math]::Round($totalMembers / $groupsReport.Count, 2))" -ForegroundColor White
    
    log_message -Message "`n=== Résumé ===" -LogFile $LogFilePath
    log_message -Message "Total de groupes: $($groupsReport.Count)" -LogFile $LogFilePath
    log_message -Message "Groupes vides: $emptyGroups" -LogFile $LogFilePath
    log_message -Message "Nombre total de memberships: $totalMembers" -LogFile $LogFilePath
    log_message -Message "Moyenne de membres par groupe: $([math]::Round($totalMembers / $groupsReport.Count, 2))" -LogFile $LogFilePath
    
    Write-Host "`nTop 10 groupes avec le plus de membres:" -ForegroundColor Cyan
    $groupsReport | Select-Object -First 10 | Format-Table -AutoSize -Property Nom, NombreMembres, Description
    
    log_message -Message "`nTop 10 groupes avec le plus de membres:" -LogFile $LogFilePath
    foreach ($topGroup in ($groupsReport | Select-Object -First 10)) {
        log_message -Message "  - $($topGroup.Nom): $($topGroup.NombreMembres) membres" -LogFile $LogFilePath
    }
    
    if ($emptyGroups -gt 0) {
        Write-Host "`nGroupes vides trouvés:" -ForegroundColor Yellow
        $groupsReport | Where-Object { $_.Vide -eq $true } | Format-Table -AutoSize -Property Nom, Description
        
        log_message -Message "`nGroupes vides:" -LogFile $LogFilePath
        foreach ($emptyGroup in ($groupsReport | Where-Object { $_.Vide -eq $true })) {
            log_message -Message "  - $($emptyGroup.Nom): $($emptyGroup.Description)" -LogFile $LogFilePath
        }
    }
    
    # Générer le rapport HTML
    if (-not $NoExport) {
        Write-Host "`nGénération du rapport HTML..." -ForegroundColor Cyan
        log_message -Message "`nGénération du rapport HTML..." -LogFile $LogFilePath
        
        $htmlContent = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport des Groupes de Sécurité Active Directory</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .header {
            border-bottom: 3px solid #0078d4;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        
        h1 {
            color: #0078d4;
            margin-bottom: 10px;
            font-size: 28px;
        }
        
        .report-date {
            color: #666;
            font-size: 14px;
            margin-top: 10px;
        }
        
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.15);
        }
        
        .summary-card.empty {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }
        
        .summary-card.total {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }
        
        .summary-card.members {
            background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
        }
        
        .summary-value {
            font-size: 32px;
            font-weight: bold;
            margin: 10px 0;
        }
        
        .summary-label {
            font-size: 14px;
            opacity: 0.9;
        }
        
        .filters {
            margin-bottom: 30px;
            padding: 15px;
            background-color: #f0f0f0;
            border-radius: 5px;
        }
        
        .filter-item {
            display: inline-block;
            margin-right: 20px;
        }
        
        .filter-label {
            font-weight: bold;
            color: #333;
        }
        
        .group-section {
            margin-bottom: 40px;
            border-left: 4px solid #0078d4;
            padding-left: 20px;
        }
        
        .group-header {
            background-color: #e8f4f8;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 15px;
            border-left: 4px solid #0078d4;
        }
        
        .group-title {
            font-size: 18px;
            font-weight: bold;
            color: #0078d4;
            margin-bottom: 10px;
        }
        
        .group-info {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 15px;
            font-size: 14px;
        }
        
        .group-info-item {
            margin-bottom: 5px;
        }
        
        .group-info-label {
            font-weight: bold;
            color: #555;
        }
        
        .group-info-value {
            color: #333;
        }
        
        .member-count {
            display: inline-block;
            background-color: #0078d4;
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 12px;
        }
        
        .member-count.empty {
            background-color: #d13438;
        }
        
        .members-list {
            background-color: #f9f9f9;
            padding: 15px;
            border-radius: 5px;
            margin-top: 10px;
        }
        
        .members-list.empty {
            color: #999;
            font-style: italic;
        }
        
        .member-item {
            padding: 8px 0;
            border-bottom: 1px solid #e0e0e0;
            display: flex;
            justify-content: space-between;
        }
        
        .member-item:last-child {
            border-bottom: none;
        }
        
        .member-name {
            font-weight: 500;
            color: #0078d4;
        }
        
        .member-type {
            background-color: #e0e0e0;
            padding: 2px 8px;
            border-radius: 3px;
            font-size: 12px;
            color: #555;
        }
        
        .member-type.user {
            background-color: #d7e8f5;
            color: #0078d4;
        }
        
        .member-type.group {
            background-color: #e8f5e9;
            color: #2e7d32;
        }
        
        .member-type.computer {
            background-color: #fff3e0;
            color: #e65100;
        }
        
        .empty-group {
            background-color: #ffebee;
            padding: 15px;
            border-radius: 5px;
            color: #c62828;
            font-weight: bold;
            margin-top: 10px;
        }
        
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
            font-size: 12px;
            text-align: center;
        }
        
        .no-members {
            color: #999;
            font-style: italic;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        
        th {
            background-color: #0078d4;
            color: white;
            font-weight: bold;
        }
        
        tr:hover {
            background-color: #f0f0f0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Rapport des Groupes de Sécurité Active Directory</h1>
            <p class="report-date">Généré le $(Get-Date -Format 'dd/MM/yyyy à HH:mm:ss')</p>
        </div>
        
        <div class="summary">
            <div class="summary-card total">
                <div class="summary-label">Total de groupes</div>
                <div class="summary-value">$($groupsReport.Count)</div>
            </div>
            <div class="summary-card empty">
                <div class="summary-label">Groupes vides</div>
                <div class="summary-value">$emptyGroups</div>
            </div>
            <div class="summary-card members">
                <div class="summary-label">Total memberships</div>
                <div class="summary-value">$totalMembers</div>
            </div>
            <div class="summary-card">
                <div class="summary-label">Moyenne/groupe</div>
                <div class="summary-value">$([math]::Round($totalMembers / $groupsReport.Count, 2))</div>
            </div>
        </div>
        
        <div class="filters">
            <div class="filter-item">
                <span class="filter-label">Type de groupes:</span>
                <span>$groupType</span>
            </div>
        </div>
"@

        # Ajouter chaque groupe au rapport
        foreach ($group in $groupsReport) {
            $memberCountClass = if ($group.Vide) { "empty" } else { "" }
            
            $htmlContent += @"
        <div class="group-section">
            <div class="group-header">
                <div class="group-title">
                    $($group.Nom)
                    <span class="member-count $memberCountClass">$($group.NombreMembres) membre$(if ($group.NombreMembres -ne 1) {'s'})</span>
                </div>
                <div class="group-info">
                    <div class="group-info-item">
                        <span class="group-info-label">Compte:</span>
                        <span class="group-info-value">$($group.SamAccountName)</span>
                    </div>
                    <div class="group-info-item">
                        <span class="group-info-label">Description:</span>
                        <span class="group-info-value">$($group.Description)</span>
                    </div>
                </div>
            </div>

"@

            if ($group.Vide) {
                $htmlContent += @"
            <div class="empty-group">
                ⚠️ Ce groupe est vide
            </div>
"@
            } else {
                $htmlContent += @"
            <div class="members-list">
                <table>
                    <thead>
                        <tr>
                            <th>Nom</th>
                            <th>Login</th>
                            <th>Type</th>
                        </tr>
                    </thead>
                    <tbody>
"@
                foreach ($member in $group.Membres) {
                    $memberTypeClass = ($member.Type).ToLower()
                    $htmlContent += @"
                        <tr>
                            <td><span class="member-name">$($member.Name)</span></td>
                            <td>$($member.Login)</td>
                            <td><span class="member-type $memberTypeClass">$($member.Type)</span></td>
                        </tr>
"@
                }
                
                $htmlContent += @"
                    </tbody>
                </table>
            </div>
"@
            }
            
            $htmlContent += @"
        </div>

"@
        }
        
        # Clôture HTML
        $htmlContent += @"
        <div class="footer">
            <p>Rapport généré par le script PowerShell report_AD_securityGroups.ps1</p>
            <p>Tous les groupes et memberships sont inclus dans ce rapport.</p>
        </div>
    </div>
</body>
</html>
"@

        try {
            $htmlContent | Out-File -FilePath $ExportPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "`nRapport HTML exporté avec succès vers: $ExportPath" -ForegroundColor Green
            log_message -Message "Rapport HTML exporté avec succès vers: $ExportPath" -LogFile $LogFilePath
            log_message -Message "Fichier log créé: $LogFilePath" -LogFile $LogFilePath
            log_message -Message "=== Script terminé avec succès ===" -LogFile $LogFilePath
        } catch {
            Write-Host "`nErreur lors de l'export du rapport HTML: $_" -ForegroundColor Red
            log_message -Message "Erreur lors de l'export du rapport HTML: $_" -LogFile $LogFilePath
            log_message -Message "=== Script terminé avec erreur ===" -LogFile $LogFilePath
            exit 1
        }
    } else {
        Write-Host "`nAucun export HTML effectué (option -NoExport spécifiée)." -ForegroundColor Yellow
        log_message -Message "Aucun export HTML effectué (option -NoExport spécifiée)" -LogFile $LogFilePath
        log_message -Message "Fichier log créé: $LogFilePath" -LogFile $LogFilePath
        log_message -Message "=== Script terminé ===" -LogFile $LogFilePath
    }
    
} catch {
    Write-Host "Erreur lors de la récupération des groupes: $_" -ForegroundColor Red
    log_message -Message "Erreur lors de la récupération des groupes: $_" -LogFile $LogFilePath
    log_message -Message "=== Script terminé avec erreur ===" -LogFile $LogFilePath
    exit 1
}
