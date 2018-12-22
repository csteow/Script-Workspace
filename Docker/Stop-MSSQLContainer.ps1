param (
    [Parameter(Mandatory=$true)]
    [string[]] $ContainerId,

    [switch] $Cleanup = $false
)

Write-Host "Stopping $ContainerId ..."

& docker stop $ContainerId

# Remove the stopped container(s)
if ($CleanUp) {
    Write-Host "Removing the stopped containers ..."
    & docker rm $ContainerId
}

Write-Host "List the available container(s)"
& docker ps -a

Write-Host "Done!"  