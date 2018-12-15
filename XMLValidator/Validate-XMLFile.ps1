<#
.SYNOPSIS
Valid XML files using XSD.

.DESCRIPTION
This script will valid XML file using the provided XSD.

.PARAMETER Path
Specifies the path which contains the xml file to be validated.

.PARAMETER SchemaPath
Specifies the XSD file to be used.

.EXAMPLE
PS> .\Validate-XMLFile.ps1 -Path Customer.xml -SchemaPath Customer.xsd

This command validates Customer.xml file using Customer.xsd schema.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_} )]
    # Specify the XML file
    [String] $Path,

    [Parameter(Mandatory = $true)]
    [ValidateScript( { Test-Path $_} )]
    # Specify the XSD file
    [String] $SchemaPath
)

Function Test-XMLSchema {
    Param (
        [String] $Path,
        [String] $SchemaPath
    )

    # Load XSD file
    $xmlSchema = Read-XSDFile -SchemaPath $SchemaPath
    $schemas = New-Object System.Xml.Schema.XmlSchemaSet
    [void] $schemas.Add($xmlSchema)
    $schemas.Compile()

    try {
        [xml]$xmlData = Get-Content $Path
        $xmlData.Schemas = $schemas

        Write-Verbose "Validating $Path using $SchemaPath ..."
        # Validate the schema. This will fail if is invalid schema
        $xmlData.Validate($null)

        Write-Verbose "XML Validated OK"
    }
    catch [System.Xml.Schema.XmlSchemaValidationException] {
        Write-Warning $_
        return $false
    }

    return $true
}

Function Read-XSDFile {
    param([String] $SchemaPath)
    try {
        $schemaItem = Get-Item $SchemaPath
        $stream = $schemaItem.OpenRead()
        $schema = [Xml.Schema.XmlSchema]::Read($stream, $null)
    }
    catch {
        throw
    }
    finally {
        if ($stream) {
            $stream.Close()
        }
    }

    return $schema
}

if (-not (Test-XMLSchema -Path $Path -SchemaPath $SchemaPath)) {
    exit 1
}

exit 0