# Function to calculate delay with jitter
function CalcDelay {
    param (
        [double]$seconds,
        [double]$jitter
    )

    [double]$jitter_factor = Get-Random -Minimum 0 -Maximum (100 / 100.0)
    [double]$jitter_value = $seconds * ($jitter / 100) * $jitter_factor
 
    # Randomly decide whether to add or subtract the jitter
    if ((Get-Random -Minimum 0 -Maximum 2) -eq 0) {
        [double]$jittered_seconds = $seconds - $jitter_value
    }
    else {
        [double]$jittered_seconds = $seconds + $jitter_value
    }
 
    return $jittered_seconds
}

function IsDnsResolvable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Hostname
    )

    try {
        [System.Net.Dns]::GetHostAddresses($Hostname)
        return $true
    }
    catch {
        return $false
    }
}


function CreateDirectory {
    param (
        [string] $OutputPath
    )
    
    if (-not (Test-Path $OutputPath)) {
        mkdir $OutputPath | Out-Null
    }
}


function PortScan {
    param(
        [string] $server,
        [int] $port
    )   

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $port = $tcpClient.ConnectAsync($server, $port).Wait(2000)
        return $port
    }

    catch {
        return $false
    }

    finally {
        $tcpClient.Close()
    }
}

function CheckLocalAdminSMB {
    param (
        [string] $server
    )
   
    $adminCheck = Test-Path -Path "\\$server\c$\Users" -ErrorAction SilentlyContinue
    #$adminCheck = Get-SmbSession -ComputerName $server
    if ($adminCheck -eq $false) {
        "[-] Access is denied on $server" | Write-Host -ForegroundColor Red
    }
    else {
        return $true
    }
}

function checkLocalAdminWMI {
    param (
        [string]$server
    )

    try {
        $LastBootUpTime = Get-WmiObject Win32_OperatingSystem -ComputerName $server -ErrorAction Stop | Select-Object -Exp LastBootUpTime
        $convertedLastBootUpTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($LastBootUpTime) 
        return $convertedLastBootUpTime
    }
    catch {
        return $false
    }
}

