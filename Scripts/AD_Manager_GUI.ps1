<#
.SYNOPSIS
    Gestionnaire Active Directory avec interface graphique (GUI).
.DESCRIPTION
    Interface graphique utilisant Windows Forms pour gérer Active Directory.
    Propose un accès centralisé à tous les scripts de gestion AD.
.EXAMPLE
    .\AD_Manager_GUI.ps1
    Lance l'interface graphique du gestionnaire AD.
.NOTES
    Auteur: Julien BABIN
    Date: 03/02/2026
    Version: 1.0
    Dépendances: ActiveDirectory, .NET Framework, scripts de gestion AD
#>

param()

# Importer les modules nécessaires
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

# Variables globales
$script:scriptsPath = $PSScriptRoot
$script:logDir = "C:\logs\AD_Manager"
$script:logFile = $null

# Créer le répertoire de logs s'il n'existe pas
if (-not (Test-Path -Path $script:logDir)) {
    New-Item -ItemType Directory -Path $script:logDir -Force | Out-Null
}

# Définir le fichier log
Function define_logfile {
    $dateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "AD_Manager_GUI_$dateStr.log"
    return Join-Path -Path $script:logDir -ChildPath $logFileName
}

# Fonction de logging
Function log_message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    if ($script:logFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $script:logFile -Value $logEntry -Force
    }
}

# Fonction pour ouvrir un dialogue de sélection de fichier
Function select_csv_file {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Sélectionner un fichier CSV"
    $openFileDialog.Filter = "Fichiers CSV (*.csv)|*.csv|Tous les fichiers (*.*)|*.*"
    $openFileDialog.InitialDirectory = [System.IO.Path]::Combine($script:scriptsPath, "..", "CSV")
    if (-not (Test-Path $openFileDialog.InitialDirectory)) {
        $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
    }
    
    if ($openFileDialog.ShowDialog() -eq "OK") {
        return $openFileDialog.FileName
    }
    return $null
}

# Fonction pour afficher les résultats dans une fenêtre avec DataGridView
Function show_results {
    param (
        [string]$Results,
        [string]$Title = "Résultats"
    )
    
    $resultForm = New-Object System.Windows.Forms.Form
    $resultForm.Text = $Title
    $resultForm.Size = New-Object System.Drawing.Size(900, 600)
    $resultForm.StartPosition = "CenterScreen"
    $resultForm.FormBorderStyle = "SizableToolWindow"
    $resultForm.BackColor = [System.Drawing.Color]::White
    
    # Vérifier si c'est un résultat structuré (utilisateur, groupe, etc.)
    if ($Results -match "Name\s*:|SamAccountName\s*:|DistinguishedName\s*:") {
        show_structured_results -Results $Results -Form $resultForm -Title $Title
        return
    }
    
    # Essayer de parser comme tableau
    $lines = $Results -split "`n" | Where-Object { $_.Trim() }
    
    if ($lines.Count -gt 1) {
        # Détecter si c'est un tableau (avec séparateurs comme "----" ou colonnes alignées)
        $headerLine = $lines[0]
        $separatorLine = if ($lines.Count -gt 1) { $lines[1] } else { "" }
        
        if ($separatorLine -match "^[\s\-]+$" -or $headerLine -match "^\s*\w+(\s+\w+)+\s*$") {
            # C'est probablement un tableau, utiliser DataGridView
            $dataGridView = New-Object System.Windows.Forms.DataGridView
            $dataGridView.AutoSizeColumnsMode = "AllCells"
            $dataGridView.AutoSizeRowsMode = "AllCells"
            $dataGridView.AllowUserToAddRows = $false
            $dataGridView.AllowUserToDeleteRows = $false
            $dataGridView.ReadOnly = $true
            $dataGridView.BackgroundColor = [System.Drawing.Color]::White
            $dataGridView.Dock = "Fill"
            $dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::LightBlue
            $dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
            $dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::DarkBlue
            $dataGridView.ColumnHeadersHeightSizeMode = "AutoSize"
            $dataGridView.DefaultCellStyle.Font = New-Object System.Drawing.Font("Courier New", 10)
            
            $resultForm.Controls.Add($dataGridView)
            
            # Parser les données
            $headerLine = $lines[0]
            $headers = @()
            
            # Extraire les en-têtes
            $parts = $headerLine -split "\s{2,}" | Where-Object { $_.Trim() }
            foreach ($part in $parts) {
                $dataGridView.Columns.Add((New-Object System.Windows.Forms.DataGridViewTextBoxColumn -Property @{
                    Name = $part.Trim()
                    HeaderText = $part.Trim()
                    AutoSizeMode = "AllCells"
                })) | Out-Null
            }
            
            # Ajouter les données (sauter l'en-tête et le séparateur)
            $startRow = if ($separatorLine -match "^[\s\-]+$") { 2 } else { 1 }
            for ($i = $startRow; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line.Trim()) {
                    $values = $line -split "\s{2,}" | Where-Object { $_.Trim() }
                    if ($values.Count -gt 0) {
                        $dataGridView.Rows.Add($values) | Out-Null
                    }
                }
            }
        } else {
            # Afficher comme texte brut avec meilleure mise en forme
            show_text_results -Results $Results -Form $resultForm
            return
        }
    } else {
        # Afficher comme texte brut
        show_text_results -Results $Results -Form $resultForm
        return
    }
    
    # Bouton Fermer
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Fermer"
    $btnClose.Dock = "Bottom"
    $btnClose.Height = 35
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
    $btnClose.Add_Click({ $resultForm.Close() })
    $resultForm.Controls.Add($btnClose)
    
    $resultForm.ShowDialog() | Out-Null
}

