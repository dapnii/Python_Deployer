#Converts .txt file contents into array
$_hostnamesArray = Get-Content -Path '.\hostnames.txt'
#Array that contains already checked machines
$_alreadyINSTALLED = @()
#Start logging all 'Write-Host"
Start-Transcript -Path ".\logs\Transcript - $((Get-Date -f "yyyy-MM-dd HH;mm;ss").ToString()).txt"
#Checks if there is "logs" folder in the folder where script is located and if not creates it.
if (-not (Test-Path .\logs)) {
    New-Item -ItemType Directory -Path .\logs -Force | Out-Null
}
#Checks if there is Python .exe installer in the folder where script is located
if (-not (Test-Path .\python-3.12.2-amd64.exe )) {
    $_URL = "https://www.python.org/ftp/python/3.12.2/python-3.12.2-amd64.exe"
    $_Output = ".\python-3.12.2-amd64.exe"
    $_StartTime = Get-Date
    $_DownloadObject = New-Object System.Net.WebClient
    Write-Host "[$(Get-Date)] Python installer not detected" -ForegroundColor Magenta
    Write-Host "[$(Get-Date)] Downloading Python installer" -ForegroundColor Magenta
    $_DownloadObject.DownloadFile($_URL, $_Output)
    Write-Host "[$(Get-Date)] Time taken: $((Get-Date).Subtract($_StartTime).Seconds) second(s)" -ForegroundColor Magenta
}

#Main loop
$_isLive = $true
while ($_isLive) {
    foreach($hostname in $_hostnamesArray) {
        #Checks if hostname is present in alreadyINSTALLED array
        if (-not ($_alreadyINSTALLED -contains $hostname)) {
            #Checks if machine is available on the network
            if (($_connectionCHECK = Test-Connection -ComputerName $hostname -count 1 -ErrorAction SilentlyContinue) -and 
            ($_mOSCHECK = Get-WmiObject -ComputerName $hostname Win32_OperatingSystem -ErrorAction SilentlyContinue ) -and
            ($_userCHECK = cmd.exe /c "query user /SERVER:$hostname")) {
                Write-Host "[$(Get-Date)] $hostname is available" -ForegroundColor Green
                #Checks if app is already installed
                $_Apps = Invoke-Command -ComputerName $hostname -ScriptBlock {
                    $GetAllApps = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,`
                    HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |`
                    Get-ItemProperty -Name DisplayName -ErrorAction SilentlyContinue | Select * -ExcludeProperty PS*;`
                    $GetAllApps
                }
                $_AppNames = @()
                foreach ($App in $_Apps) {
                    $_AppNames += $App.DisplayName
                }
                #If app is not already installed, copies file to machine
                if (-not ($_AppNames -like "*Python 3.12.2*")) {
                    if (-not (Test-Path \\$hostname\C$\Support)) {
                        Invoke-Command -ComputerName $hostname -ScriptBlock {
                            New-Item -ItemType Directory -Path "C:\Support" -Force | Out-Null
                        }
                    }
                    $_PathTest = Test-Path \\$hostname\C$\Support\python-3.12.2-amd64.exe
                    if (-not $_PathTest) {
                        $_Copy = xcopy .\python-3.12.2-amd64.exe \\$hostname\C$\Support
                    }
                    #Checks if file is already transfered and starts installation
                    if ($_Copy -or $_PathTest) {
                        Write-Host "[$(Get-Date)] Python installation file has been transfered to \\$hostname\C:\Support\ successfully" -ForegroundColor Green
                        Write-Host "[$(Get-Date)] Please wait..." -ForegroundColor Green
                        Start-Sleep -Seconds 5
                        $_Installation = Invoke-Command -ComputerName $hostname -ScriptBlock {
                            Write-Host "[$(Get-Date)] Python installation has been successfully started" -ForegroundColor Green
                            Start-Process -FilePath C:\Support\python-3.12.2-amd64.exe -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -noNewWindow -Wait
                        }
                        Write-Host "[$(Get-Date)] Python installation has been successfully completed on $hostname" -ForegroundColor Green
                        $_alreadyINSTALLED += $hostname
                    }
                } else {
                    Write-Host "[$(Get-Date)] Python 3.12.2 is already installed on $hostname" -ForegroundColor Green
                    $_alreadyINSTALLED += $hostname
                }
            } else {
                Write-Host "[$(Get-Date)] $hostname couldn't be reached" -ForegroundColor Red
                Continue
            }
        }
    }
}
Stop-Transcript