# Compares the machine bootuptime with the last write/access time of users in users folder
# Returns an indication the user has a session in LSASS memory
function FindUserInMemory {
    param (
        [string] $server,
        [string] $outputPath,
        [string] $sessionOutput,
        [string] $convBootupTime
    )
    $users = Get-WmiObject -ComputerName $server -Query "SELECT * FROM Win32_Directory WHERE Drive = 'C:' AND Path = '\\users\\'"  -ErrorAction SilentlyContinue
         
    foreach ($user in $users) {

        $userName = $user.Name.split('\')[-1]
        $lastAccess = [System.Management.ManagementDateTimeConverter]::ToDateTime($user.LastAccessed)
        $lastWriteUser = [System.Management.ManagementDateTimeConverter]::ToDateTime($user.LastModified)
            
        if (($lastWriteUser -gt $convBootupTime) -or ($lastAccess -gt $convBootupTime)) {
            '[+]LastWriteTime or LastAccessTime is greater than LastBootUpTime.' | Add-Content -Path $sessionOutput
                
            "$userName Last AccessTime was at: $lastAccess " | Add-Content -Path $sessionOutput
            Write-Host "$userName LastAccessTime was at: $lastAccess " 
               
            "$userName LastWriteTime was at: $lastWriteUser" | Add-Content -Path $sessionOutput
            Write-Host "$userName LastWriteTime was at: $lastWriteUser `n"  

            Write-Host ' '
        }
                
    }
}

function FindUserSessionsSMB {
    param (
        [string] $server,
        [string] $outputPath,
        [string] $sessionOutput
    )
    

    try {  
        $loggedOnUsers = quser /server:$server | Select-Object -Skip 1 | ForEach-Object { $_ -replace '\s{2,}', ',' } 
    }
    catch {
        if ($_.Exception.Message -match 'No User exists for') {
            Write-Output "No user exists on $serverName"
        }
        else {
            # Handle other exceptions
            Write-Error $_.Exception.Message
        }    
    }

    #Checking user sessions
    '[+] Enumerating sessions:' | Add-Content $sessionOutput
    Write-Host '[+] Enumerating sessions:'

    foreach ($user in $loggedOnUsers) {
        $split = $user.Split(',')
        "$($split[0]) has a session on $server at: $($split[4])" | Add-Content -Path $sessionOutput
        $split[0] + " has a seesion on $server at: " + $split[4] | Write-Host -ForegroundColor Green 

        #Writing all sessions into the file
        "$($split[0]) has a session on $server at: $($split[4])" | Add-Content -Path "$pwd\\$OutputPathName\\Sessions.txt" 

    }
     
    Write-Host ''
    '[+] Session Enumeration Completed' | Write-Host -ForegroundColor Blue 
    '[+] Session Enumeration Completed' | Add-Content $sessionOutput
    Write-Host ''
    "`n" | Add-Content $sessionOutput
}

function ExtractPowershellConsoleHost {
    param ( 
        [string] $server,
        [string] $OutputPath,
        [string] $sessionOutput
    )    

    #Checking if the path is exist
    $users = Get-ChildItem -Path "\\$server\c$\Users" -Directory -ErrorAction SilentlyContinue

    foreach ($user in $users) {

        $userName = $user.Name
        $consoleHistory = "\\$server\c$\Users\$userName\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
        $testConsoleHistory = Test-Path -Path $consoleHistory -ErrorAction Stop

        if ($testConsoleHistory) { 
            "[+]Extracting ConsoleHost_history for the user $userName" | Add-Content -Path $sessionOutput
            Write-Host "[+]Extracting ConsoleHost_history for the user $userName" -ForegroundColor Green
            Get-Content -Path $consoleHistory | Out-File "$OutputPath\\$userName.txt" -Append  
        }


    }

    Write-Host ""
    "`n" | Add-Content -Path $sessionOutput
}
function Invoke-Kosem {
    param (
        [string]$filePath,
        [double]$baseSeconds = 5, # Default base delay in seconds
        [double]$jitter = 30
    )

    #Checking if the file exists
    if (-not (Test-Path $filePath)) {
        "[-] File $filePath does not exist" | Write-Host -ForegroundColor Red
        return
    }

    if (-not [double]$baseSeconds) {
        '[-] Base delay must be a number' | Write-Host -ForegroundColor Red
        return
    }

    if (-not [double]$jitter) {
        '[-] Jitter must be a number' | Write-Host -ForegroundColor Red
        return
    }
  
    $servers = Get-Content $filePath
    $date = Get-Date
    $OutputPathName = "kosem_$($date.Second)$($date.Hour)$($date.Minute)_$($date.Day)$($date.Month)$($date.Year)"  

    mkdir $OutputPathName | Out-Null
    #Checking if the server is resolved
    foreach ($computer in $servers) {

        Write-Host '---------------------------- [+] Moving to the next computer ------------------------------------------------'
        
        #Starting delay base on the user input
        $delay = CalcDelay -seconds $baseSeconds  -jitter $jitter
        Start-Sleep -Seconds $delay

        $OutputPath = "$pwd\\$OutputPathName\\$computer"
        $sessionOutput = "$outputPath\\_Sessions.txt"

        $written_local_admin = $null
        if (-not (IsDnsResolvable -Hostname $computer)) {
            "[-] Host $computer is not resolvable" | Write-Host -ForegroundColor Red
            continue
        }
        
        #Checking port 445
        $smbResult = PortScan -server $computer -port 445
        if ($smbResult) {    
            $written_local_admin = CheckLocalAdminSMB -server $computer 
            #If not local admin exit
            if ($written_local_admin) {
                "[+] Current user has Admin access on $computer `n" | Write-Host -ForegroundColor Green
                #Creating directory  
                CreateDirectory -OutputPath $outputPath 
                FindUserSessionsSMB -server $computer -sessionOutput $sessionOutput -OutputPath $OutputPath
                ExtractPowershellConsoleHost -server $computer -OutputPath $OutputPath -sessionOutput $sessionOutput
                $computer | Add-Content "$pwd\\$outputPathName\\_Computers.txt" 
            }
            else {
                continue
            }

        }  

        #Checking port 135
        $wmiResult = PortScan -server $computer -port 135

        if ($wmiResult) {
            
            
            $LastBootUpTime = checkLocalAdminWMI -server $computer
            # if $written_local_admin is null = smb is closed - we have not checked we are local admin
            # if $lastBootUpTime is false - we are not local admin
            if ($written_local_admin -eq $null -and $LastBootUpTime -ne $false) {
                # we checked via WMI we are local admin
                "[+] Current user has Admin access on $computer `n" | Write-Host -ForegroundColor Green
                Write-Output "[+] Enumerating $computer using RPC"
                CreateDirectory -OutputPath $outputPath    
                $computer | Add-Content "$pwd\\$outputPathName\\_Computers.txt" 
            }

            elseif ($LastBootUpTime -eq $false){
                "[-] Access is denied on $computer" | Write-Host -ForegroundColor Red
                continue
            }

            else {
                # We know we are local admin
                Write-Output "[+] Enumerating $computer using RPC"
            }

            # We are local admin

            "[+] $computer LastBootUpTime is $LastBootUpTime `n" | Add-Content $sessionOutput 
            Write-Host "[+] $computer LastBootUpTime is $LastBootUpTime`n" 
                
            FindUserInMemory -server $computer -sessionOutput $sessionOutput -OutputPath $OutputPath -convBootupTime $LastBootUpTime
        }
        
        #If SMB or RPC is open, do not check winrm
        if ($smbResult -or $wmiResult) {
            continue
        }

        $winrm = PortScan -server $computer -port 5985
    
        if ($winrm) {
            $winrmPath = "$OutputPathName\\_openWinrm"
            CreateDirectory -OutputPath $winrmPath
            Write-Output "[+] Port 5985 is open `n" | Add-Content "$OutputPathName\\_openWinrm\\$computer"
            Write-Host  "[+] Port 5985 is open $computer`n"
        }

        if (-not ($smbResult -or $wmiResult -or $winrm)) {
            "[+] No ports are open on $computer, but it has resolved" | Add-Content -Path "$OutputPathName\\noPortsOpen.txt"
            Write-Host "[+] No ports are open on $computer" -ForegroundColor Red
        }
    }
    "[+] Writing output to $pwd\\$OutputPathName" | Write-Host -ForegroundColor Yellow  
}
