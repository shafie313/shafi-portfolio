# Windows Server Active Directory Lab

## Objective
Build a small, isolated AD DS lab and practise domain controller setup, organizational units (OUs), users, security groups, a test client join and basic verification.

## Suggested virtual lab
- Windows Server evaluation VM: static lab IP `192.168.50.10/24`, DNS `192.168.50.10` after DNS is installed.
- Windows 10/11 client VM: `192.168.50.20/24`, DNS `192.168.50.10`.
- Lab domain example: `adlab.test` (use only in the lab; do not use it as a public internet domain).
- Use an Internal/Host-only virtual network and take VM snapshots first.

## GUI workflow (Server Manager)
1. Set a computer name such as `DC01` and configure the static IPv4 address.
2. Add **Active Directory Domain Services** and DNS Server roles.
3. Select **Promote this server to a domain controller** → **Add a new forest** → `adlab.test`.
4. Set a strong Directory Services Restore Mode password, review prerequisites, install, and allow the server to restart.
5. Open **Active Directory Users and Computers**. Create OUs `Lab-Users` and `Lab-Groups`.
6. Create a security group `IT-Support-Lab` and a test user. Add the user to the group.
7. Configure the client DNS to `192.168.50.10`, confirm it can resolve the domain, then join `adlab.test` using authorized lab credentials.
8. Sign in using the lab domain account and verify membership and policy behavior.

## Optional PowerShell examples
Run in an elevated PowerShell session on the domain controller after AD DS is installed and the domain is available. Review each command before use.

```powershell
# Confirm domain controller and domain details
Get-ADDomain
Get-ADForest
Get-ADDomainController -Filter *

# Create OUs and a security group (safe to re-run only after checking for existing objects)
New-ADOrganizationalUnit -Name 'Lab-Users' -Path 'DC=adlab,DC=test'
New-ADOrganizationalUnit -Name 'Lab-Groups' -Path 'DC=adlab,DC=test'
New-ADGroup -Name 'IT-Support-Lab' -SamAccountName 'IT-Support-Lab' `
  -GroupScope Global -GroupCategory Security -Path 'OU=Lab-Groups,DC=adlab,DC=test'

# Create a lab user; prompts for password instead of storing it in the script
$Password = Read-Host 'Enter a strong lab-only password' -AsSecureString
New-ADUser -Name 'Lab User' -SamAccountName 'lab.user' `
  -UserPrincipalName 'lab.user@adlab.test' -Path 'OU=Lab-Users,DC=adlab,DC=test' `
  -AccountPassword $Password -Enabled $true
Add-ADGroupMember -Identity 'IT-Support-Lab' -Members 'lab.user'
Get-ADGroupMember 'IT-Support-Lab'
```

**Caution:** If an OU/group/user already exists, the creation command can fail. Confirm distinguished names match your domain before running. Do not use real production accounts or passwords in this lab. The commands are examples and have not been run in your environment.

## Evidence to capture after testing
- Server Manager showing AD DS/DNS installed
- AD Users and Computers showing OUs, user and group
- `Get-ADDomain` and `Get-ADGroupMember` output
- Client `ipconfig /all`, `nslookup adlab.test`, and successful domain join