# Fonction pour afficher les résultats structurés (utilisateur, groupe, etc.)
Function show_structured_results {
    param (
        [string]$Results,
        [System.Windows.Forms.Form]$Form,
        [string]$Title
    )
    
    # Créer un panel scrollable
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.AutoScroll = $true
    $panel.BackColor = [System.Drawing.Color]::White
    $panel.Padding = New-Object System.Windows.Forms.Padding(20)
    $Form.Controls.Add($panel)
    
    $yPos = 10
    
    # Titre succès
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "✓ Résultat trouvé"
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblStatus.ForeColor = [System.Drawing.Color]::Green
    $lblStatus.Location = New-Object System.Drawing.Point(10, $yPos)
    $lblStatus.Size = New-Object System.Drawing.Size(600, 35)
    $lblStatus.AutoSize = $false
    $panel.Controls.Add($lblStatus)
    $yPos += 50
    
    # Parser les données clé-valeur
    $lines = $Results -split "`n" | Where-Object { $_.Trim() }
    $properties = @{}
    
    foreach ($line in $lines) {
        if ($line -match "^(.+?):\s*(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $properties[$key] = $value
        }
    }
    
    # Afficher les propriétés principales en premier
    $mainProperties = @("Login", "SamAccountName", "Name", "GivenName", "Surname", "EmailAddress", "Title", "Department", "Enabled", "DistinguishedName", "MemberOf")
    
    foreach ($prop in $mainProperties) {
        foreach ($key in $properties.Keys) {
            if ($key -like "*$prop*" -or $key -eq $prop) {
                $value = $properties[$key]
                
                # Label pour la clé
                $lblKey = New-Object System.Windows.Forms.Label
                $lblKey.Text = "$key :"
                $lblKey.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
                $lblKey.ForeColor = [System.Drawing.Color]::DarkBlue
                $lblKey.Location = New-Object System.Drawing.Point(10, $yPos)
                $lblKey.Size = New-Object System.Drawing.Size(200, 25)
                $panel.Controls.Add($lblKey)
                
                # Valeur
                $lblValue = New-Object System.Windows.Forms.Label
                $lblValue.Text = if ([string]::IsNullOrWhiteSpace($value)) { "(vide)" } else { $value }
                $lblValue.Font = New-Object System.Drawing.Font("Courier New", 10)
                $lblValue.ForeColor = [System.Drawing.Color]::Black
                $lblValue.Location = New-Object System.Drawing.Point(220, $yPos)
                $lblValue.Size = New-Object System.Drawing.Size(650, 25)
                $lblValue.AutoSize = $false
                $panel.Controls.Add($lblValue)
                
                $yPos += 35
                
                # Supprimer la propriété pour éviter les doublons
                $properties.Remove($key)
                break
            }
        }
    }
    
    # Afficher les autres propriétés
    if ($properties.Count -gt 0) {
        $yPos += 10
        
        $lblOther = New-Object System.Windows.Forms.Label
        $lblOther.Text = "Autres propriétés :"
        $lblOther.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $lblOther.ForeColor = [System.Drawing.Color]::DarkBlue
        $lblOther.Location = New-Object System.Drawing.Point(10, $yPos)
        $lblOther.Size = New-Object System.Drawing.Size(200, 25)
        $panel.Controls.Add($lblOther)
        $yPos += 35
        
        foreach ($key in $properties.Keys) {
            $value = $properties[$key]
            
            $lblKey = New-Object System.Windows.Forms.Label
            $lblKey.Text = "$key :"
            $lblKey.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            $lblKey.ForeColor = [System.Drawing.Color]::DarkBlue
            $lblKey.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblKey.Size = New-Object System.Drawing.Size(200, 25)
            $panel.Controls.Add($lblKey)
            
            $lblValue = New-Object System.Windows.Forms.Label
            $lblValue.Text = if ([string]::IsNullOrWhiteSpace($value)) { "(vide)" } else { $value }
            $lblValue.Font = New-Object System.Drawing.Font("Courier New", 10)
            $lblValue.ForeColor = [System.Drawing.Color]::Black
            $lblValue.Location = New-Object System.Drawing.Point(220, $yPos)
            $lblValue.Size = New-Object System.Drawing.Size(650, 25)
            $lblValue.AutoSize = $false
            $panel.Controls.Add($lblValue)
            
            $yPos += 35
        }
    }
    
    # Bouton Fermer
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Fermer"
    $btnClose.Dock = "Bottom"
    $btnClose.Height = 35
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
    $btnClose.Add_Click({ $Form.Close() })
    $Form.Controls.Add($btnClose)
}

