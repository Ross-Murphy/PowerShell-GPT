# PowerShell-GPT - an OpenAI Chat for PowerShell.
# https://github.com/Ross-Murphy/PowerShell-GPT
# MIT License
# https://platform.openai.com/docs/api-reference
#

# Cross-platform home directory
$Global:USERHOME = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)

# Create Object to hold config
$Global:Config = [PSCustomObject] @{
    API_KEY = ''
    endpoint = ""
    model = ""
    system_msg = ""
    ConfigPath = ""
    ConfigFile = ""
    Debugging = ""
    AppVersion = ""
}
$Global:Models = @(
    'gpt-3.5-turbo', # Default The Large Lang Model to use.
    'gpt-3.5-turbo-16k',
    'gpt-4',
    'gpt-4-32k'
)

# Set some defaults
$Config.ConfigPath = Join-Path -Path $USERHOME -ChildPath '.PowerShell-GPT' # Location of config dir
$Config.ConfigFile = Join-Path -Path $Config.ConfigPath -ChildPath 'PowerShell-GPT_config.json' # Default name of the config file.
$Config.endpoint = 'https://api.openai.com/v1/chat/completions' # The OpenAI endpoint for chat/completions
$Config.model = $Global:Models[0] # Default The Large Lang Model to use.
$Config.system_msg = "You are my helpful assistant. Please be brief." # Default system message. Can be configured during setup.
$Config.Debugging = '0' # Enable more verbose output for troubleshooting. Token counting.
$Config.AppVersion = '0.5.3' # Current module version

# --- Functions --- 
Function invoke-Bot { # Send current prompt and an array with messages history to API.
    param(
    [Parameter()][string]$api_key = $Global:Config.API_KEY,
    [Parameter()][string]$endpoint = $Global:Config.endpoint,
    [Parameter()][string]$model = $Global:Config.model,
    [Parameter()][array]$messages = $global:Session.Messages,
    [Parameter()][string]$prompt
    )
    if ($null -eq $api_key){return $false}
    if ($null -eq $endpoint){return $false}
    if ($null -eq $model){return $false}
    if (($null -eq $prompt) -and ($messages.Count -lt 1 ) ){return $false}

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $api_key"
    }

    $messages += @{ 
        role = 'user' 
        content = "$prompt" 
    }
    
    $body = @{
        messages = $messages
        model = "$model"       
    } | ConvertTo-Json -EscapeHandling EscapeNonAscii
   
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body $body 
    }
    catch {
        Write-Host -ForegroundColor Red "Invoke-RestMethod - An error occurred: $($_.Exception.Message)"
        return $false
    }
    
    $bot_reply = ($response.choices[0].message )
    $global:Session.Tokens = ($response.usage.total_tokens )
    return ($bot_reply |Write-Output)
}

Function invoke-SystemMessage{ # Send System message .
    param(
    [Parameter()][array]$messages,
    [Parameter()][string]$content
    )
    $response = $false
    $SystemMsg = New-Object -TypeName System.Collections.ArrayList
    
    if($content) { # Prepend Content system message 
        $SystemMsg += @{
            role="system"
            content = "$content" 
        }
    }
   
    foreach ($message in $messages) {
        $SystemMsg += @{ 
            role="system"
            content = "$message"   
        }
    }

    If($SystemMsg.Count -ge 1 ){
        $response = invoke-Bot -messages $SystemMsg # Send  $messages array
        $SystemMsg
    }
    
    if($response){
        #Write-Host -ForegroundColor Green $response.content  # display the response content to the console    
        #$messages
        return $response.content              
    } else {
        if ($Global:Config.Debugging){Write-Host -ForegroundColor Yellow "Warning. API Response is false"}
        return $response
    } 
}

function Get-MultiLineInput { # Dot-escape to exit.  ".<enter> " 
    $inputLines = @()
    $read_prompt = $true
    while ($read_prompt) {
        $line = Read-Host
        if( $line -eq '.' ){ # Exit if '.'
            $read_prompt = $false
        }
        if ([string]::IsNullOrEmpty($line)) {
            $inputLines += ""
        } else {
            $inputLines += $line
        }
    }
    return $inputLines -join "`n"
}

