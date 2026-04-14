<h1 align="center">Manager PowerShell pour Windows Active Directory</h1>

<details>
  <summary><h2>Prérequis</h2></summary>

  - [Module Active Directory](#module-active-directory-)
  - [Permissions](#permissions-)
  - [Exécution de scripts PowerShell](#exécution-de-scripts-powershell-)

</details>

<details>
  <summary><h2>Scripts</h2></summary>

  ### Informations
  - [Infos du domaine](#infos-du-domaine-infos_ad_domainps1)
  - [Infos d'utilisateurs](#infos-dutilisateurs-infos_ad_usersps1)
  - [Infos de groupes](#infos-de-groupes-infos_ad_groupsps1)
  - [Informations sur les OU](#informations-sur-les-OUs-infos_ad_OUps1)
  - [Rapport des utilisateurs inactifs](#rapport-des-utilisateurs-inactifs-report_ad_inactiveusersps1)
  - [Rapport des utilisateurs désactivés](#rapport-des-utilisateurs-désactivés-report_ad_disabledusersps1)
  - [Rapport des groupes de sécurité](#rapport-des-groupes-de-sécurité-report_ad_securitygroupsps1)
  - [Rapport complet Active Directory](#rapport-complet-active-directory-report_ad_completeps1)

  ### Gestion des utilisateurs
  - [Création d'utilisateurs](#création-dutilisateurs-create_ad_userps1)
  - [Ajout d'un nouvel employé](#ajout-dun-nouvel-employé-add_ad_newemployeeps1)
  - [Modification d'utilisateurs](#modification-dutilisateurs-modify_ad_userps1)
  - [Activation et désactivation d'utilisateurs](#activation-et-désactivation-dutilisateurs-enable_ad_userps1--disable_ad_userps1)
  - [Ajout d'utilisateurs à des groupes](#ajout-dutilisateurs-à-des-groupes-add_ad_users_to_groupps1)
  - [Suppression d'utilisateurs](#suppression-dutilisateurs-delete_ad_userps1)
  - [Retrait d'un employé](#retrait-dun-employé-remove_ad_employeeps1)
  - [Réactivation d'un employé](#réactivation-dun-employé-reactivate_ad_employeeps1)
  - [Réinitialisation de mot de passe](#réinitialisation-de-mot-de-passe-reset_ad_employeepasswordps1)
  ### Gestion des groupes
  - [Création de groupes](#création-de-groupes-create_ad_groupps1)
  - [Ajout de groupes dans une OU](#ajout-de-groupes-dans-une-ou-add_ad_groups_in_oups1)
  - [Ajout de groupes dans des groupes](#ajout-de-groupes-dans-des-groupes-add_ad_group_in_groupps1)
  - [Retrait de membres d'un groupe](#retrait-de-membres-dun-groupe-remove_ad_member_from_groupps1)

  ### Gestion des unités d'organisation (OU)s
  - [Création d'OU](#création-dou-create_ad_OUps1)
  - [Modification de l'OU d'un utilisateur](#modification-de-lOU-dun-utilisateur-modify_ad_user_OUUps1)
</details>

## Prérequis

Avant d'exécuter les scripts PowerShell fournis dans cet atelier, assurez-vous de remplir les conditions suivantes :

### Module Active Directory : 

Le module Active Directory doit être installé sur votre système. 

Ce module est généralement inclus avec les outils d'administration de serveur distant (RSAT) pour Windows. 

Voici comment l'installer :

- Pour les systèmes Windows Server :
  ```powershell
    Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
  ```
  Ou installation depuis le gestionnaire de serveur en ajoutant la fonctionnalité :
  
  "Outils d'administration de serveur distant" > "Outils d'administration des rôles" > "Outils AD DS et AD LDS" > "Module Active Directory pour Windows PowerShell".

- Pour les systèmes Windows 10/11 :
  ```powershell
    Get-WindowsCapability -Name Rsat.ActiveDirectory* -Online | Add-WindowsCapability -Online
  ```

### Permissions :

Vous devez disposer des autorisations appropriées pour exécuter des commandes Active Directory.

Cela inclut généralement les droits d'administrateur de domaine ou des droits délégués spécifiques pour gérer les utilisateurs et les groupes dans Active Directory.

### Exécution de scripts PowerShell :

Assurez-vous que la politique d'exécution de PowerShell permet l'exécution de scripts.

Vous pouvez vérifier et modifier la politique d'exécution en utilisant les commandes suivantes :
  ```powershell
    Get-ExecutionPolicy
    Set-ExecutionPolicy RemoteSigned
  ```

## Scripts

### Infos du domaine (infos_AD_domain.ps1)

**Description :**
Ce script PowerShell récupère et affiche diverses informations sur l'Active Directory, telles que les contrôleurs de domaine, les utilisateurs, les groupes et les unités organisationnelles.

**Exemple d'utilisation :**
```powershell
.\infos_ad.ps1
```
Exécute le script et affiche les informations de l'Active Directory.


### Infos d'utilisateurs (infos_AD_users.ps1)

**Description :**
Ce script PowerShell récupère et affiche diverses informations sur les utilisateurs dans Active Directory, telles que les noms, les adresses e-mail, les départements et les statuts des comptes.

**Exemples d'utilisation :**
```powershell
.\infos_user.ps1 -Names "John,Doe,Jane"
```
Exécute le script et affiche les informations des utilisateurs dans Active Directory.
```powershell
.\infos_user.ps1 -Names *
```
Exécute le script et affiche les informations de tous les utilisateurs dans Active Directory.
```powershell
.\infos_user.ps1 -Login "jdoe,asmith"
```
Exécute le script et affiche les informations des utilisateurs avec les logins spécifiés dans Active Directory.
```powershell
.\infos_user.ps1 -Login "*"
```
Exécute le script et affiche les informations de tous les utilisateurs dans Active Directory.
```powershell
.\infos_user.ps1 -FirstLetter "J, B"
```
Exécute le script et affiche les informations des utilisateurs dont le nom commence par la lettre spécifiée.
```powershell
.\infos_user.ps1 -Titre "Administrateur"
```
Exécute le script et affiche les informations des utilisateurs avec le mot spécifié dans leur titre dans Active Directory.
```powershell
.\infos_user.ps1 -Count
```
Exécute le script et affiche le nombre total d'utilisateurs dans Active Directory.

**Paramètres :**
- **Names** : Une liste de noms d'utilisateurs séparés par des virgules pour lesquels récupérer les informations. Ou * pour tous les utilisateurs.
- **Login** : Une liste de logins d'utilisateurs séparés par des virgules pour lesquels récupérer les informations. Ou * pour tous les utilisateurs.
- **FirstLetter** : La première lettre des noms d'utilisateurs pour lesquels récupérer les informations.
- **Titre** : Un mot ou une phrase dans le titre des utilisateurs pour lesquels récupérer les informations.


### Infos de groupes (infos_AD_groups.ps1)

**Description :**
Ce script PowerShell permet de récupérer et d'afficher les informations des groupes spécifiques dans Active Directory en utilisant leurs noms.

**Exemples d'utilisation :**
```powershell
.\infos_AD_groups.ps1 -Group "IT_Group"
```
Exécute le script pour récupérer les informations du groupe spécifié (nombre de membres, noms des membres avec le titre et les autres groupes dont ils sont membres).
```powershell
.\infos_AD_groups.ps1 -Group "IT_Group, HR_Group"
```
Exécute le script pour récupérer les informations de plusieurs groupes dont les noms sont spécifiés, séparés par des virgules.

**Paramètre :**
- **Group** : Le nom du/des groupe(s) dont les informations doivent être récupérées. (obligatoire)

### Informations sur les OU (infos_AD_OU.ps1)

**Description :**
Ce script PowerShell récupère et affiche des informations sur les Unités d'Organisation (OU) dans Active Directory, y compris les sous-OU et les objets qu'elles contiennent.

**Exemples d'utilisation :**
```powershell
.\infos_AD_OU.ps1
```
Exécute le script pour afficher toutes les OUs dans le domaine Active Directory.

```powershell
.\infos_AD_OU.ps1 -OuName "Service_IT"
```
Exécute le script pour afficher les informations de l'OU "Service_IT". 
Possible de spécifier plusieurs OUs en les séparant par une virgule.

```powershell
.\infos_AD_OU.ps1 -OuName "Service_IT" -Properties "Name,DistinguishedName,Description"
```
Exécute le script pour afficher les propriétés spécifiées de l'OU "Service_IT".

```powershell
.\infos_AD_OU.ps1 -OuName "Service_IT" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)"
```
Exécute le script pour afficher le nombre d'objets spécifiés par -Objects dans l'OU "Service_IT" avec le scope de recherche défini par -SearchScope.
- OneLevel : Recherche uniquement dans l'OU spécifiée.
- Subtree : Recherche dans l'OU spécifiée et toutes ses sous-OUs.

```powershell
.\infos_AD_OU.ps1 -OuName "Service_IT" -Properties "Name,DistinguishedName,Description" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)"
```
Exécute le script pour afficher le nombre d'objets spécifiés par -Objects dans l'OU "Service_IT" avec le scope de recherche défini par -SearchScope et les propriétés spécifiées avec -Properties.
- OneLevel : Recherche uniquement dans l'OU spécifiée.
- Subtree : Recherche dans l'OU spécifiée et toutes ses sous-OUs.

```powershell
.\infos_AD_OU.ps1 -FilePath "C:\ous_to_check.csv" (ou -FilePath "C:\ous_to_check.csv" -Properties "Name,DistinguishedName,Description" -Count -Objects "Users (ou Groups, ou Computers, ou OU)" -SearchScope "OneLevel (ou Subtree)")
```
Exécute le script et affiche les informations de toutes les OUs listées dans un fichier CSV.
Le fichier doit avoir au moins la colonne: OuName (facultatif : Properties, Objects, SearchScope).

Les paramètres Properties, Objects et SearchScope peuvent définis dans le fichier CSV pour afficher des informations différentes pour chaque OU ou en paramètre du script pour afficher les mêmes informations pour toutes les OUs.

Si -Count est utilisé en paramètre du script, Objects et SearchScope doivent être définis dans le fichier CSV ou en paramètre du script. 

### Rapport des utilisateurs inactifs (report_AD_inactiveUsers.ps1)

**Description :**
Ce script PowerShell génère un rapport des utilisateurs qui n'ont pas changé leur mot de passe depuis un nombre de jours spécifié (90 jours par défaut). Il affiche le login, le nom complet, la dernière modification du mot de passe, et le nombre de jours depuis cette modification. Les résultats sont triés par nombre de jours décroissant et peuvent être exportés en CSV.

**Exemples d'utilisation :**
```powershell
.\report_AD_inactiveUsers.ps1
```
Affiche tous les utilisateurs n'ayant pas changé leur mot de passe depuis plus de 90 jours et exporte le résultat vers un CSV par défaut.

```powershell
.\report_AD_inactiveUsers.ps1 -Days 60
```
Affiche tous les utilisateurs n'ayant pas changé leur mot de passe depuis plus de 60 jours.

```powershell
.\report_AD_inactiveUsers.ps1 -Days 90 -ExportPath "C:\Reports\inactifs.csv"
```
Affiche les utilisateurs inactifs depuis 90 jours et exporte vers le fichier spécifié.

```powershell
.\report_AD_inactiveUsers.ps1 -Days 90 -NoExport
```
Affiche uniquement les résultats sans exporter en CSV.

**Paramètres :**
- **Days** : Nombre de jours d'inactivité basé sur le dernier changement de mot de passe. (facultatif, 90 par défaut)
- **ExportPath** : Chemin complet du fichier CSV d'export. (facultatif, par défaut: C:\Reports\inactive_users_YYYYMMDD_HHMMSS.csv)
- **NoExport** : Si spécifié, n'exporte pas les résultats en CSV, affiche uniquement à l'écran. (facultatif)


### Rapport des utilisateurs désactivés (report_AD_disabledUsers.ps1)

**Description :**
Ce script PowerShell liste tous les comptes utilisateurs désactivés. Il affiche le login, le nom, l'OU et la date de désactivation si elle est présente dans la description du compte. Les résultats peuvent être exportés en CSV.

**Exemples d'utilisation :**
```powershell
.\report_AD_disabledUsers.ps1
```
Affiche tous les comptes désactivés et exporte le rapport vers un CSV par défaut.

```powershell
.\report_AD_disabledUsers.ps1 -ExportPath "C:\Reports\disabled_users.csv"
```
Affiche les comptes désactivés et exporte vers le fichier spécifié.

```powershell
.\report_AD_disabledUsers.ps1 -NoExport
```
Affiche uniquement les résultats sans exporter en CSV.

**Paramètres :**
- **ExportPath** : Chemin complet du fichier CSV d'export. (facultatif, par défaut: C:\Reports\disabled_users_YYYYMMDD_HHMMSS.csv)
- **NoExport** : Si spécifié, n'exporte pas les résultats en CSV, affiche uniquement à l'écran. (facultatif)


### Rapport des groupes de sécurité (report_AD_securityGroups.ps1)

**Description :**
Ce script PowerShell génère un rapport détaillé de tous les groupes de sécurité dans Active Directory. Il affiche le nombre de membres pour chaque groupe, identifie les groupes vides, et génère un rapport HTML avec mise en forme CSS présentant le nom du groupe, sa description, le nombre de membres, et la liste complète des membres.

**Exemples d'utilisation :**
```powershell
.\report_AD_securityGroups.ps1
```
Affiche le résumé des groupes et exporte le rapport détaillé en HTML.

```powershell
.\report_AD_securityGroups.ps1 -ExportPath "C:\Reports\groupes.html"
```
Exporte le rapport vers le fichier HTML spécifié.

```powershell
.\report_AD_securityGroups.ps1 -NoExport
```
Affiche uniquement le résumé sans exporter en HTML.

```powershell
.\report_AD_securityGroups.ps1 -IncludeDistribution
```
Inclut également les groupes de distribution (pas seulement les groupes de sécurité).

**Paramètres :**
- **ExportPath** : Chemin complet du fichier HTML d'export. (facultatif, par défaut: C:\Reports\security_groups_YYYYMMDD_HHMMSS.html)
- **NoExport** : Si spécifié, affiche uniquement le résumé sans exporter en HTML. (facultatif)
- **IncludeDistribution** : Si spécifié, inclut également les groupes de distribution. (facultatif)
- **LogFilePath** : Le chemin du fichier journal où le rapport sera enregistré. (facultatif, par défaut: C:\logs\group_reports\)


### Création d'utilisateurs (create_AD_user.ps1)

**Description :**
Ce script PowerShell permet de créer de nouveaux utilisateurs dans Active Directory avec des propriétés spécifiées telles que le nom, le prénom, le login, l'adresse e-mail, le titre et l'unité organisationnelle.

**Exemples d'utilisation :**
```powershell
.\create_AD_user.ps1 -Prenom "John" -Nom "Doe" -Login "jdoe" -Email "john.doe@example.com" -Titre "Manager" -OU "OU=Users" -Password "TempP@ssw0rd123456!" -Enable "true"
```
Exécute le script pour créer un nouvel utilisateur avec les propriétés spécifiées.
```powershell
.\create_AD_user.ps1 -FilePath "C:\users.csv"
```
Exécute le script et crée tous les utilisateurs à partir d'un fichier CSV.

**Paramètres :**
- **Prenom** : Le prénom de l'utilisateur au format "Prénom". (obligatoire si FilePath n'est pas spécifié)
- **Nom** : Le nom de l'utilisateur au format "Nom". (obligatoire si FilePath n'est pas spécifié)
- **Login** : Le nom d'utilisateur (login) pour l'utilisateur au format "login". (obligatoire si FilePath n'est pas spécifié)
- **Email** : L'adresse e-mail de l'utilisateur au format "email". (obligatoire si FilePath n'est pas spécifié)
- **Titre** : Le titre ou poste de l'utilisateur au format "Titre". (facultatif)
- **OU** : L'unité organisationnelle où l'utilisateur sera créé au format "OU=Users" (facultatif, l'OU est générée automatiquement à partir du département si non spécifié)
- **Manager** : Le login du manager de l'utilisateur. (facultatif)
- **Departement** : Le département de l'utilisateur. (facultatif)
- **Groupe** : Les groupes auxquels l'utilisateur sera ajouté, séparés par des virgules. (facultatif)
- **Password** : Le mot de passe de l'utilisateur. (facultatif) Si non spécifié, un mot de passe par défaut sera utilisé ("TempP@ssw0rd123456!").
- **Enable** : Indique si le compte utilisateur doit être activé ou non. (facultatif, par défaut true)
- **FilePath** : Chemin vers un fichier CSV contenant les utilisateurs à créer. Le fichier doit avoir au moins les colonnes: Prenom, Nom, Login, Email, OU (Titre, Manager, Departement, Groupe, Password sont facultatifs)


### Ajout d'un nouvel employé (add_AD_newEmployee.ps1)

**Description :**
Ce script PowerShell est une interface interactive pour créer un nouvel employé dans Active Directory. Il demande les informations de l'utilisateur et appelle automatiquement le script create_AD_user.ps1 pour effectuer la création. Le script génère automatiquement le login et l'email à partir du nom et prénom, détermine l'OU à partir du département, et ajoute l'utilisateur aux groupes appropriés.

**Exemples d'utilisation :**
```powershell
.\add_AD_newEmployee.ps1 -Auto
```
Mode interactif avec prompts pour chaque paramètre.

```powershell
.\add_AD_newEmployee.ps1 -Prenom "John" -Nom "Doe" -Titre "Développeur" -Departement "Developpement" -Manager "jsmith"
```
Crée directement l'utilisateur sans prompts.

```powershell
.\add_AD_newEmployee.ps1 -FilePath "C:\nouveaux_employes.csv"
```
Crée tous les employés à partir d'un fichier CSV.

**Paramètres :**
- **Prenom** : Prénom de l'employé à créer. (obligatoire en mode non interactif)
- **Nom** : Nom de l'employé à créer. (obligatoire en mode non interactif)
- **Titre** : Titre/Poste de l'employé à créer. (obligatoire en mode non interactif)
- **Departement** : Département de l'employé à créer. (obligatoire en mode non interactif)
- **Manager** : Login du manager de l'employé à créer. (facultatif)
- **FilePath** : Chemin vers un fichier CSV contenant les employés à créer. Le fichier doit avoir les colonnes: Prenom, Nom, Titre, Departement (Manager est facultatif). (facultatif)
- **Auto** : Si spécifié, le script fonctionne en mode interactif avec des prompts pour chaque paramètre. (facultatif)


### Modification d'utilisateurs (modify_AD_user.ps1)

**Description :**
Ce script PowerShell permet de modifier diverses propriétés d'un utilisateur dans Active Directory, telles que le nom, l'adresse e-mail, le titre et le statut du compte.

**Exemple d'utilisation :**
```powershell
.\modify_AD_user.ps1 -Login "jdoe" -Email "jdoe@example.com"
```
Exécute le script pour modifier l'adresse e-mail de l'utilisateur avec le login spécifié.

**Paramètres :**
- **Login** : Le nom d'utilisateur (login) de l'utilisateur à modifier. (obligatoire)
- **Email|Title|Description|Enable|City|Country|HomeDirectory|HomePhone|OfficePhone** : La nouvelle valeur pour la propriété spécifiée (Email, Title, Description, Enable, City, Country, HomeDirectory, HomePhone, OfficePhone). (au moins une doit être spécifiée)


### Activation et désactivation d'utilisateurs (enable_AD_user.ps1 / disable_AD_user.ps1)

#### enable_AD_user.ps1

**Description :**
Ce script PowerShell permet d'activer un/des utilisateur(s) spécifique(s) dans Active Directory en utilisant le nom d'utilisateur (Login).

**Exemples d'utilisation :**
```powershell
.\enable_AD_user.ps1 -Login "jdoe"
```
Exécute le script pour activer l'utilisateur avec le login spécifié.
```powershell
.\enable_AD_user.ps1 -Login "jdoe, jsmith, mbrown"
```
Exécute le script pour activer plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules.

**Paramètre :**
- **Login** : Le nom d'utilisateur (login) de l'utilisateur à activer. (obligatoire)

#### disable_AD_user.ps1

**Description :**
Ce script PowerShell permet de désactiver un/des utilisateur(s) spécifique(s) dans Active Directory en utilisant le nom d'utilisateur (login).

**Exemples d'utilisation :**
```powershell
.\disable_AD_user.ps1 -Login "jdoe"
```
Exécute le script pour désactiver l'utilisateur avec le login spécifié.
```powershell
.\disable_AD_user.ps1 -Login "jdoe, jsmith, mbrown"
```
Exécute le script pour désactiver plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules.

**Paramètre :**
- **Login** : Le nom d'utilisateur (login) de l'utilisateur à désactiver. (obligatoire)


### Ajout d'utilisateurs à des groupes (add_AD_users_to_group.ps1)

**Description :**
Ce script PowerShell permet d'ajouter un ou plusieurs utilisateurs à un ou plusieurs groupes de sécurité spécifiques dans Active Directory en utilisant leurs noms d'utilisateur (logins). Il permet aussi d'ajouter les utilisateurs à des groupes à partir d'un fichier CSV. Il permet également d'ajouter les utilisateurs d'un groupe source à un groupe cible.

**Exemples d'utilisation :**
```powershell
.\add_AD_users_to_group.ps1 -Login "jdoe" -Group "IT_Group"
```
Exécute le script pour ajouter l'utilisateur avec le login spécifié au groupe spécifié
```powershell
.\add_AD_users_to_group.ps1 -Login "jdoe, jsmith" -Group "IT_Group, HR_Group"
```
Exécute le script pour ajouter plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules, aux groupes spécifiés, séparés par des virgules.
```powershell
.\add_AD_users_to_group.ps1 -FilePath "C:\users_to_add.csv" -Group "IT_Group"
```
Exécute le script et ajoute les utilisateurs à partir d'un fichier CSV. Le fichier doit contenir au moins la colonne: Login (Group est facultatif si le paramètre Group est spécifié).
```powershell
.\add_AD_users_to_group.ps1 -SourceGroup "Source_Group" -TargetGroup "New_Group"
```
Exécute le script pour ajouter tous les utilisateurs du groupe source au groupe cible.
```powershell
.\add_AD_users_to_group.ps1 -SourceGroup "Source_Group, Source_Group2" -TargetGroup "New_Group"
```
Exécute le script pour ajouter tous les utilisateurs de plusieurs groupes source au groupe cible.
```powershell
.\add_AD_users_to_group.ps1 -SourceGroup "Source_Group" -TargetGroup "New_Group1, New_Group2"
```
Exécute le script pour ajouter tous les utilisateurs du groupe source à plusieurs groupes cibles

**Paramètres :**
- **Login** : Le nom d'utilisateur (login) de l'/des utilisateur(s) à ajouter aux groupes. (obligatoire si FilePath n'est pas spécifié)
- **Group** : Le(s) groupe(s) de sécurité auquel/auxquels ajouter l'/les utilisateur(s). (obligatoire si FilePath n'est pas spécifié, facultatif si les groupes sont spécifiés dans le fichier CSV)
- **FilePath** : Chemin vers un fichier CSV contenant les utilisateurs à ajouter aux groupes. Le fichier doit avoir au moins la colonne: Login (Group est facultatif si le paramètre Group est spécifié).
- **SourceGroup** : Le groupe source dont les utilisateurs seront ajoutés au groupe cible. (obligatoire si TargetGroup est spécifié)
- **TargetGroup** : Le groupe cible auquel les utilisateurs du groupe source seront ajoutés. (obligatoire si SourceGroup est spécifié)


### Suppression d'utilisateurs (delete_AD_user.ps1)

**Description :**
Ce script PowerShell permet de supprimer un utilisateur spécifique dans Active Directory en utilisant son nom d'utilisateur (login).

**Exemples d'utilisation :**
```powershell
.\delete_AD_user.ps1 -Login "jdoe"
```
Exécute le script pour supprimer l'utilisateur avec le login spécifié.
```powershell
.\delete_AD_user.ps1 -Login "jdoe, jsmith, mbrown"
```
Exécute le script pour supprimer plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules.

**Paramètre :**
- **Login** : Le nom d'utilisateur (login) de l'utilisateur à supprimer. (obligatoire)


### Retrait d'un employé (remove_AD_employee.ps1)

**Description :**
Ce script PowerShell retire un employé d'Active Directory en désactivant son compte, en le déplaçant vers une OU pour les comptes inactifs, en réinitialisant son mot de passe et en ajoutant une note avec la date de désactivation. Toutes les actions sont journalisées et une confirmation est demandée avant de procéder.

**Exemple d'utilisation :**
```powershell
.\remove_AD_employee.ps1 -Login "jdoe"
```
Retire l'employé avec le login "jdoe" et enregistre les actions dans un fichier journal.

```powershell
.\remove_AD_employee.ps1 -Login "jdoe" -LogFilePath "C:\Logs\AD_Removals.log"
```
Retire l'employé et enregistre les actions dans le fichier journal spécifié.

**Paramètres :**
- **Login** : Le login de l'employé à retirer d'Active Directory. (obligatoire)
- **LogFilePath** : Le chemin du fichier journal où les actions seront enregistrées. (facultatif, par défaut: C:\logs\user_removal\prenom.nom_yyyyMMdd_HHmmss.log)


### Réactivation d'un employé (reactivate_AD_employee.ps1)

**Description :**
Ce script PowerShell réactive un employé dans Active Directory en activant son compte, en le déplaçant vers une nouvelle unité organisationnelle (OU), en l'ajoutant à des groupes spécifiés et en réinitialisant son mot de passe. Il ajoute également une note avec la date de réactivation et logge toutes les actions.

**Exemples d'utilisation :**
```powershell
.\reactivate_AD_employee.ps1 -Login "jdoe"
```
Réactive l'employé avec le login "jdoe" en mode interactif.

```powershell
.\reactivate_AD_employee.ps1 -Login "jdoe" -OU "Developpement" -Groupes "GRP_Developpement,GRP_Tous_Utilisateurs"
```
Réactive l'employé directement avec les paramètres spécifiés.

**Paramètres :**
- **Login** : Le login de l'employé à réactiver dans Active Directory. (obligatoire)
- **OU** : Le nom de l'unité organisationnelle où déplacer l'utilisateur. (facultatif, demandé en mode interactif)
- **Groupes** : Les groupes à ajouter à l'utilisateur, séparés par des virgules. (facultatif, demandé en mode interactif)
- **LogFilePath** : Le chemin du fichier journal où les actions seront enregistrées. (facultatif, par défaut: C:\logs\user_reactivation\)


### Réinitialisation de mot de passe (reset_AD_employeePassword.ps1)

**Description :**
Ce script PowerShell réinitialise le mot de passe d'un utilisateur Active Directory en générant un nouveau mot de passe aléatoire sécurisé. Il force l'utilisateur à changer son mot de passe à la prochaine connexion et déverrouille le compte si nécessaire. Le nouveau mot de passe est affiché pour transmission sécurisée.

**Exemples d'utilisation :**
```powershell
.\reset_AD_employeePassword.ps1 -Login "jdoe"
```
Réinitialise le mot de passe de l'utilisateur "jdoe" et affiche le nouveau mot de passe.

```powershell
.\reset_AD_employeePassword.ps1 -Login "jdoe" -LogFilePath "C:\Logs\password_reset.log"
```
Réinitialise le mot de passe et enregistre l'action dans le fichier journal spécifié.

**Paramètres :**
- **Login** : Le login (SamAccountName) de l'employé dont réinitialiser le mot de passe. (obligatoire)
- **LogFilePath** : Le chemin du fichier journal où les actions seront enregistrées. (facultatif, par défaut: C:\logs\password_reset\)


### Création de groupes (create_AD_group.ps1)

**Description :**
Ce script PowerShell permet de créer de nouveaux groupes de sécurité dans Active Directory avec des propriétés spécifiées telles que le nom du groupe, la description, le type de groupe, la portée et les groupes desquels il est membre (domaine par défaut si non spécifié).

**Exemples d'utilisation :**
```powershell
.\create_AD_group.ps1 -GroupName "IT_Support" -Description "Groupe de support informatique" -GroupScope "Global" -GroupCategory "Security" -MemberOf "OU=Service_IT,DC=example,DC=com"
```
Exécute le script pour créer un nouveau groupe de sécurité avec les propriétés spécifiées.
```powershell
.\create_AD_group.ps1 -FilePath "C:\groups.csv"
```
Exécute le script et crée tous les groupes à partir d'un fichier CSV.

**Paramètres :**
- **GroupName** : Le nom du groupe de sécurité à créer. (obligatoire si FilePath n'est pas spécifié)
- **Description** : La description du groupe de sécurité. (facultatif)
- **GroupScope** : La portée du groupe de sécurité (DomainLocal, Global, Universal). (obligatoire si FilePath n'est pas spécifié)
- **GroupCategory** : Le type de groupe (Security ou Distribution). (obligatoire si FilePath n'est pas spécifié)
- **MemberOf** : Les groupes dont ce groupe sera membre. (facultatif, par défaut le groupe sera membre du domaine)
- **FilePath** : Chemin vers un fichier CSV contenant les groupes à créer. Le fichier doit avoir au moins les colonnes: GroupName, GroupScope, GroupCategory (Description et MemberOf sont facultatifs).


### Ajout de groupes dans une OU (add_AD_groups_in_OU.ps1)

**Description :**
Ce script PowerShell permet d'ajouter des groupes dans une Unité d'Organisation (OU) spécifique dans Active Directory.

**Exemples d'utilisation :**
```powershell
.\add_AD_groups_in_OU.ps1 -GroupNames "IT_Support","IT_Admins" -OuName "Service_IT"
```
Ajoute les groupes "IT_Support" et "IT_Admins" dans l'OU "Service_IT".

```powershell
.\add_AD_groups_in_OU.ps1 -FilePath "C:\groups_to_add.csv"
```
Ajoute tous les groupes à partir d'un fichier CSV. Le fichier doit avoir les colonnes: GroupName, OuName.

```powershell
.\add_AD_groups_in_OU.ps1 -FilePath "C:\groups_to_add.csv" -OuName "Service_IT"
```
Ajoute tous les groupes listés dans le fichier CSV dans l'OU spécifiée.

**Paramètres :**
- **GroupNames** : Le(s) nom(s) des groupes à ajouter. Pour plusieurs groupes, séparer les noms par des virgules. (obligatoire si FilePath n'est pas spécifié)
- **OuName** : Le nom de l'Unité d'Organisation (OU) dans laquelle ajouter les groupes. (obligatoire si FilePath n'est pas spécifié ou si le fichier ne contient pas la colonne OuName)
- **FilePath** : Chemin vers un fichier CSV contenant les groupes à ajouter. Le fichier doit avoir les colonnes: GroupName, OuName (si OuName n'est pas spécifié en paramètre). Le fichier peut aussi contenir uniquement la colonne GroupName si OuName est spécifié en paramètre. (facultatif)


### Ajout de groupes dans des groupes (add_AD_group_in_group.ps1)

**Description :**
Ce script PowerShell permet d'ajouter un ou plusieurs groupes Active Directory en tant que membres d'un ou plusieurs autres groupes AD. Il prend en charge l'ajout de plusieurs groupes en une seule exécution.

**Exemples d'utilisation :**
```powershell
.\add_AD_group_in_group.ps1 -MemberGroups "GroupeMembre1, GroupeMembre2" -TargetGroups "GroupeCible1, GroupeCible2"
```
Ajoute "GroupeMembre1" et "GroupeMembre2" en tant que membres de "GroupeCible1" et "GroupeCible2".

```powershell
.\add_AD_group_in_group.ps1 -FilePath "C:\groupes.csv"
```
Ajoute les groupes listés dans le fichier "groupes.csv" en tant que membres des groupes cibles spécifiés dans le fichier.
Colonnes obligatoires: MemberGroup, TargetGroup

```powershell
.\add_AD_group_in_group.ps1 -FilePath "C:\groupes.csv" -TargetGroups "GroupeCible1, GroupeCible2"
```
Ajoute les groupes listés dans le fichier en tant que membres de "GroupeCible1" et "GroupeCible2".
Colonne obligatoire: MemberGroup uniquement.

**Paramètres :**
- **MemberGroups** : Le ou les groupes AD à ajouter en tant que membres. (obligatoire si FilePath n'est pas spécifié)
- **TargetGroups** : Le ou les groupes AD cibles auxquels les groupes membres seront ajoutés. (obligatoire si FilePath n'est pas spécifié)
- **FilePath** : Chemin vers un fichier CSV contenant les noms des groupes AD à ajouter en tant que membres. Colonnes obligatoires: MemberGroup, TargetGroup. Si les groupes cibles sont spécifiés via le paramètre TargetGroups, seule la colonne MemberGroup est requise. (facultatif)


### Retrait de membres d'un groupe (remove_AD_member_from_group.ps1)

**Description :**
Ce script PowerShell permet de retirer un ou plusieurs membres (utilisateurs ou groupes) d'un groupe de sécurité dans Active Directory. Il peut retirer des utilisateurs individuels, des groupes, ou traiter un fichier CSV contenant plusieurs retraits. Le script supporte un mode interactif pour faciliter l'utilisation.

**Exemples d'utilisation :**
```powershell
.\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -Login "jdoe"
```
Retire l'utilisateur "jdoe" du groupe "IT_Group".

```powershell
.\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -Login "jdoe,jsmith"
```
Retire plusieurs utilisateurs du groupe "IT_Group".

```powershell
.\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -MemberGroup "HR_Group"
```
Retire le groupe "HR_Group" du groupe "IT_Group".

```powershell
.\remove_AD_member_from_group.ps1 -SourceGroup "IT_Group" -MemberGroup "HR_Group,Support_Group"
```
Retire plusieurs groupes du groupe "IT_Group".

```powershell
.\remove_AD_member_from_group.ps1 -FilePath "C:\members_to_remove.csv"
```
Retire les membres listés dans le fichier CSV.
Le fichier doit contenir les colonnes: SourceGroup, Login (facultatif), MemberGroup (facultatif).

```powershell
.\remove_AD_member_from_group.ps1 -Auto
```
Mode interactif avec prompts pour chaque paramètre.

**Paramètres :**
- **SourceGroup** : Le nom du groupe duquel retirer les membres. (obligatoire si FilePath n'est pas spécifié)
- **Login** : Le(s) login(s) des utilisateurs à retirer du groupe, séparés par des virgules. (facultatif)
- **MemberGroup** : Le(s) nom(s) des groupes à retirer du groupe source, séparés par des virgules. (facultatif)
- **FilePath** : Chemin vers un fichier CSV contenant les membres à retirer. Le fichier doit avoir les colonnes: SourceGroup, Login (facultatif), MemberGroup (facultatif). Au moins une des colonnes Login ou MemberGroup doit être renseignée pour chaque ligne. (facultatif)
- **Auto** : Mode interactif avec prompts pour chaque paramètre. (facultatif)
- **LogFilePath** : Le chemin du fichier journal où les actions seront enregistrées. (facultatif, par défaut: C:\logs\member_removal\)


### Création d'OU (create_AD_OU.ps1)

**Description :**
Ce script PowerShell permet de créer une nouvelle Unité d'Organisation (OU) dans Active Directory si elle n'existe pas déjà.

**Exemples d'utilisation :**
```powershell
.\create_AD_OU.ps1 -OuName "Service_IT"
```
Exécute le script pour créer une nouvelle OU avec le nom spécifié.

```powershell
.\create_AD_OU.ps1 -OuName "Service_IT" -MemberOf "OU=Departments"
```
Exécute le script pour créer une nouvelle OU avec le nom spécifié sous l'OU parente spécifiée.

```powershell
.\create_AD_OU.ps1 -FilePath "C:\create_ou.csv"
```
Exécute le script et crée toutes les OUs à partir d'un fichier CSV. Le fichier doit avoir les colonnes: OuName et MemberOf.

```powershell
.\create_AD_OU.ps1 -FilePath "C:\create_ou.csv" -MemberOf "OU=Departments"
```
Exécute le script et crée toutes les OUs listées dans le fichier CSV sous l'OU "Departments".
Le fichier doit contenir uniquement la colonne: OuName.

**Paramètres :**
- **FilePath** : Chemin vers un fichier CSV contenant les OUs à créer. Le fichier doit avoir au moins la colonne: OuName (MemberOf est facultatif).
- **OuName** : Le nom de l'OU à créer. (obligatoire si FilePath n'est pas spécifié)
- **MemberOf** : L'OU parente sous laquelle l'OU sera créée. (facultatif, par défaut l'OU sera créée à la racine du domaine si non spécifié)

### Modification de l'OU d'un utilisateur (modify_AD_user_OU.ps1)

**Description :**
Ce script PowerShell permet de déplacer un utilisateur existant vers une nouvelle Unité d'Organisation (OU) dans Active Directory.

**Exemples d'utilisation :**
```powershell
.\modify_AD_user_OU.ps1 -Login "jdoe" -NewOU "Informatique"
```
Exécute le script pour déplacer l'utilisateur avec le login spécifié vers la nouvelle OU spécifiée.

```powershell
.\modify_AD_user_OU.ps1 -Login "jdoe, jsmith" -NewOU "Informatique"
```
Exécute le script pour déplacer plusieurs utilisateurs dont les logins sont spécifiés, séparés par des virgules, vers la nouvelle OU spécifiée.

```powershell
.\modify_AD_user_OU.ps1 -FilePath "C:\users_to_move.csv"
```
Exécute le script et déplace les utilisateurs à partir d'un fichier CSV. Le fichier doit avoir les colonnes: Login et NewOU.

```powershell
.\modify_AD_user_OU.ps1 -FilePath "C:\users_to_move.csv" -NewOU "Informatique"
```
Exécute le script et déplace tous les utilisateurs listés dans le fichier CSV vers la
nouvelle OU spécifiée. Le fichier doit contenir uniquement la colonne: Login.

**Paramètres :**
- **Login** : Le nom d'utilisateur (login) de l'utilisateur à déplacer. (obligatoire si FilePath n'est pas spécifié)
- **NewOU** : Le nom de la nouvelle Unité d'Organisation (OU) vers laquelle déplacer l'utilisateur. (obligatoire si FilePath n'est pas spécifié, falcultatif avec FilePath si les nouvelles OUs sont spécifiées dans le fichier CSV)
- **FilePath** : Chemin vers un fichier CSV contenant les utilisateurs à déplacer. Le fichier doit avoir la colonne: Login (NewOU est facultatif si le paramètre NewOU est spécifié).


### Rapport complet Active Directory (report_AD_complete.ps1)

**Description :**
Ce script PowerShell génère un rapport HTML détaillé et complet incluant :
- Nombre total d'utilisateurs (actifs/désactivés)
- Nombre total de groupes et d'OUs
- Top 10 des groupes avec le plus de membres
- Liste des utilisateurs dont le mot de passe n'expire jamais
- Liste des utilisateurs avec des mots de passe expirés
- Statistiques détaillées par département

Le rapport est généré au format HTML avec mise en forme CSS professionnelle et peut être ouvert dans n'importe quel navigateur.

**Exemples d'utilisation :**
```powershell
.\report_AD_complete.ps1
```
Génère le rapport HTML complet et l'exporte vers le chemin par défaut (C:\Reports\report_AD_complete_YYYYMMDD_HHMMSS.html).

```powershell
.\report_AD_complete.ps1 -ExportPath "C:\Reports\rapport_complet.html"
```
Génère le rapport et l'exporte vers le fichier spécifié.

```powershell
.\report_AD_complete.ps1 -NoExport
```
Affiche uniquement le résumé dans la console sans exporter en HTML.

**Paramètres :**
- **ExportPath** : Chemin complet du fichier HTML d'export. (facultatif, par défaut: C:\Reports\report_AD_complete_YYYYMMDD_HHMMSS.html)
- **NoExport** : Si spécifié, n'exporte pas les résultats en HTML, affiche uniquement les résultats. (facultatif)

**Contenu du rapport :**
- **Statistiques Globales** : Compteurs des utilisateurs actifs/désactivés, groupes, OUs et départements
- **Top 10 Groupes** : Les 10 groupes avec le plus de membres
- **Mots de passe n'expirant jamais** : Liste des utilisateurs avec mots de passe non expirables (risque sécurité)
- **Mots de passe expirés** : Liste des utilisateurs devant changer leur mot de passe
- **Statistiques par département** : Répartition des utilisateurs actifs/désactivés par département