# Fonction pour afficher les résultats en texte brut ou structuré
Function show_text_results {
    param (
        [string]$Results,
        [System.Windows.Forms.Form]$Form
    )
    
    # Vérifier si les données contiennent des paires clé-valeur
    $lines = $Results -split "`n" | Where-Object { $_.Trim() }
    $isKeyValue = $false
    $keyValueCount = 0
    
    foreach ($line in $lines) {
        if ($line -match "^(.+?):\s*(.*)$") {
            $keyValueCount++
        }
    }
    
    # Si plus de 30% des lignes sont des clé-valeur, utiliser le format structuré
    if ($keyValueCount -gt ($lines.Count * 0.3)) {
        $isKeyValue = $true
    }
    
    if ($isKeyValue) {
        # Afficher en format structuré
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = "Fill"
        $panel.AutoScroll = $true
        $panel.BackColor = [System.Drawing.Color]::White
        $panel.Padding = New-Object System.Windows.Forms.Padding(20)
        $Form.Controls.Add($panel)
        
        $yPos = 10
        
        # Titre succès
        $lblStatus = New-Object System.Windows.Forms.Label
        $lblStatus.Text = "✓ Opération réussie"
        $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $lblStatus.ForeColor = [System.Drawing.Color]::Green
        $lblStatus.Location = New-Object System.Drawing.Point(10, $yPos)
        $lblStatus.Size = New-Object System.Drawing.Size(600, 35)
        $lblStatus.AutoSize = $false
        $panel.Controls.Add($lblStatus)
        $yPos += 50
        
        # Parser les données clé-valeur
        $properties = @{}
        
        foreach ($line in $lines) {
            if ($line -match "^(.+?):\s*(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $properties[$key] = $value
            }
        }
        
        # Afficher toutes les propriétés
        foreach ($key in $properties.Keys) {
            $value = $properties[$key]
            
            # Label pour la clé
            $lblKey = New-Object System.Windows.Forms.Label
            $lblKey.Text = "$key :"
            $lblKey.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
            $lblKey.ForeColor = [System.Drawing.Color]::DarkBlue
            $lblKey.Location = New-Object System.Drawing.Point(10, $yPos)
            $lblKey.Size = New-Object System.Drawing.Size(200, 25)
            $panel.Controls.Add($lblKey)
            
            # Valeur
            $lblValue = New-Object System.Windows.Forms.Label
            $lblValue.Text = if ([string]::IsNullOrWhiteSpace($value)) { "(vide)" } else { $value }
            $lblValue.Font = New-Object System.Drawing.Font("Courier New", 10)
            $lblValue.ForeColor = [System.Drawing.Color]::Black
            $lblValue.Location = New-Object System.Drawing.Point(220, $yPos)
            $lblValue.Size = New-Object System.Drawing.Size(650, 25)
            $lblValue.AutoSize = $false
            $panel.Controls.Add($lblValue)
            
            $yPos += 35
        }
    } else {
        # Afficher comme texte brut classique
        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Multiline = $true
        $textBox.ScrollBars = "Both"
        $textBox.WordWrap = $false
        $textBox.Text = $Results
        $textBox.ReadOnly = $true
        $textBox.Font = New-Object System.Drawing.Font("Courier New", 10)
        $textBox.BackColor = [System.Drawing.Color]::White
        $textBox.ForeColor = [System.Drawing.Color]::Black
        $textBox.Dock = "Fill"
        $Form.Controls.Add($textBox)
    }
    
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Fermer"
    $btnClose.Dock = "Bottom"
    $btnClose.Height = 35
    $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
    $btnClose.Add_Click({ $Form.Close() })
    $Form.Controls.Add($btnClose)
}

