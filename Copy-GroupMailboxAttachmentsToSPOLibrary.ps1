<# 
 Microsoft provides programming examples for illustration only, without warranty either expressed or
 implied, including, but not limited to, the implied warranties of merchantability and/or fitness 
 for a particular purpose. We grant You a nonexclusive, royalty-free right to use and modify the 
 Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that
 You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the
 Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which
 the Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers
 from and against any claims or lawsuits, including attorneys' fees, that arise or result from the
 use or distribution of the Sample Code.
 
 This sample assumes that you are familiar with the programming language being demonstrated and the 
 tools used to create and debug procedures. Microsoft support professionals can help explain the 
 functionality of a particular procedure, but they will not modify these examples to provide added 
 functionality or construct procedures to meet your specific needs. if you have limited programming 
 experience, you may want to contact a Microsoft Certified Partner or the Microsoft fee-based consulting 
 line at (800) 936-5200. 
#>

# Script Parameters
param 
(
    [Parameter(Mandatory=$false)][string]$GroupId,
    [Parameter(Mandatory=$false)][string]$SiteUrl,
    [Parameter(Mandatory=$false)][string]$LibraryName,
    [Parameter(Mandatory=$false)][string]$FolderName
)

function Get-Token 
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)][string]$Tenant,
        [Parameter(Mandatory = $true)][System.Guid]$ClientID,
        [Parameter(Mandatory = $true)][string]$ClientSecret,
        [Parameter(Mandatory = $true)][string]$Resource
    )
    
    begin 
    {
    }  
    process {
        $Body = @{
            grant_type    = "client_credentials"
            scope         = "$Resource/.default"
            client_id     = $ClientID
            client_secret = $ClientSecret
        } 
      
        $RequestToken = @{
            ContentType = 'application/x-www-form-urlencoded'
            Method      = 'POST'
            Body        = $Body
            Uri         = "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token"
        }
  
        try {
            $response = Invoke-RestMethod @RequestToken
        }
        catch {
            Write-Error $_.Exception
        }
    }
    end 
    {
        $response
    }
}

function Get-AuthenticationHeaders
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken
    )

    begin
    {
    }
    process
    {
        @{
            'Content-Type'  = 'application/json'
            'Authorization' = "Bearer $($AccessToken)"
        }    
    }
    end
    {
    }
}

function Get-ConversationsWithAttachments
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$GroupId
    )

    begin
    {
        $conversations = @()
        $headers = Get-AuthenticationHeaders -AccessToken $AccessToken
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/conversations?`$filter=hasAttachments eq true" 
    }
    process
    {
        do
        {
            $json = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
            $conversations += $json.value
            $uri = $json.'@odata.nextLink'
        }
        while( $uri )
    }
    end
    {
       $conversations
    }
}

function Get-Threads
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$GroupId,
        [Parameter(Mandatory=$true)][string]$ConversationId
    )

    begin
    {
        $threads = @()
        $headers = Get-AuthenticationHeaders -AccessToken $AccessToken
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/conversations/$ConversationId/threads" 
    }
    process
    {
        do
        {
            $json = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
            $threads += $json.value
            $uri = $json.'@odata.nextLink'
        }
        while( $uri )
    }
    end
    {
       $threads
    }
}

function Get-Posts
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$GroupId,
        [Parameter(Mandatory=$true)][string]$ConversationId,
        [Parameter(Mandatory=$true)][string]$ThreadId
    )

    begin
    {
        $posts = @()
        $headers = Get-AuthenticationHeaders -AccessToken $AccessToken
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/conversations/$ConversationId/threads/$ThreadId/posts" 
    }
    process
    {
        do
        {
            $json = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
            $posts += $json.value
            $uri = $json.'@odata.nextLink'
        }
        while( $uri )
    }
    end
    {
       $posts
    }
}

function Get-Attachments
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)][string]$AccessToken,
        [Parameter(Mandatory=$true)][string]$GroupId,
        [Parameter(Mandatory=$true)][string]$ConversationId,
        [Parameter(Mandatory=$true)][string]$ThreadId,
        [Parameter(Mandatory=$true)][string]$PostId
    )

    begin
    {
        $attachments = @()
        $headers = Get-AuthenticationHeaders -AccessToken $AccessToken
        $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/conversations/$ConversationId/threads/$ThreadId/posts/$PostId/attachments" 
    }
    process
    {
        do
        {
            $json = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
            $attachments += $json.value
            $uri = $json.'@odata.nextLink'
        }
        while( $uri )
    }
    end
    {
       $attachments
    }
}

# script requires Group.Read.All
# script requires Write to Library: <AppPermissionRequests AllowAppOnlyPolicy="true"><AppPermissionRequest Scope="http://sharepoint/content/sitecollection/web/list" Right="Write"/></AppPermissionRequests>

$tenant       = "contoso.onmicrosoft.com"
$clientId     = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxx"                # aka "Application ID" in Azure Portal > Azure Active Directory > App Registrations
$clientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"     # aka "Keys" in Azure Portal > Azure Active Directory > App Registrations

$token = $null
$token = Get-Token -Tenant $tenant -ClientID $clientId -ClientSecret $clientSecret -Resource "https://graph.microsoft.com"

Connect-PnPOnline -Url $SiteUrl -AppId $clientId -AppSecret $clientSecret

if( -not $token -or -not $token.access_token ) 
{
    break
}

$conversations = Get-ConversationsWithAttachments -AccessToken $token.access_token -GroupId $GroupId

foreach ($conversation in $conversations) {
    $threads = Get-Threads -AccessToken $token.access_token -GroupId $GroupId -ConversationId $conversation.id

    Write-Host "Processing Conversation: $($conversation.topic)"

    $threadsWithAttachments = $threads | ? {$_.hasAttachments}
    foreach ($thread in $threadsWithAttachments) {
        $posts = Get-Posts -AccessToken $token.access_token -GroupId $GroupId -ConversationId $conversation.id -ThreadId $thread.id

        $postsWithAttachments = $posts | ? {$_.hasAttachments}
        foreach ($post in $postsWithAttachments) {
            $attachments = Get-Attachments -AccessToken $token.access_token -GroupId $GroupId -ConversationId $conversation.id -ThreadId $thread.id -PostId $post.id

            foreach ($attachment in $attachments) {
                $bytes = [System.Convert]::FromBase64String($attachment.contentBytes)
                $stream = [IO.MemoryStream]::new($bytes)
                $utcDateFormatted = (Get-Date $thread.lastDeliveredDateTime).ToUniversalTime().ToString("yyyy_MM_dd_HH_mm_ss")
                $folderPath = "$LibraryName/$FolderName/$($thread.topic)_$utcDateFormatted"

                Write-Host "  Uploading Attachment: $($attachment.name)"
                Resolve-PnPFolder -SiteRelativePath $folderPath
                Add-PnPFile -FileName $attachment.name -Folder $folderPath -Stream $stream | Out-Null
            }
        }
    }
}