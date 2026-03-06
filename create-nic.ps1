<#

Useage:

.\create-and-attach-new-nic.ps1 `
  -ResourceGroup "example-rg" `
  -VnetName "example-vnet" `
  -SubnetName "example-subnet" `
  -NicName "example-nic2" `
  -VmName "example-dc01"

.SYNOPSIS
    Creates a new Azure NIC and optionally attaches it to a VM.

.PARAMETER ResourceGroup
    The name of the Azure resource group.

.PARAMETER VnetName
    The name of the virtual network.

.PARAMETER SubnetName
    The name of the subnet.

.PARAMETER NicName
    The name of the NIC to create.

.PARAMETER VmName
    (Optional) If provided, will attach the NIC to this VM after creation.

.EXAMPLE
    .\create-nic.ps1 -ResourceGroup "ambit-rg" -VnetName "ambit-vnet" -SubnetName "ambit-subnet" -NicName "ambit-nic2" -VmName "ambit-dc01"
#>

param (
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$VnetName,
    [Parameter(Mandatory = $true)][string]$SubnetName,
    [Parameter(Mandatory = $true)][string]$NicName,
    [string]$VmName
)

az login --only-show-errors --output none

Write-Host "🔧 Creating NIC '$NicName' in VNet '$VnetName'..." -ForegroundColor Cyan

az network nic create `
    --resource-group $ResourceGroup `
    --name $NicName `
    --vnet-name $VnetName `
    --subnet $SubnetName `
    --output none

Write-Host "✅ NIC '$NicName' created successfully." -ForegroundColor Green

if ($VmName) {
    Write-Host "📦 Deallocating VM '$VmName' to attach NIC..." -ForegroundColor Yellow
    az vm deallocate --resource-group $ResourceGroup --name $VmName --output none

    Write-Host "🔌 Attaching NIC to VM..." -ForegroundColor Cyan
    az vm nic add `
        --resource-group $ResourceGroup `
        --vm-name $VmName `
        --nics $NicName `
        --output none

    Write-Host "🚀 Starting VM again..." -ForegroundColor Yellow
    az vm start --resource-group $ResourceGroup --name $VmName --output none
    
    Write-Host "✅ NIC '$NicName' attached to VM '$VmName'." -ForegroundColor Green
}
