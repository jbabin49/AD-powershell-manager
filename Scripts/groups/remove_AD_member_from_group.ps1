<#
.SYNOPSIS
    Retire des membres (utilisateurs ou groupes) d'un groupe Active Directory.
.DESCRIPTION
    Ce script PowerShell permet de retirer un ou plusieurs membres d'un groupe de sécurité dans Active Directory.
    Il peut retirer des utilisateurs individuels, des groupes, ou traiter un fichier CSV contenant plusieurs retraits.
    Le script supporte un mode interactif pour faciliter l'utilisation.
.EXAMPLE
    .\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -Login "jdoe"
    Retire l'utilisateur "jdoe" du groupe "IT_Group".

    .\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -Login "jdoe,jsmith"
    Retire plusieurs utilisateurs du groupe "IT_Group".

    .\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -MemberGroup "HR_Group"
    Retire le groupe "HR_Group" du groupe "IT_Group".

    .\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -MemberGroup "HR_Group,Support_Group"
    Retire plusieurs groupes du groupe "IT_Group".

    .\remove_AD_member_from_group.ps1 -FilePath "C:\members_to_remove.csv"
    Retire les membres listés dans le fichier CSV.
    Le fichier doit contenir les colonnes: SourceGroup, Login (facultatif), MemberGroup (facultatif).

    .\remove_AD_member_from_group.ps1 -Auto
    Mode interactif avec prompts pour chaque paramètre.
