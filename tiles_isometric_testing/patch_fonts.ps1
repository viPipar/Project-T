$files = @(
    "c:\Users\rafid\Downloads\_Repos\Project-T\tiles_isometric_testing\ui\menu\MainMenu.tscn",
    "c:\Users\rafid\Downloads\_Repos\Project-T\tiles_isometric_testing\ui\menu\DisclaimerScreen.tscn",
    "c:\Users\rafid\Downloads\_Repos\Project-T\tiles_isometric_testing\ui\menu\SplashScreen.tscn"
)

foreach ($file in $files) {
    Write-Host "Patching $file..."
    $content = Get-Content $file -Raw
    
    $ext_pirata = '[ext_resource type="FontFile" path="res://assets/ui_assets/PirataOne-Regular.ttf" id="pirata_font"]'
    $ext_meta = '[ext_resource type="FontFile" path="res://assets/ui_assets/Metamorphous-Regular.ttf" id="meta_font"]'
    
    # Inject ExtResources after the first Script ext_resource
    $content = $content -replace "\[ext_resource type=`"Script`"([^\]]+)\]", "`$0`r`n$ext_pirata`r`n$ext_meta"
    
    # Replace SubResource usages
    $content = $content.Replace('SubResource("SystemFont_title")', 'ExtResource("pirata_font")')
    $content = $content.Replace('SubResource("SystemFont_bold")', 'ExtResource("pirata_font")')
    $content = $content.Replace('SubResource("SystemFont_menu_btn")', 'ExtResource("meta_font")')
    $content = $content.Replace('SubResource("SystemFont_label")', 'ExtResource("meta_font")')
    
    # Strip sub_resource definitions
    $content = [regex]::Replace($content, '\[sub_resource type="SystemFont" id="[^"]+"\]\r?\n(?:[^\[\r\n]+\r?\n|\r?\n)*', '')
    
    Set-Content $file -Value $content -NoNewline
    Write-Host "Done patching $file"
}
