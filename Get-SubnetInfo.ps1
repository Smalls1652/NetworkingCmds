[CmdletBinding()]
param(
    [string]$NetworkAddress = "192.168.0.0",
    [ValidateSet(31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8)]
    [int]$CidrNotation = 24
)

begin {

    #Checking to make sure the network address supplied is valid.
    if ($NetworkAddress.Split(".").Count -ne 4) {
        #Throw an error if there aren't four octets.
        Write-Error -Message "The network address supplied does not have enough octets." -Category InvalidData -ErrorId "InvalidNetAddr" -TargetObject $NetworkAddress -RecommendedAction "Check network address." -CategoryActivity "CheckProvData" -CategoryReason "InvalidNetAddr" -CategoryTargetName "NetworkAddress" -ErrorAction Stop
    }
    else {
        #If there are four octects, try to convert to bytes.
        try {
            [byte[]]$NetworkAddressBytes = $NetworkAddress.Split(".")
        }
        catch {
            #Throw an error if the conversion fails.
            $ErrorDetails = $_
            throw $ErrorDetails
        }
    }

    $TotalBits = 32

}

process {
    #Calculate the total number of addresses and usable hosts with the provided CIDR notation.
    $TotalAddresses = [math]::Pow(2, ($TotalBits - $CidrNotation))
    $TotalHosts = $TotalAddresses - 2

    #Determine the amount of bits used if...
    if ($TotalAddresses -le [math]::Pow(256, 1)) {
        #TotalAddress <= 256^1, then the fourth octet is calculated.
        $WildcardBits = [byte[]](0, 0, 0, (255 - (256 - $TotalAddresses)))
    }
    elseif (($TotalAddresses -gt [math]::Pow(256, 1)) -and ($TotalAddresses -lt [math]::Pow(256, 2))) {
        #256^1 < TotalAddresses > 256^2, then the third octet is calculated.
        $WildcardBits = [byte[]](0, 0, (($TotalAddresses / 256) - 1), 255)
    }
    elseif ($TotalAddresses -gt [math]::Pow(256, 2) -and ($TotalAddresses -lt [math]::Pow(256, 3))) {
        #256^2 < TotalAddresses > 256^3, then the second octet is calculated.
        $WildcardBits = [byte[]](0, (($TotalAddresses / [math]::Pow(256, 2)) - 1), 255, 255)
    }
    elseif ($TotalAddresses -gt [math]::Pow(256, 3)) {
        #TotalAddresses > 256^3, then the first octet is calculated.
        $WildcardBits = [byte[]]((($TotalAddresses / [math]::Pow(256, 3)) - 1), 255, 255, 255)
    }

    #Calculate the subnetmask from bits used.
    [byte[]]$SubnetMask = foreach ($Wildcard in $WildcardBits) {
        255 - $Wildcard
    }

    #Calculate the broadcast address by adding the bits used to each octet.
    [byte[]]$BroadcastAddress = for (($i = 0); $i -lt 4; $i++) {
        $NetworkAddressBytes[$i] + $WildcardBits[$i]
    }

    #Add 1 to the network address and subtract one from the broadcast address for the usable host range.
    [byte[]]$FirstUsableHost = ($NetworkAddressBytes[0], $NetworkAddressBytes[1], $NetworkAddressBytes[2], ($NetworkAddressBytes[3] + 1))
    [byte[]]$LastUsableHost = ($BroadcastAddress[0], $BroadcastAddress[1], $BroadcastAddress[2], ($BroadcastAddress[3] - 1))

    return [pscustomobject]@{
        "NetworkAddress"   = ($NetworkAddress -join ".");
        "BroadcastAddress" = ($BroadcastAddress -join ".");
        "SubnetMask"       = ($SubnetMask -join ".");
        "CidrNotation"     = $CidrNotation;
        "HostRange"        = "$($FirstUsableHost -join ".") - $($LastUsableHost -join ".")";
        "TotalHosts"       = $TotalHosts;
        "TotalAddresses"   = $TotalAddresses
    }
}