Function Read-Menu {
     param(
        [parameter()][array]$Options,
        [parameter()][string]$PromptText
    )
    $Check = $false
    If ($PromptText){ 
        Write-Host -ForegroundColor Green "$PromptText"
    } else {
        Write-Host -ForegroundColor Green "Please choose one of the following options..."
    }
    
    [int]$i = 1 # set counter
    while($Check -eq $false) {  
        Foreach ($MenuOption in $options){
            Write-Host -ForegroundColor Yellow "$i :> $MenuOption"
            $i++
        }
        Write-Host -ForegroundColor Yellow "0 :> Cancel"
        [int]$i = 1 # reset the counter.
        [int]$Choice = Read-Host -Prompt "Selection"
        
        If($Choice -le 0) { # returns 0 if chosen for cancel.
            $Check = $true
            return $false
        }
        If($Choice -le $options.Count){
            $Check = $true
            Return [int]$Choice - 1
        }Else{ 
            Write-Host -ForegroundColor Red "Invalid option. Please choose an option from 0 to $($options.Count)"
        }
    }  
} # Generate a menu with array of options. returns the int of the choice made. counts from 1.

Function Read-PromptYesNo{
    param(
        [Parameter()][string]$Question
    )
    $Check = $false
    while($Check -eq $false){
        Switch -Regex (Read-Host -Prompt "$Question `nYes/No"){
            {'yes', 'y' -contains $_} {
                $Check = $true
                return $true
            }
            {'no', 'n' -contains $_ } {
                $Check = $true
                Return $False
            }  
            default { Write-Host "Please enter Y/N"}
        }
    }
}  # Prompt for yes/no | y/n and return true/false

Function Start-Chat(){
    param(
        [parameter()][array]$messages = $global:Session.Messages,
        [parameter()][string]$Question = "`n" 
    )
    $model = $Global:Config.model
    Read-Config

    $command_menu = "
    You are now chatting with $model.  Type your chat message and hit <enter> to send. 
    Or choose a command from the menu.
---    
GPT-PowerShell Version 0.5
==================================================================================
Name                        Command             Description 
==================================================================================
Close Chat:                 Quit() or Exit()    End chat session. Alias Q() is Save and Quit.
Multiline input mode:       Multi() or M()      Multiline text entry mode, Use Dot-escape to exit .<enter> 
Save/Export Current Chat:   Save() or S()       Export Contents of current chat messages to `$Env:GPT_CHAT_MESSAGES 
Import Saved Chat:          Import() or I()     Import content of `$Env:GPT_CHAT_MESSAGES & append to current messages array.
Reset Chat Session:         Reset()             Clear messages array. Start fresh chat.
History:                    History()           Display Chat History. See Content of current messages array.
Config:                     Conf()              Display Current Configuration.
Setup:                      Setup()             Setup  config options. API-Key, system_msg, model context, debug msg
Help:                       Help()              Display this help menu.
    "
    Write-Host -ForegroundColor DarkMagenta $command_menu
    $Check = $false
    while($Check -eq $false){
        if ($Global:Config.Debugging){Write-Host -ForegroundColor Yellow "Current tokens $($Session.Tokens)"}

        Switch -Regex (Read-Host -Prompt "$Question"){
            {'Quit()', 'Exit()' -contains $_ } {
                $Check = $true
            }
            {'Q()' -contains $_ } {
                $Env:GPT_CHAT_MESSAGES = $global:Session.Messages|ConvertTo-Json
                $Check = $true
            }
            {'Multi()', 'M()' -contains $_ } {
                Write-Host -ForegroundColor DarkMagenta "Multi Line Input. Empty line with . to end "
                [string]$MultiLineInput = Get-MultiLineInput
                $response = invoke-Bot -prompt "$MultiLineInput" -messages $global:Session.Messages # Send Current prompt and $messages history
                if($response){
                    $global:Session.Messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                } 
            }
            {'History()' -contains $_ } {
                Write-Host -ForegroundColor Cyan  ( $global:Session.Messages|ConvertTo-Json)  # write out chat history as json
           }
            {'Save()', 'S()' -contains $_ } { # json export chat history and display it 
                 $Env:GPT_CHAT_MESSAGES = $global:Session.Messages|ConvertTo-Json
                 Write-Host -ForegroundColor DarkCyan $Env:GPT_CHAT_MESSAGES  
            }
            {'Import()', 'I()' -contains $_ } { # check $Env:GPT_CHAT_MESSAGES and see if it has an array and try to load it.
                #$Env:GPT_CHAT_MESSAGES = $global:Session.Messages|ConvertTo-Json
                $import_last = ($Env:GPT_CHAT_MESSAGES | ConvertFrom-Json) # prehaps some more checks here...
                if ( $import_last -is [array]){
                    $global:Session.Messages += $import_last
                }               
                Write-Host -ForegroundColor DarkCyan "Imported:`n$($Env:GPT_CHAT_MESSAGES)"
           }
           {'Clear()' -contains $_ } { # Clear export var 
                $Env:GPT_CHAT_MESSAGES = ""
           }
           {'Reset()' -contains $_ } { # Delete Current Chat History. Start over but don't exit. You can import saved chats
                $global:Session.Messages = @($global:Session.Messages[0]) # Keep only the inital system prompt
                $response = invoke-Bot -prompt "Ready?" -messages $global:Session.Messages # 
                if($response){
                    $global:Session.Messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                }              
           }
           {'Conf()' -contains $_ } { # Show current config
            Write-Host -ForegroundColor DarkMagenta "
                API_KEY    : $($Global:Config.API_KEY)
                Endpoint   : $($Global:Config.endpoint)
                Model      : $($Global:Config.model)
                ConfigPath : $($Global:Config.ConfigPath)
                ConfigFile : $($Global:Config.ConfigFile)
                System_Msg : $($Global:Config.system_msg)
                Debugging  : $($Global:Config.Debugging)
                AppVersion : $($Global:Config.AppVersion)
            "
           }
           {'Setup()' -contains $_ } { # Setup config.
            Start-PowerShellGPTSetup
           }

           {'Help()' -contains $_ } { # Show command menu options
            Write-Host -ForegroundColor DarkMagenta $command_menu
           }
            default { 
                if ($_ -eq ''){ # Do not send a blank line to our butler
                    continue
                }
                $response = invoke-Bot -prompt "$_" -messages $global:Session.Messages  # Send Current prompt and $messages history
                if($response){
                    $global:Session.Messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                }               
            }
        }
    }
} 