# Fonction pour afficher une confirmation
Function show_confirmation {
    param (
        [string]$Message,
        [string]$Title = "Confirmation"
    )
    $result = [System.Windows.Forms.MessageBox]::Show($Message, $Title, "YesNo", "Question")
    return ($result -eq "Yes")
}

# Fonction pour exécuter un script et capturer la sortie
Function invoke_script {
    param (
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [string]$Description = ""
    )
    
    if (-not (Test-Path $ScriptPath)) {
        show_message -Message "Erreur: Le script '$ScriptPath' n'existe pas." -Title "Erreur"
        log_message -Message "ERREUR: Script non trouvé: $ScriptPath" -Level "ERROR"
        return $false
    }
    
    try {
        log_message -Message "Exécution: $Description - $ScriptPath"
        
        $output = @()
        if ($Parameters.Count -gt 0) {
            $output = & $ScriptPath @Parameters -ErrorAction Stop 2>&1
        } else {
            $output = & $ScriptPath -ErrorAction Stop 2>&1
        }
        
        $outputText = ($output | Out-String).Trim()
        
        log_message -Message "Succès: $Description"
        
        # Afficher les résultats
        if ($outputText) {
            show_results -Results $outputText -Title $Description
        } else {
            show_message -Message "Opération réussie: $Description" -Title "Succès"
        }
        return $true
    } catch {
        $errorText = "Erreur lors de l'exécution:`n`n$_"
        log_message -Message "ERREUR lors de l'exécution: $_" -Level "ERROR"
        show_message -Message $errorText -Title "Erreur"
        return $false
    }
}

# Créer le formulaire principal
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Gestionnaire Active Directory - TechSecure"
$mainForm.Size = New-Object System.Drawing.Size(900, 650)
$mainForm.StartPosition = "CenterScreen"
$mainForm.FormBorderStyle = "FixedDialog"
$mainForm.MaximizeBox = $false
$mainForm.BackColor = [System.Drawing.Color]::WhiteSmoke

# Logo/Titre
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "GESTIONNAIRE ACTIVE DIRECTORY"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(860, 40)
$titleLabel.TextAlign = "MiddleCenter"
$mainForm.Controls.Add($titleLabel)

# Créer le TabControl
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 70)
$tabControl.Size = New-Object System.Drawing.Size(850, 500)
$mainForm.Controls.Add($tabControl)

# ===== ONGLET UTILISATEURS =====
$tabUsers = New-Object System.Windows.Forms.TabPage
$tabUsers.Text = "Users"
$tabUsers.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabUsers)

$yPos = 20
$buttonWidth = 380
$buttonHeight = 50
$spacing = 60
$leftColumn = 20
$rightColumn = 430

# Titre
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Gestion des utilisateurs Active Directory"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, $yPos)
$lblTitle.Size = New-Object System.Drawing.Size(800, 30)
$tabUsers.Controls.Add($lblTitle)
$yPos = 60

