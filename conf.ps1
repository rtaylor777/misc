# Lets test if we can add some firewall rules successfully. 
# first clean up matching rules
$fwoutput=netsh advfirewall firewall delete rule name="Allow source 198.51.100.0/24 in through firewall"
if ($LastExitCode){
	Write-Host "Please right click on the script and select Run as administrator"
	Write-Host
	exit
}
$fwoutput=netsh advfirewall firewall delete rule name="Allow dest 198.51.100.0/24 out through firewall"
if ($LastExitCode){
	Write-Host "Please right click on the script and select Run as administrator"
	Write-Host
	exit
}
# then add the rules
$fwoutput=netsh advfirewall firewall add rule name="Allow source 198.51.100.0/24 in through firewall" dir=in action=allow protocol=ANY remoteip=198.51.100.0/24
if ($LastExitCode){
	Write-Host "Please right click on the script and select Run as administrator"
	Write-Host
	exit
}	
$fwoutput=netsh advfirewall firewall add rule name="Allow dest 198.51.100.0/24 out through firewall" dir=out action=allow protocol=ANY remoteip=198.51.100.0/24
if ($LastExitCode){
	Write-Host "Please right click on the script and select Run as administrator"
	Write-Host
	exit
}
# Change directory to a temp directory indicated by the environment variable
$tempDir=(Get-Childitem -path env:TEMP|select value|Format-Table -HideTableHeaders | Out-String).trim()
cd $tempDir
# Make a child directory that doesn't exist
$newLeaf=[guid]::NewGuid()
$newPath=$tempDir+'\'+$newLeaf
if ( -not (Test-Path -Path $newPath) ){
	Try {
		$mkdirresult=mkdir $newLeaf
	}
	Catch {
		Write-Host "Directory creation failed, probably TEMP directory is not writable"
	}
}
if (Test-Path -Path $newPath){
	# Change into this new directory
	cd $newLeaf
	# set $filename variable to current directory
	$filename=(pwd|select Path|Format-Table -HideTableHeaders | Out-String).trim()
	# add desired output file name to the full path in $filename variable
	$filename+='\OpenVPN-2.6.5-I001-amd64.msi'
	# download OpenVPN file to $filename
	(new-object System.Net.WebClient).DownloadFile('https://swupdate.openvpn.org/community/releases/OpenVPN-2.6.5-I001-amd64.msi',$filename)
	# Test that the downloaded file exists
	if (Test-Path -Path $filename){
		#Download successful
		# If OpenVPN adapter is missing, attempt to install OpenVPN
		try { 
				$OpenVPNStatus=Get-NetAdapter -Name 'OpenVPN Data Channel Offload' -ErrorAction Stop |Select Status 
			} 
		Catch {
			msiexec /i \temp\OpenVPN-2.6.4-I001-amd64.msi ADDLOCAL=OpenVPN,OpenVPN.Service,Drivers.OvpnDco,Drivers,Drivers.TAPWindows6,Drivers.Wintun /qn
		}
		$Pfiles=(Get-Childitem -path env:ProgramFiles|select value|Format-Table -HideTableHeaders | Out-String).trim()
		$configpath=$Pfiles+"\OpenVPN\config-auto"
		$configFile=$configpath+"\client1win.ovpn"
		if (Test-Path -Path $configpath){
			if (Test-Path -Path $configFile){
				Write-Host "Config file already exists"
			} else {
				# Attempting to download config file
				(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/rtaylor777/misc/main/somesettings.txt',$configFile)
			}
			# Test that the expected Adapter exists confirming successful OpenVPN install
			try { 
				$OpenVPNStatus=Get-NetAdapter -Name 'OpenVPN Data Channel Offload' -ErrorAction Stop |Select Status
			} 
			Catch { 
				Write-Host "Adapter missing, it's possible OpenVPN did not install correctly"
				exit
			}
			# Lets see if we can set up ICS correctly
			$getics=$newPath+'\Get-MrInternetConnectionSharing.ps1'
			$setics=$newPath+'\Set-MrInternetConnectionSharing.ps1'
			(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/rtaylor777/misc/main/Get-MrInternetConnectionSharing.ps1',$getics)
			(new-object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/rtaylor777/misc/main/Set-MrInternetConnectionSharing.ps1',$setics)
			. $getics
			. $setics
			$gatewayinterface=(Get-NetIPConfiguration |Foreach IPv4DefaultGateway|Select ifIndex|Get-NetAdapter |Where-Object Status -eq "up"|select Name|Format-Table -HideTableHeaders | Out-String).trim()
			# use switch statement to prevent function call with break from stopping parent script
			switch ('dummy') { default {Set-MrInternetConnectionSharing -InternetInterfaceNacme $gatewayinterface -LocalInterfaceName 'OpenVPN Data Channel Offload' -Enabled $true}}
		} else {
			Write-Host "It seems like the OpenVPN install did not work correctly"
			exit
		}
	}else{
		Write-Host "Download failed"
	}
	# clean up
	Try {
		Write-Host "Removing $newLeaf"
		cd $tempDir
		rm -r $newLeaf -ErrorAction Stop
	}
	Catch {
		Write-Host "Unable to remove $newLeaf"
	}
}