Function Set-PwshGPTConfig{
    param(
        [Parameter()][bool]$RunSetup = $false  
    )

    if( -not (Test-Path -Path $Global:Config.ConfigFile)){
        Write-Host -ForegroundColor Magenta "Config File not found $($Global:Config.ConfigFile)"
        $RunSetup = $true    
    } 

    if($RunSetup -and ( Read-PromptYesNo -Question "Run setup?" )){
        Write-Host -ForegroundColor Green "Configure PowerShell-GPT"    
        # create the config dir if not exists.
        if(-not (Test-Path $Global:Config.ConfigPath )) { 
            Write-Host -ForegroundColor Green "Creating configuration dir $($Global:Config.ConfigPath)"    
            New-Item -ItemType Directory -Path $Global:Config.ConfigPath 
        }
        # End script here if dir still not available.
        if( -not (Test-Path $Global:Config.ConfigPath ) ) {
            Write-Error "ConfigPath not found $($Global:Config.ConfigPath)"
            Get-Error
            exit
        }
        # GET API_KEY
        if( ($Global:Config.API_KEY.Length -gt 49 ) ){
            Write-Host -ForegroundColor Green "Current API Key: " -NoNewline
            Write-Host -ForegroundColor Cyan "$($Global:Config.API_KEY)"
            Write-Host -ForegroundColor Green "Enter New API Key or press <Enter> to accept current."
        } else{
            Write-Host -ForegroundColor Green "Enter OpenAI API Key"
        }
        $api_key = Read-Host "OpenAI API Key>"
        if (-not ([string]::IsNullOrWhiteSpace($api_key ))) { 
           $Global:Config.API_KEY = $api_key 
        } 

        # SET SYSTEM MSG - A set of customizable instructions or addtional info for the bot 
        Write-Host -ForegroundColor Green "Current System Message: " -NoNewline
        Write-Host -ForegroundColor Cyan "$($Global:Config.system_msg)"
        Write-Host -ForegroundColor Green "Enter New system message or press <Enter> to accept current"
        $system_msg = Read-Host "system message>"
        if (-not ([string]::IsNullOrWhiteSpace($system_msg))) { 
           $Global:Config.system_msg = $system_msg  
        }
        
        # Enable Debugging
        If (-not [bool]($LoadedConfig.PSobject.Properties.name -match "Debugging")){
            Add-Member -force -InputObject $Global:Config -NotePropertyName Debugging -NotePropertyValue $False
        }# Test if config has Debugging property and if not add it. #bugfix in V.0.5.3
        Write-Host -ForegroundColor Green "Enable Debug messages: " -NoNewline
        If(Read-PromptYesNo -Question "?"){
            $Global:Config.Debugging = $true            
        }else {
            $Global:Config.Debugging = $false
        }

        Write-Host -ForegroundColor Green "Use Default Model: $($Global:Models[0])" -NoNewline
        If(Read-PromptYesNo -Question ""){
            $Global:Config.model = $Global:Models[0]
        }else {
            [int]$UserChoice = Read-Menu -options $Global:Models
            $Global:Config.model = $Global:Models[$UserChoice]
        }

        Write-host -ForegroundColor Cyan "
        API_KEY    : $($Global:Config.API_KEY)
        Endpoint   : $($Global:Config.endpoint)
        Model      : $($Global:Config.model)
        ConfigPath : $($Global:Config.ConfigPath)
        ConfigFile : $($Global:Config.ConfigFile)
        System_Msg : $($Global:Config.system_msg)
        Debugging  : $($Global:Config.Debugging)
        AppVersion : $($Global:Config.AppVersion)
        "
        Write-Host -ForegroundColor Green "Write Configuration to $($Global:Config.ConfigFile) ?"
        if(Read-PromptYesNo -Question "Write config?"){
            Set-Content -Path $Global:Config.ConfigFile -Value ($Global:Config | ConvertTo-Json -EscapeHandling EscapeNonAscii )
        }
    } 
}

