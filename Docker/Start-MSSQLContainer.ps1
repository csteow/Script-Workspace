param (
    [string] $Password = "secret",
    [int] $Port = 1433
)

# Start the container
Write-Host "Startup MSSQL container ..."
$containerID = $(docker run -d -p ${Port}:1433 -e sa_password=$Password -e ACCEPT_EULA=Y microsoft/mssql-server-windows-express)
Write-Host -Foreground Blue "Container ID = $containerID"

# List the created container
& docker ps -l

if ($containerID) {
    # Get the container IP address
    $serverIP = $(docker inspect -f "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" $containerID)
    Write-Host -Foreground Blue "Container IP: $serverIP"

    # Verify the connection
    Write-Host "Connecting to MSSQL ..."
    & docker exec $containerID sqlcmd -Q "select @@servername servername"
}

Write-Host "Done!"  