# Bouton Créer utilisateur
$btnCreateUser = New-Object System.Windows.Forms.Button
$btnCreateUser.Text = "Creer nouvel utilisateur"
$btnCreateUser.Location = New-Object System.Drawing.Point($leftColumn, $yPos)
$btnCreateUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnCreateUser.BackColor = [System.Drawing.Color]::LightGreen
$btnCreateUser.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnCreateUser.Add_Click({
    try {
        if ([System.Windows.Forms.MessageBox]::Show("Voulez-vous importer des utilisateurs depuis un fichier CSV ?", "Import CSV", "YesNo", "Question") -eq "Yes") {
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Title = "Sélectionner un fichier CSV"
            $openFileDialog.Filter = "Fichiers CSV (*.csv)|*.csv|Tous les fichiers (*.*)|*.*"
            $openFileDialog.InitialDirectory = [System.IO.Path]::Combine($script:scriptsPath, "..", "CSV")
            if (-not (Test-Path $openFileDialog.InitialDirectory)) {
                $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            }
            
            if ($openFileDialog.ShowDialog() -eq "OK") {
                $csvFile = $openFileDialog.FileName
                $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\add_AD_newEmployee.ps1"
                if (Test-Path $scriptPath) {
                    $output = & $scriptPath -FilePath $csvFile 2>&1 3>&1 4>&1 5>&1 6>&1
                    $outputText = ($output | Out-String).Trim()
                    
                    $resultForm = New-Object System.Windows.Forms.Form
                    $resultForm.Text = "Import utilisateurs depuis CSV"
                    $resultForm.Size = New-Object System.Drawing.Size(900, 600)
                    $resultForm.StartPosition = "CenterScreen"
                    $resultForm.FormBorderStyle = "SizableToolWindow"
                    $resultForm.BackColor = [System.Drawing.Color]::White
                    
                    if ([string]::IsNullOrWhiteSpace($outputText)) {
                        $outputText = "✓ Opération réussie`n`nUtilisateurs importés avec succès."
                    }
                    
                    $textBox = New-Object System.Windows.Forms.TextBox
                    $textBox.Multiline = $true
                    $textBox.ScrollBars = "Both"
                    $textBox.WordWrap = $false
                    $textBox.Text = $outputText
                    $textBox.ReadOnly = $true
                    $textBox.Font = New-Object System.Drawing.Font("Courier New", 10)
                    $textBox.Dock = "Fill"
                    $resultForm.Controls.Add($textBox)
                    
                    $btnClose = New-Object System.Windows.Forms.Button
                    $btnClose.Text = "Fermer"
                    $btnClose.Dock = "Bottom"
                    $btnClose.Height = 35
                    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
                    $btnClose.Add_Click({ $resultForm.Close() })
                    $resultForm.Controls.Add($btnClose)
                    
                    $resultForm.ShowDialog() | Out-Null
                }
            }
        } else {
            $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\add_AD_newEmployee.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -ErrorAction Stop 2>&1 | Out-Null
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur: $_", "Erreur", "OK", "Error") | Out-Null
    }
})
$tabUsers.Controls.Add($btnCreateUser)

# Bouton Rechercher
$btnSearchUser = New-Object System.Windows.Forms.Button
$btnSearchUser.Text = "Rechercher utilisateur"
$btnSearchUser.Location = New-Object System.Drawing.Point($rightColumn, $yPos)
$btnSearchUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnSearchUser.BackColor = [System.Drawing.Color]::LightBlue
$btnSearchUser.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnSearchUser.Add_Click({
    $login = [Microsoft.VisualBasic.Interaction]::InputBox("Login:", "Rechercher utilisateur", "")
    if (![string]::IsNullOrWhiteSpace($login)) {
        $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "infos\infos_AD_users.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Recherche utilisateur: $login"
    }
})
$tabUsers.Controls.Add($btnSearchUser)
$yPos += $spacing

# Bouton Modifier
$btnModifyUser = New-Object System.Windows.Forms.Button
$btnModifyUser.Text = "Modifier utilisateur"
$btnModifyUser.Location = New-Object System.Drawing.Point($leftColumn, $yPos)
$btnModifyUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnModifyUser.BackColor = [System.Drawing.Color]::LightYellow
$btnModifyUser.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnModifyUser.Add_Click({
    $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\modify_AD_user.ps1"
    invoke_script -ScriptPath $scriptPath -Description "Modification d'un utilisateur"
})
$tabUsers.Controls.Add($btnModifyUser)

# Bouton Désactiver
$btnDisableUser = New-Object System.Windows.Forms.Button
$btnDisableUser.Text = "Desactiver utilisateur"
$btnDisableUser.Location = New-Object System.Drawing.Point($rightColumn, $yPos)
$btnDisableUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnDisableUser.BackColor = [System.Drawing.Color]::Orange
$btnDisableUser.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnDisableUser.Add_Click({
    $login = [Microsoft.VisualBasic.Interaction]::InputBox("Login:", "Desactiver utilisateur", "")
    if (![string]::IsNullOrWhiteSpace($login)) {
        if (show_confirmation -Message "Confirmer la desactivation de '$login'?") {
            $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\disable_AD_user.ps1"
            invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Desactivation utilisateur: $login"
        }
    }
})
$tabUsers.Controls.Add($btnDisableUser)
$yPos += $spacing

# Bouton Réactiver
$btnEnableUser = New-Object System.Windows.Forms.Button
$btnEnableUser.Text = "Reactiver utilisateur"
$btnEnableUser.Location = New-Object System.Drawing.Point($leftColumn, $yPos)
$btnEnableUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnEnableUser.BackColor = [System.Drawing.Color]::LightGreen
$btnEnableUser.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnEnableUser.Add_Click({
    $login = [Microsoft.VisualBasic.Interaction]::InputBox("Login:", "Reactiver utilisateur", "")
    if (![string]::IsNullOrWhiteSpace($login)) {
        $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\enable_AD_user.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Reactivation utilisateur: $login"
    }
})
$tabUsers.Controls.Add($btnEnableUser)

# Bouton Supprimer
$btnDeleteUser = New-Object System.Windows.Forms.Button
$btnDeleteUser.Text = "Supprimer utilisateur"
$btnDeleteUser.Location = New-Object System.Drawing.Point($rightColumn, $yPos)
$btnDeleteUser.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnDeleteUser.BackColor = [System.Drawing.Color]::LightCoral
$btnDeleteUser.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnDeleteUser.Add_Click({
    $login = [Microsoft.VisualBasic.Interaction]::InputBox("Login:", "Supprimer utilisateur", "")
    if (![string]::IsNullOrWhiteSpace($login)) {
        if (show_confirmation -Message "ETES-VOUS SUR? Cette action est IRREVERSIBLE!") {
            if (show_confirmation -Message "Derniere confirmation pour supprimer '$login'?") {
                $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "users\delete_AD_user.ps1"
                invoke_script -ScriptPath $scriptPath -Parameters @{Login = $login} -Description "Suppression utilisateur: $login"
            }
        }
    }
})
$tabUsers.Controls.Add($btnDeleteUser)

# ===== ONGLET GROUPES =====
$tabGroups = New-Object System.Windows.Forms.TabPage
$tabGroups.Text = "Groups"
$tabGroups.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabGroups)