Function Start-PowerShellGPTSetup{
    Set-PwshGPTConfig -RunSetup $true
}

Function Read-Config(){
    # Run setup if no config file found
    if ( ($null -eq $Global:Config.ConfigFile) -or (-not (Test-Path $Global:Config.ConfigFile))  ) {
        Set-PwshGPTConfig
    }

    # Read config json into global:config obj
    #$Global:Config = (Get-Content $Global:Config.ConfigFile | ConvertFrom-Json )
    
    $LoadedConfig = (Get-Content $Global:Config.ConfigFile | ConvertFrom-Json )
    
    If( (-not [bool]($LoadedConfig.PSobject.Properties.name -match "AppVersion")) -or ($LoadedConfig.AppVersion -ne $Global:Config.AppVersion) ){
        Write-Host -ForegroundColor DarkMagenta `
        "AppVersion $($Global:Config.AppVersion) does not match value in config file
         $($Global:Config.ConfigFile)
         Running setup to upgrade config"
         Add-Member -force -InputObject $Global:Config -NotePropertyName AppVersion -NotePropertyValue $Global:Config.AppVersion
         Start-PowerShellGPTSetup
    } else{
        $Global:Config = $LoadedConfig
    }

    If($null -eq $Global:Config) {
        Write-Host -ForegroundColor Red "ERROR. Config not loaded. Exiting."
        Exit 1
    }
    # test loading API key as go / no-go
    If( ($null -eq $Global:Config.API_KEY )){
        Write-Host -ForegroundColor Red "No valid API key loaded. Exiting."
        Exit
    }

    # Setup Messages Array
    # Format of a user message is [{"role": "user", "content": "Hello! My name is Ross."}]
    # Format of a response is [{"role": "assistant", "content": "Hello Ross, I am ChatGPT."}]
    # Format of a system message [{"role": "system", "content": "You are my helpful assistant."}]
    # ---
    $global:Session = New-Object -TypeName PSObject -Property @{
        Messages = New-Object -TypeName System.Collections.ArrayList
        Tokens   = 0
    }

   # $global:Session.Messages = New-Object System.Collections.ArrayList  # Global messages array variable.
    $global:Session.Messages += @{ # Inital system message to set the tone of the conversation. Tweak to your liking
        role="system"
        content = "$($Global:Config.system_msg)"
    }

}

