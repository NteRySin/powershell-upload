# PowerShell Upload

## Introduction
 Multipart file upload [PowerShell script](powershell-upload.ps1) supporting:
 - Streaming for big files
 - Allow specific server certificate fingerprint
 - Ignore SSL certificate errors (unsafe)
 - X509 client certificate authentication

## Usage
Upload the file `example.txt` to the endpoint `https://www.example.com/upload` using a client certificate and accepting only the server certificate with fingerprint `DA39A3EE5E6B4B0D3255BFEF95601890AFD80709`:

    Import-Module .\powershell-upload.psm1
    Invoke-FileUpload `
    -UploadUrl https://www.example.com/upload `
    -FileToUpload .\example.txt `
    -AllowedServerCertificateFingerprint DA39A3EE5E6B4B0D3255BFEF95601890AFD80709 `
    -X509ClientCertificateFile .\clientcertificate.p12 `
    -X509ClientCertificatePassword $(ConvertTo-SecureString -AsPlainText -Force -String "")

It can be tested with the [uploadserver](https://pypi.org/project/uploadserver/) Python module for instance.

## Future plans
- Send POST parameters
