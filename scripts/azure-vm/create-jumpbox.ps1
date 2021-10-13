<#
    .AUTHOR
    Skip Cherniss

    .SYNOPSIS
    creates a new linux vm 

    .DESCRIPTION
    something low drag and amazingly high speed

    .NOTES
    
    *** IMPORTANT *** Modify variables at the bottom of the script

    This was sourced from the following Azure Doc
    https://docs.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-powershell

    .OUTPUTS
    This will output the IP Address for the newly created virtual machine

#>


function create-newvm {
    
    Param(
        [parameter(Mandatory=$true)]
        [string]$resourceGroup,
        [parameter(Mandatory=$true)]
        [string]$location,
        [parameter(Mandatory=$true)]
        [string]$vmname,
        [parameter(Mandatory=$true)]
        [string]$vmSize,
        [parameter(Mandatory=$true)]
        [string]$userPassword,
        [parameter(Mandatory=$true)]
        [string]$userName,
        [parameter(Mandatory=$true)]
        [string]$nicName,
        [parameter(Mandatory=$true)]
        [string]$sslPath
    )

    New-AzResourceGroup -Name $resourceGroup -Location $location

    # Create a subnet configuration
    $subnetConfig = New-AzVirtualNetworkSubnetConfig `
        -Name "mySubnet" `
        -AddressPrefix 192.168.1.0/24

    # Create a virtual network
    $vnet = New-AzVirtualNetwork `
        -ResourceGroupName $resourceGroup `
        -Location $location `
        -Name "myVNET" `
        -AddressPrefix 192.168.0.0/16 `
        -Subnet $subnetConfig

    # Create a public IP address and specify a DNS name
    $pip = New-AzPublicIpAddress `
        -ResourceGroupName $resourceGroup `
        -Location $location `
        -AllocationMethod Static `
        -IdleTimeoutInMinutes 4 `
        -Name "mypublicdns$(Get-Random)"

    # Create an inbound network security group rule for port 22
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "myNetworkSecurityGroupRuleSSH"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1000 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 22 `
    -Access "Allow"

    # Create an inbound network security group rule for port 80
    $nsgRuleWeb = New-AzNetworkSecurityRuleConfig `
    -Name "myNetworkSecurityGroupRuleWWW"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1001 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 80 `
    -Access "Allow"

    # Create a network security group
    $nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Name "myNetworkSecurityGroup" `
    -SecurityRules $nsgRuleSSH,$nsgRuleWeb

    # Create a virtual network card and associate with public IP address and NSG
    $nic = New-AzNetworkInterface `
        -Name $nicName  `
        -ResourceGroupName $resourceGroup `
        -Location $location `
        -SubnetId $vnet.Subnets[0].Id `
        -PublicIpAddressId $pip.Id `
        -NetworkSecurityGroupId $nsg.Id

    # Define a credential object
    $securePassword = ConvertTo-SecureString $userPassword  -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($userName, $securePassword)

    # Create a virtual machine configuration
    $vmConfig = New-AzVMConfig `
        -VMName $vmname `
        -VMSize $vmSize | `
    Set-AzVMOperatingSystem `
        -Linux `
        -ComputerName $vmname `
        -Credential $cred `
        -DisablePasswordAuthentication | `
    Set-AzVMSourceImage `
        -PublisherName "Canonical" `
        -Offer "UbuntuServer" `
        -Skus "18.04-LTS" `
        -Version "latest" | `
    Add-AzVMNetworkInterface `
        -Id $nic.Id

    # Configure the SSH key
    $sshPublicKey = Get-Content $sslpath
    Add-AzVMSshPublicKey `
        -VM $vmconfig `
        -KeyData $sshPublicKey `
        -Path "/home/$userName/.ssh/authorized_keys"

    New-AzVM `
    -ResourceGroupName $resourceGroup `
    -Location $location -VM $vmConfig

}



### ///////////////////////////////////////////////////////////////////////////////////////////////
### *******  INITIALIZE VARIABLES
### ///////////////////////////////////////////////////////////////////////////////////////////////

$resourceGroup = "rg-vstudio-cloudshell-demo"
$location = "CentralUS"
$vmname = "vm-vstudio-hsld-demo-jump-box"
# use the following command to list sizes for a region
# get-azvmsize -Location "CentralUS"
$vmSize = "Standard_D1_v2"
$userPassword = "password"
$userName = "azureuser"
$nicName = "nic-vstudio-hsld-demo-jump-box"
$sslPath = "~/.ssh/hslddemo.pub"


### ///////////////////////////////////////////////////////////////////////////////////////////////
### *******  CREATE VM
### ///////////////////////////////////////////////////////////////////////////////////////////////

if( $(Test-Path $sslpath) -eq $true)
{
    create-newvm `
        -resourceGroup $resourceGroup `
        -location $location `
        -vmname $vmname `
        -VMSize $vmSize `
        -userPassword $userPassword `
        -userName $userName `
        -nicName $nicName `
        -sslPath $sslPath

    $newvmipaddr = $(Get-AzPublicIpAddress -ResourceGroupName $resourceGroup | Select-Object "IpAddress")

    Write-Output "VMName: $vmName - IPADDR: $newvmipaddr"
}
else {
    Write-Output "SSL File does not exist."
}

