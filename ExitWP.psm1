<# 
.SYNOPSIS
   Converts a WordPress blog to Jekyll
#>
Function ConvertTo-JekyllBlog {
    
    [CmdletBinding(SupportsShouldProcess)]
    Param
    (
        #Specifies the wordpress.xml source file path 
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $InputPath,

        #Encoding of wordpress.xml file. Defaults to UTF8
        [Parameter()]
        $Encoding = 'UTF8',

        #Path to output directory for post files
        [Parameter()]
        [string]
        $DestinationPath = '.',

        # Specifies the types of content to convert. Defaults to posts and pages
        [Parameter()]
        [string[]]
        $ContentTypes = @('post'),

        # Limits exporting to posts in the specified language. If omitted, all posts are included.
        [Parameter()]
        [string[]]
        $Language,

        # Specifies whether images should be downloaded
        [Parameter()]
        [switch]
        $DownloadImages,

        # Specifies the output format for posts and pages. Default to Markdown (md)
        [Parameter()]
        [ValidateSet("html", "md")]
        [string]
        $OutputFormat = 'md',

        # Specifies where images and other attachments should be saved. Defaults to the same folder where the page/post Markdown is saved
        [Parameter()]
        [ValidateSet('AssetsFolder', 'PostFolder')]
        [string]
        $AttachmentDestination = 'PostFolder',

        #Specifies whether draft posts should be excluded from exporting
        [Parameter()]
        [switch]
        $ExcludeDrafts,

        #Forces the command to run without asking for user confirmation
        [Parameter()]
        [switch]
        $Force
    )

    Begin
    {
        Add-Type -Path (Join-Path $PSScriptRoot 'HtmlAgilityPack.dll')
        Add-Type -Path (Join-Path $PSScriptRoot 'Html2Markdown.dll')
    }

    Process
    {
        $DestinationPath = Get-OutputDirectory $DestinationPath
        $PostOutputPath = Get-OutputDirectory (Join-Path $DestinationPath '_posts')

        if ((Get-ChildItem $PostOutputPath) -and (-not $Force.IsPresent))
        {
            throw "Output path $PostOutputPath contains files. To overwrite its contents, use -Force switch"
        }
        
        $xml = [xml] (Get-Content $InputPath -Raw -Encoding $Encoding)

        foreach($postXml in ($xml.rss.channel.item | Where-Object {$_.post_type.InnerText -in $ContentTypes}))
        {
            if($Language)
            {
                $lang = $postXml.SelectNodes("category[@domain='language']/@nicename").Value

                if ($lang -and ($Language -notcontains $lang))
                {
                    continue
                }
            }

            $post = ConvertTo-PostObject $postXml

            if(($post.status -eq 'draft') -and ($ExcludeDrafts.IsPresent)) { continue }

            Export-Post $post $DestinationPath

            return $post
        }
    }
}

Function ConvertTo-PostObject($inputObject)
{
    $inputContents = $inputObject.encoded[0].InnerText
    
    if ($OutputFormat -eq 'md')
    {
        $body = ConvertTo-Markdown $inputContents
    }
    else
    {
        $body = $inputContents    
    }

    $post = @{
        title = $inputObject.title.Trim()
        link = $inputObject.link
        author = $inputObject.creator.InnerText
        date = $inputObject.post_date_gmt.InnerText
        slug = $inputObject.post_name.InnerText
        status = $inputObject.status.InnerText
        type = $inputObject.post_type.InnerText
        wp_id = $inputObject.post_id
        parent = $inputObject.post_parent
        comments = ($inputObject.comment_status -eq 'open')
        body = $body
        format = $OutputFormat
        excerpt = $inputObject.encoded[1].InnerText
        imageSources = Get-ImageSources $inputContents
        image = Get-FeaturedImage $inputObject
        XmlElement = $inputObject
    }

    foreach($cat in $inputObject.category)
    {
        $item = [PSCustomObject]@{
            Slug = $cat.nicename
            Name = $cat.InnerText
        }

        if (-not $post[$cat.domain])
        {
            $post[$cat.domain] = @()
        }

        $post[$cat.domain] += $item
    }

    return [PSCustomObject] $post
}

Function Export-Post($post, $destinationPath)
{
    $outputPath = $destinationPath

    if($post.Type -eq 'post')
    {

    }
    else
    {
        $outputPath = Join-Path $outputPath (Join-Path)
    }
}

Function ConvertTo-Markdown($html)
{
    $converter = [Html2Markdown.Converter]::new()
    return $converter.Convert($html)
}

Function Get-ImageSources($html)
{
    if (-not $html)
    {
        return @()
    }

    try
    {
        $doc = [HtmlAgilityPack.HtmlDocument]::new()
        $doc.LoadHtml($html)
        
        return $doc.DocumentNode.SelectNodes('//img[@src]') | ForEach-Object { 
            if($_) {
                [PSCustomObject] @{
                    OriginalUrl = $_.Attributes['src'].Value
                    Url = Get-LocalImageUrl $_.Attributes['src'].Value
                    FilePath = Get-LocalImageFilePath $_.Attributes['src'].Value $AttachmentDestination
                }
            }
        }
    }
    catch
    {
        Write-Warning "Error parsing HTML: $($_.Exception)"
    }
}

Function Get-LocalImageUrl($url)
{

}

Function Get-LocalImageFilePath($url, $attachmentDestination)
{

}

Function Get-OutputDirectory($Path)
{
    if (-not (Test-Path $Path))
    {
        [void] (New-Item $Path -ItemType Directory)
    }

    return Resolve-Path $Path
}

Function Get-FeaturedImage($inputObject)
{
    if (-not $inputObject)
    {
        return ''
    }

    try
    {
        Write-Output $inputObject
    }
    catch
    {
        Write-Warning "Error parsing HTML: $($_.Exception)"
    }        
}
