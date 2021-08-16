Function Invoke-FileUpload {
    Param (
        [Parameter(Mandatory=$true,HelpMessage="URL to upload to")][string]$UploadUrl,
        [Parameter(Mandatory=$true,HelpMessage="Path of file to upload")][string]$FileToUpload,
        [Parameter(Mandatory=$false,HelpMessage="Verb to use for file upload, e.g. POST")][string]$UploadVerb = "POST",
        [Parameter(Mandatory=$false,HelpMessage="Name of file form")][string]$FileFormName = "files",
        [Parameter(Mandatory=$false,HelpMessage="Compute SHA-256 hashsum after sending file")][bool]$ComputeHashsum = $true,
        [Parameter(Mandatory=$false,HelpMessage="Allow specific server certificate fingerprint")][string]$AllowedServerCertificateFingerprint = $null,
        [Parameter(Mandatory=$false,HelpMessage="Ignore SSL certificate errors (unsafe)")][bool]$IgnoreCertificateErrors = $false,
        [Parameter(Mandatory=$false,HelpMessage="X509 client certificate file to use")][string]$X509ClientCertificateFile = $null,
        [Parameter(Mandatory=$false,HelpMessage="Password for X509 client certificate")][Security.SecureString]$X509ClientCertificatePassword = $(ConvertTo-SecureString -String "" -AsPlainText -Force),
        [Parameter(Mandatory=$false,HelpMessage="Timeout in minutes")][int]$TimeoutMinutes = 30
    )

    If ($AllowedServerCertificateFingerprint -Or $IgnoreCertificateErrors) {
        $Condition1 = ""
        $Fallback = "return false;"

        If ($AllowedServerCertificateFingerprint) {
            Write-Output "Allow specific server certificate fingerprint"
            $Condition1 = "if (x509Certificate.GetCertHashString().Equals(""" + $AllowedServerCertificateFingerprint + """)) { return true; }"
        }

        If ($IgnoreCertificateErrors) {
            Write-Output "Ignore SSL certificate errors (unsafe)"
            $Fallback = "return true;"
        }

Add-Type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class CustomCertificatePolicy : ICertificatePolicy {
            public bool CheckValidationResult(ServicePoint servicePoint, X509Certificate x509Certificate, WebRequest webRequest, int certificateProblem) {
                $Condition1
                $Fallback
            }
        }
"@
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object CustomCertificatePolicy
    }

    Write-Output "Use TLS 1.2"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Output "Create multipart"
    $LF = "`r`n"
    $DoubleHyphens = "--"
    $Boundary = "------------------------" + [System.Guid]::NewGuid().ToString()
    $Prefix = $DoubleHyphens + $Boundary + $LF
    $Prefix += "Content-Disposition: form-data; name=""" + $FileFormName + """; filename=""" + $(Split-Path $FileToUpload -leaf) + """" + $LF
    $Prefix += "Content-Type: application/octet-stream" + $LF + $LF
    $Suffix = $LF + $DoubleHyphens + $Boundary + $DoubleHyphens + $LF

    Try {
        Write-Output "Open file"
        $FileInputStream = [System.IO.File]::OpenRead($FileToUpload)

        Write-Output "Create web request"
        $HttpWebRequest = [System.Net.HttpWebRequest]::Create($UploadUrl)
        $HttpWebRequest.AllowWriteStreamBuffering = $false
        $HttpWebRequest.Timeout = $TimeoutMinutes * 60 * 1000
        $HttpWebRequest.Method = $UploadVerb
        $HttpWebRequest.ContentLength = $Prefix.Length + $FileInputStream.Length + $Suffix.Length
        $HttpWebRequest.ContentType = "multipart/form-data; boundary=""" + $Boundary + """"

        If ($X509ClientCertificateFile) {
            Write-Output "Use client certificate"
            $X509ClientCertificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            $X509ClientCertificate.Import($X509ClientCertificateFile, $X509ClientCertificatePassword, "DefaultKeySet")
            $HttpWebRequest.ClientCertificates.Add($X509ClientCertificate)
        }

        Write-Output "Get output stream"
        $RequestOutputStream = $HttpWebRequest.GetRequestStream()

        Write-Output "Write prefix to output stream"
        $PrefixBytes = [System.Text.Encoding]::UTF8.GetBytes($Prefix)
        $RequestOutputStream.Write($PrefixBytes, 0, $PrefixBytes.Length)

        Write-Output "Write file to output stream"
        $FileInputStream.CopyTo($RequestOutputStream)

        Write-Output "Write suffix to output stream"
        $SuffixBytes = [System.Text.Encoding]::UTF8.GetBytes($Suffix)
        $RequestOutputStream.Write($SuffixBytes, 0, $SuffixBytes.Length)

        Write-Output "File sent"

        If ($ComputeHashsum) {
            Write-Output "Compute SHA-256 hashsum"
            Get-FileHash -Path $FileToUpload
        }
    } Finally {
        Write-Output "Close input and output streams"
        $FileInputStream.Close()
        $RequestOutputStream.Close()

        Write-Output "Revert certificate policy"
        [System.Net.ServicePointManager]::CertificatePolicy = $null
    }
}
Export-ModuleMember -Function Invoke-FileUpload