$yPosG = 60
$lblGroupTitle = New-Object System.Windows.Forms.Label
$lblGroupTitle.Text = "Gestion des groupes Active Directory"
$lblGroupTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblGroupTitle.Location = New-Object System.Drawing.Point(20, 20)
$lblGroupTitle.Size = New-Object System.Drawing.Size(800, 30)
$tabGroups.Controls.Add($lblGroupTitle)

# Bouton Créer groupe
$btnCreateGroup = New-Object System.Windows.Forms.Button
$btnCreateGroup.Text = "Creer groupe"
$btnCreateGroup.Location = New-Object System.Drawing.Point(20, $yPosG)
$btnCreateGroup.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnCreateGroup.BackColor = [System.Drawing.Color]::LightGreen
$btnCreateGroup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnCreateGroup.Add_Click({
    try {
        if ([System.Windows.Forms.MessageBox]::Show("Voulez-vous importer des groupes depuis un fichier CSV ?", "Import CSV", "YesNo", "Question") -eq "Yes") {
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Title = "Sélectionner un fichier CSV"
            $openFileDialog.Filter = "Fichiers CSV (*.csv)|*.csv|Tous les fichiers (*.*)|*.*"
            $openFileDialog.InitialDirectory = [System.IO.Path]::Combine($script:scriptsPath, "..", "CSV")
            if (-not (Test-Path $openFileDialog.InitialDirectory)) {
                $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            }
            
            if ($openFileDialog.ShowDialog() -eq "OK") {
                $csvFile = $openFileDialog.FileName
                $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "groups\create_AD_group.ps1"
                if (Test-Path $scriptPath) {
                    $output = & $scriptPath -FilePath $csvFile 2>&1 3>&1 4>&1 5>&1 6>&1
                    $outputText = ($output | Out-String).Trim()
                    
                    $resultForm = New-Object System.Windows.Forms.Form
                    $resultForm.Text = "Import groupes depuis CSV"
                    $resultForm.Size = New-Object System.Drawing.Size(900, 600)
                    $resultForm.StartPosition = "CenterScreen"
                    $resultForm.FormBorderStyle = "SizableToolWindow"
                    $resultForm.BackColor = [System.Drawing.Color]::White
                    
                    if ([string]::IsNullOrWhiteSpace($outputText)) {
                        $outputText = "✓ Opération réussie`n`nGroupes importés avec succès."
                    }
                    
                    $textBox = New-Object System.Windows.Forms.TextBox
                    $textBox.Multiline = $true
                    $textBox.ScrollBars = "Both"
                    $textBox.WordWrap = $false
                    $textBox.Text = $outputText
                    $textBox.ReadOnly = $true
                    $textBox.Font = New-Object System.Drawing.Font("Courier New", 10)
                    $textBox.Dock = "Fill"
                    $resultForm.Controls.Add($textBox)
                    
                    $btnClose = New-Object System.Windows.Forms.Button
                    $btnClose.Text = "Fermer"
                    $btnClose.Dock = "Bottom"
                    $btnClose.Height = 35
                    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
                    $btnClose.Add_Click({ $resultForm.Close() })
                    $resultForm.Controls.Add($btnClose)
                    
                    $resultForm.ShowDialog() | Out-Null
                }
            }
        } else {
            $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "groups\create_AD_group.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -ErrorAction Stop 2>&1 | Out-Null
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur: $_", "Erreur", "OK", "Error") | Out-Null
    }
})
$tabGroups.Controls.Add($btnCreateGroup)

# Bouton Ajouter membre
$btnAddMember = New-Object System.Windows.Forms.Button
$btnAddMember.Text = "Ajouter membre"
$btnAddMember.Location = New-Object System.Drawing.Point(430, $yPosG)
$btnAddMember.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnAddMember.BackColor = [System.Drawing.Color]::LightYellow
$btnAddMember.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnAddMember.Add_Click({
    try {
        if ([System.Windows.Forms.MessageBox]::Show("Voulez-vous importer des membres depuis un fichier CSV ?", "Import CSV", "YesNo", "Question") -eq "Yes") {
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Title = "Sélectionner un fichier CSV"
            $openFileDialog.Filter = "Fichiers CSV (*.csv)|*.csv|Tous les fichiers (*.*)|*.*"
            $openFileDialog.InitialDirectory = [System.IO.Path]::Combine($script:scriptsPath, "..", "CSV")
            if (-not (Test-Path $openFileDialog.InitialDirectory)) {
                $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            }
            
            if ($openFileDialog.ShowDialog() -eq "OK") {
                $csvFile = $openFileDialog.FileName
                $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "groups\add_AD_users_to_group.ps1"
                if (Test-Path $scriptPath) {
                    $output = & $scriptPath -FilePath $csvFile 2>&1 3>&1 4>&1 5>&1 6>&1
                    $outputText = ($output | Out-String).Trim()
                    
                    $resultForm = New-Object System.Windows.Forms.Form
                    $resultForm.Text = "Import membres depuis CSV"
                    $resultForm.Size = New-Object System.Drawing.Size(900, 600)
                    $resultForm.StartPosition = "CenterScreen"
                    $resultForm.FormBorderStyle = "SizableToolWindow"
                    $resultForm.BackColor = [System.Drawing.Color]::White
                    
                    if ([string]::IsNullOrWhiteSpace($outputText)) {
                        $outputText = "✓ Opération réussie`n`nMembres importés avec succès."
                    }
                    
                    $textBox = New-Object System.Windows.Forms.TextBox
                    $textBox.Multiline = $true
                    $textBox.ScrollBars = "Both"
                    $textBox.WordWrap = $false
                    $textBox.Text = $outputText
                    $textBox.ReadOnly = $true
                    $textBox.Font = New-Object System.Drawing.Font("Courier New", 10)
                    $textBox.Dock = "Fill"
                    $resultForm.Controls.Add($textBox)
                    
                    $btnClose = New-Object System.Windows.Forms.Button
                    $btnClose.Text = "Fermer"
                    $btnClose.Dock = "Bottom"
                    $btnClose.Height = 35
                    $btnClose.BackColor = [System.Drawing.Color]::LightCoral
                    $btnClose.Add_Click({ $resultForm.Close() })
                    $resultForm.Controls.Add($btnClose)
                    
                    $resultForm.ShowDialog() | Out-Null
                }
            }
        } else {
            $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "groups\add_AD_users_to_group.ps1"
            if (Test-Path $scriptPath) {
                & $scriptPath -ErrorAction Stop 2>&1 | Out-Null
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erreur: $_", "Erreur", "OK", "Error") | Out-Null
    }
})
$tabGroups.Controls.Add($btnAddMember)
$yPosG += $spacing

# Bouton Retirer membre
$btnRemoveMember = New-Object System.Windows.Forms.Button
$btnRemoveMember.Text = "Retirer membre"
$btnRemoveMember.Location = New-Object System.Drawing.Point(20, $yPosG)
$btnRemoveMember.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnRemoveMember.BackColor = [System.Drawing.Color]::Orange
$btnRemoveMember.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnRemoveMember.Add_Click({
    if (show_confirmation -Message "Confirmer le retrait d'un membre?") {
        $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "groups\remove_AD_member_from_group.ps1"
        invoke_script -ScriptPath $scriptPath -Description "Retrait d'un membre d'un groupe"
    }
})
$tabGroups.Controls.Add($btnRemoveMember)

# Bouton Lister membres
$btnListMembers = New-Object System.Windows.Forms.Button
$btnListMembers.Text = "Lister membres"
$btnListMembers.Location = New-Object System.Drawing.Point(430, $yPosG)
$btnListMembers.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnListMembers.BackColor = [System.Drawing.Color]::LightBlue
$btnListMembers.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnListMembers.Add_Click({
    $groupName = [Microsoft.VisualBasic.Interaction]::InputBox("Nom du groupe:", "Lister membres", "")
    if (![string]::IsNullOrWhiteSpace($groupName)) {
        $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "infos\infos_AD_groups.ps1"
        invoke_script -ScriptPath $scriptPath -Parameters @{GroupName = $groupName} -Description "Listage membres groupe: $groupName"
    }
})
$tabGroups.Controls.Add($btnListMembers)

# ===== ONGLET RAPPORTS =====
$tabReports = New-Object System.Windows.Forms.TabPage
$tabReports.Text = "Reports"
$tabReports.BackColor = [System.Drawing.Color]::White
$tabControl.TabPages.Add($tabReports)

$yPosR = 60
$btnInactive = New-Object System.Windows.Forms.Button
$btnInactive.Text = "Utilisateurs inactifs"
$btnInactive.Location = New-Object System.Drawing.Point(20, $yPosR)
$btnInactive.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnInactive.BackColor = [System.Drawing.Color]::LightYellow
$btnInactive.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnInactive.Add_Click({
    $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "infos\report_AD_inactiveUsers.ps1"
    invoke_script -ScriptPath $scriptPath -Description "Rapport utilisateurs inactifs"
})
$tabReports.Controls.Add($btnInactive)

$btnAudit = New-Object System.Windows.Forms.Button
$btnAudit.Text = "Audit complet AD"
$btnAudit.Location = New-Object System.Drawing.Point(430, $yPosR)
$btnAudit.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$btnAudit.BackColor = [System.Drawing.Color]::LightGreen
$btnAudit.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnAudit.Add_Click({
    if (show_confirmation -Message "Lancer audit complet AD?") {
        $scriptPath = Join-Path -Path $script:scriptsPath -ChildPath "infos\report_AD_complete.ps1"
        invoke_script -ScriptPath $scriptPath -Description "Audit complet Active Directory"
    }
})
$tabReports.Controls.Add($btnAudit)

# Bouton Quitter
$btnQuit = New-Object System.Windows.Forms.Button
$btnQuit.Text = "Quitter"
$btnQuit.Location = New-Object System.Drawing.Point(770, 580)
$btnQuit.Size = New-Object System.Drawing.Size(100, 30)
$btnQuit.BackColor = [System.Drawing.Color]::LightCoral
$btnQuit.Add_Click({
    log_message -Message "========== FERMETURE =========="
    $mainForm.Close()
})
$mainForm.Controls.Add($btnQuit)

# ========== MAIN ==========
Add-Type -AssemblyName Microsoft.VisualBasic

$script:logFile = define_logfile
log_message -Message "========== DEMARRAGE GUI =========="

try {
    $mainForm.ShowDialog() | Out-Null
} catch {
    [System.Windows.Forms.MessageBox]::Show("Erreur: $_", "Erreur", "OK", "Error") | Out-Null
}
