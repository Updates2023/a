# Define the UNC path to the Users directory
$UNCPath = "\\SE-DP-02.dom1.vinci-energies.net\C$\Users"

# Initialize an array to store output results
$outputResults = @()

# Get all user directories from the UNC path
$users = Get-ChildItem -Path $UNCPath -Directory -ErrorAction SilentlyContinue

foreach ($user in $users) {
    # Construct the path to the PSReadLine history file for each user
    $historyPath = Join-Path -Path $user.FullName -ChildPath "AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    
    if (Test-Path $historyPath) {
        Write-Host "Reading history for user '$($user.Name)' from $historyPath"
        try {
            $content = Get-Content -Path $historyPath -ErrorAction Stop
            # Create a custom object with the user's name, file path, and file content
            $outputResults += [PSCustomObject]@{
                User    = $user.Name
                File    = $historyPath
                Content = $content -join "`n"
            }
        } catch {
            Write-Error "Error reading file at ${historyPath}: $_"
        }
    } else {
        Write-Host "No history file found for user '$($user.Name)' at $historyPath"
    }
}

# Output the aggregated results in a table format
$outputResults | tee-object "C:\Users\Public\results"
