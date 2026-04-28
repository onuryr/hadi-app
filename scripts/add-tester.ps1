# Add one or more emails to the Firebase App Distribution "testers" group.
# Usage:
#   .\scripts\add-tester.ps1 ahmet@x.com
#   .\scripts\add-tester.ps1 ahmet@x.com mehmet@y.com ayse@z.com

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Emails
)

if (-not $Emails -or $Emails.Count -eq 0) {
    Write-Host "Email gerekli. Örnek:" -ForegroundColor Yellow
    Write-Host "  .\scripts\add-tester.ps1 ahmet@x.com mehmet@y.com" -ForegroundColor Yellow
    exit 1
}

$ProjectId = "hadi-app-b33f7"
$Joined = $Emails -join ","

Write-Host "==> Adding $($Emails.Count) tester(s) to project $ProjectId" -ForegroundColor Cyan
firebase appdistribution:testers:add $Joined `
    --group-aliases testers `
    --project $ProjectId