.PARAMETER SourceGroup
    Le nom du groupe duquel retirer les membres. (obligatoire si FilePath n'est pas spécifié)
.PARAMETER Login
    Le(s) login(s) des utilisateurs à retirer du groupe, séparés par des virgules. (facultatif)
.PARAMETER MemberGroup
    Le(s) nom(s) des groupes à retirer du groupe source, séparés par des virgules. (facultatif)
.PARAMETER FilePath
    Chemin vers un fichier CSV contenant les membres à retirer.
    Le fichier doit avoir les colonnes: SourceGroup, Login (facultatif), MemberGroup (facultatif).
    Au moins une des colonnes Login ou MemberGroup doit être renseignée pour chaque ligne. (facultatif)
.PARAMETER Auto
    Mode interactif avec prompts pour chaque paramètre. (facultatif)
.PARAMETER LogFilePath
    Le chemin du fichier journal où les actions seront enregistrées. (facultatif)
    Par défaut, un fichier journal est créé dans le répertoire "C:\logs\member_removal".
.NOTES
    Auteur: Julien BABIN
    Date: 02/02/2026
    Version: 1.1
    Dépendances: Module ActiveDirectory, Droits d'administration AD
#>

param (
    [string]$SourceGroup,
    [string]$Login,
    [string]$MemberGroup,
    [string]$FilePath,
    [switch]$Auto,
    [string]$LogFilePath
)

# Importer le module Active Directory
Import-Module ActiveDirectory

Function define_logfile {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $logDir = "C:\logs\member_removal"
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    $logFileName = "member_removal_$dateStr.log"
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

Function remove_user_from_group {
    param (
        [string]$GroupName,
        [string]$UserLogin,
        [string]$LogFile
    )
    
    try {
        # Vérifier que le groupe existe
        $group = Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction Stop
        if (-not $group) {
            $errorMsg = "Erreur: Le groupe '$GroupName' n'existe pas dans Active Directory."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return $false
        }
        
        # Vérifier que l'utilisateur existe
        $user = Get-ADUser -Filter "SamAccountName -eq '$UserLogin'" -ErrorAction Stop
        if (-not $user) {
            $errorMsg = "Erreur: L'utilisateur '$UserLogin' n'existe pas dans Active Directory."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return $false
        }
        
        # Vérifier que l'utilisateur est membre du groupe
        $isMember = Get-ADGroupMember -Identity $GroupName -ErrorAction Stop | Where-Object { $_.SamAccountName -eq $UserLogin }
        if (-not $isMember) {
            $warnMsg = "Avertissement: L'utilisateur '$UserLogin' n'est pas membre du groupe '$GroupName'."
            Write-Host $warnMsg -ForegroundColor Yellow
            log_message -Message $warnMsg -LogFile $LogFile
            return $false
        }
        
        # Retirer l'utilisateur du groupe
        Remove-ADGroupMember -Identity $GroupName -Members $UserLogin -Confirm:$false -ErrorAction Stop
        $successMsg = "Utilisateur '$UserLogin' retiré du groupe '$GroupName' avec succès."
        Write-Host $successMsg -ForegroundColor Green
        log_message -Message $successMsg -LogFile $LogFile
        return $true
        
    } catch {
        $errorMsg = "Erreur lors du retrait de l'utilisateur '$UserLogin' du groupe '${GroupName}': $_"
        Write-Host $errorMsg -ForegroundColor Red
        log_message -Message $errorMsg -LogFile $LogFile
        return $false
    }
}

Function remove_group_from_group {
    param (
        [string]$SourceGroupName,
        [string]$MemberGroupName,
        [string]$LogFile
    )
    
    try {
        # Vérifier que le groupe source existe
        $sourceGroup = Get-ADGroup -Filter "SamAccountName -eq '$SourceGroupName'" -ErrorAction Stop
        if (-not $sourceGroup) {
            $errorMsg = "Erreur: Le groupe source '$SourceGroupName' n'existe pas dans Active Directory."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return $false
        }
        
        # Vérifier que le groupe membre existe
        $memberGroup = Get-ADGroup -Filter "SamAccountName -eq '$MemberGroupName'" -ErrorAction Stop
        if (-not $memberGroup) {
            $errorMsg = "Erreur: Le groupe membre '$MemberGroupName' n'existe pas dans Active Directory."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return $false
        }
        
        # Vérifier que le groupe membre est bien membre du groupe source
        $isMember = Get-ADGroupMember -Identity $SourceGroupName -ErrorAction Stop | Where-Object { $_.SamAccountName -eq $MemberGroupName }
        if (-not $isMember) {
            $warnMsg = "Avertissement: Le groupe '$MemberGroupName' n'est pas membre du groupe '$SourceGroupName'."
            Write-Host $warnMsg -ForegroundColor Yellow
            log_message -Message $warnMsg -LogFile $LogFile
            return $false
        }
        
        # Retirer le groupe du groupe source
        Remove-ADGroupMember -Identity $SourceGroupName -Members $MemberGroupName -Confirm:$false -ErrorAction Stop
        $successMsg = "Groupe '$MemberGroupName' retiré du groupe '$SourceGroupName' avec succès."
        Write-Host $successMsg -ForegroundColor Green
        log_message -Message $successMsg -LogFile $LogFile
        return $true
        
    } catch {
        $errorMsg = "Erreur lors du retrait du groupe '$MemberGroupName' du groupe source '${SourceGroupName}': $_"
        Write-Host $errorMsg -ForegroundColor Red
        log_message -Message $errorMsg -LogFile $LogFile
        return $false
    }
}

Function process_csv_file {
    param (
        [string]$CsvFilePath,
        [string]$LogFile
    )
    
    try {
        log_message -Message "Début du traitement du fichier CSV: $CsvFilePath" -LogFile $LogFile
        
        # Vérifier que le fichier existe
        if (-not (Test-Path $CsvFilePath)) {
            $errorMsg = "Erreur: Le fichier '$CsvFilePath' n'existe pas."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return
        }
        
        # Importer le fichier CSV
        $members = Import-Csv -Path $CsvFilePath -ErrorAction Stop
        
        # Vérifier que le fichier contient la colonne SourceGroup
        if (-not ($members[0].PSObject.Properties.Name -contains "SourceGroup")) {
            $errorMsg = "Erreur: Le fichier CSV doit contenir la colonne 'SourceGroup'."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return
        }
        
        # Vérifier qu'au moins une des colonnes Login ou MemberGroup existe
        $hasLogin = $members[0].PSObject.Properties.Name -contains "Login"
        $hasMemberGroup = $members[0].PSObject.Properties.Name -contains "MemberGroup"
        
        if (-not $hasLogin -and -not $hasMemberGroup) {
            $errorMsg = "Erreur: Le fichier CSV doit contenir au moins une des colonnes 'Login' ou 'MemberGroup'."
            Write-Host $errorMsg -ForegroundColor Red
            log_message -Message $errorMsg -LogFile $LogFile
            return
        }
        
        $successCount = 0
        $failCount = 0
        
        foreach ($member in $members) {
            $sourceGroup = $member.SourceGroup.Trim()
            
            # Traiter les utilisateurs si la colonne Login existe et est renseignée
            if ($hasLogin -and $member.Login -and $member.Login.Trim() -ne '') {
                $logins = $member.Login -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
                foreach ($login in $logins) {
                    $login = $login.Trim()
                    if (remove_user_from_group -GroupName $sourceGroup -UserLogin $login) {
                        $successCount++
                    } else {
                        $failCount++
                    }
                }
            }
            
            # Traiter les groupes si la colonne MemberGroup existe et est renseignée
            if ($hasMemberGroup -and $member.MemberGroup -and $member.MemberGroup.Trim() -ne '') {
                $memberGroups = $member.MemberGroup -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
                foreach ($grp in $memberGroups) {
                    $grp = $grp.Trim()
                    if (remove_group_from_group -SourceGroupName $sourceGroup -MemberGroupName $grp) {
                        $successCount++
                    } else {
                        $failCount++
                    }
                }
            }
        }
        
        $summaryMsg = "Résumé: $successCount retrait(s) réussi(s), $failCount échec(s)."
        Write-Host "`n$summaryMsg" -ForegroundColor Cyan
        log_message -Message $summaryMsg -LogFile $LogFile
        
    } catch {
        $errorMsg = "Erreur lors du traitement du fichier CSV: $_"
        Write-Host $errorMsg -ForegroundColor Red
        log_message -Message $errorMsg -LogFile $LogFile
    }
}

# Initialiser le fichier de log si non spécifié
if (-not $LogFilePath) {
    $LogFilePath = define_logfile
}

log_message -Message "=== Script démarré: remove_AD_member_from_group.ps1 ===" -LogFile $LogFilePath

# Mode CSV
if ($FilePath) {
    process_csv_file -CsvFilePath $FilePath -LogFile $LogFilePath
    log_message -Message "=== Script terminé ===" -LogFile $LogFilePath
    exit 0
}

# Mode interactif
if ($Auto) {
    Write-Host "`nRetrait de membres d'un groupe Active Directory" -ForegroundColor Cyan
    Write-Host "=================================================`n"
    
    log_message -Message "Mode interactif activé" -LogFile $LogFilePath
    
    # Demander si l'utilisateur a un fichier CSV
    $csvChoice = Read-Host "Avez-vous un fichier CSV pour retirer plusieurs membres ? (O/N)"
    
    if ($csvChoice -eq 'O' -or $csvChoice -eq 'o') {
        $csvPath = Read-Host "Entrez le chemin du fichier CSV"
        process_csv_file -CsvFilePath $csvPath -LogFile $LogFilePath
        log_message -Message "=== Script terminé ===" -LogFile $LogFilePath
        exit 0
    }
    
    # Mode retrait individuel
    Write-Host "`nMode retrait individuel" -ForegroundColor Yellow
    $SourceGroup = Read-Host "Entrez le nom du groupe source (d'où retirer les membres)"
    
    $memberType = Read-Host "Voulez-vous retirer un utilisateur (U) ou un groupe (G) ?"
    
    if ($memberType -eq 'U' -or $memberType -eq 'u') {
        $Login = Read-Host "Entrez le(s) login(s) des utilisateurs à retirer (séparés par des virgules)"
    } elseif ($memberType -eq 'G' -or $memberType -eq 'g') {
        $MemberGroup = Read-Host "Entrez le(s) nom(s) des groupes à retirer (séparés par des virgules)"
    } else {
        Write-Host "Erreur: Choix invalide. Utilisez 'U' pour utilisateur ou 'G' pour groupe." -ForegroundColor Red
        exit 1
    }
}

# Validation du groupe source obligatoire
if (-not $SourceGroup) {
    $errorMsg = "Erreur: Le paramètre SourceGroup est obligatoire."
    Write-Host $errorMsg -ForegroundColor Red
    log_message -Message $errorMsg -LogFile $LogFilePath
    log_message -Message "=== Script terminé avec erreur ===" -LogFile $LogFilePath
    exit 1
}

# Validation qu'au moins un membre est spécifié
if (-not $Login -and -not $MemberGroup) {
    $errorMsg = "Erreur: Au moins un des paramètres Login ou MemberGroup doit être spécifié."
    Write-Host $errorMsg -ForegroundColor Red
    log_message -Message $errorMsg -LogFile $LogFilePath
    log_message -Message "=== Script terminé avec erreur ===" -LogFile $LogFilePath
    exit 1
}

log_message -Message "Paramètres validés - SourceGroup: $SourceGroup" -LogFile $LogFilePath

# Nettoyer les espaces
$SourceGroup = $SourceGroup.Trim()
if ($Login) { $Login = $Login.Trim() }
if ($MemberGroup) { $MemberGroup = $MemberGroup.Trim() }

$successCount = 0
$failCount = 0

# Traiter les utilisateurs si spécifiés
if ($Login) {
    $loginList = $Login -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($userLogin in $loginList) {
        $userLogin = $userLogin.Trim()
        if (remove_user_from_group -GroupName $SourceGroup -UserLogin $userLogin -LogFile $LogFilePath) {
            $successCount++
        } else {
            $failCount++
        }
    }
}

# Traiter les groupes si spécifiés
if ($MemberGroup) {
    $groupList = $MemberGroup -split '\s*,\s*' | Where-Object { $_ -and $_.Trim() -ne '' }
    foreach ($grp in $groupList) {
        $grp = $grp.Trim()
        if (remove_group_from_group -SourceGroupName $SourceGroup -MemberGroupName $grp -LogFile $LogFilePath) {
            $successCount++
        } else {
            $failCount++
        }
    }
}

$summaryMsg = "Résumé: $successCount retrait(s) réussi(s), $failCount échec(s)."
Write-Host "`n$summaryMsg" -ForegroundColor Cyan
log_message -Message $summaryMsg -LogFile $LogFilePath
log_message -Message "=== Script terminé ===" -LogFile $LogFilePath

if ($failCount -eq 0) {
    exit 0
} else {
    exit 1
}
