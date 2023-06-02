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
}
# Set some defaults
$Config.ConfigPath = Join-Path -Path $USERHOME -ChildPath '.PowerShell-GPT' # Location of config dir
$Config.ConfigFile = Join-Path -Path $Config.ConfigPath -ChildPath 'PowerShell-GPT_config.json' # Default name of the config file.
$Config.endpoint = 'https://api.openai.com/v1/chat/completions' # The OpenAI endpoint for chat/completions
$Config.model = 'gpt-3.5-turbo' # Default The Large Lang Model to use.
$Config.system_msg = "You are my helpful assistant. Please be brief." # Default system message. Can be configured during setup.

Function invoke-Bot { # Send current prompt and an array with messages history to API.
    param(
    [Parameter()][string]$api_key = $Global:Config.API_KEY,
    [Parameter()][string]$endpoint = $Global:Config.endpoint,
    [Parameter()][string]$model = $Global:Config.model,
    [Parameter()][array]$messages = $Global:messages,
    [Parameter(Mandatory=$true)][string]$prompt
    )
    if ($null -eq $api_key){return $false}
    if ($null -eq $endpoint){return $false}
    if ($null -eq $model){return $false}

    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $api_key"
    }

    $global:messages += @{ 
        role = 'user' 
        content = "$prompt" 
    }
    
    $body = @{
        messages = $global:messages
        model = "$model"       
    } | ConvertTo-Json
   
    try {
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body $body 
    }
    catch {
        Write-Host -ForegroundColor Red "Invoke-RestMethod - An error occurred: $($_.Exception.Message)"
        return $false
    }
    
    $bot_reply = ($response.choices[0].message )
    return ($bot_reply |Write-Output)
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
Function Start-Chat(){
    param(
        [parameter()][array]$messages = $global:messages,
        [parameter()][string]$Question = "`n" 
    )
    $model = $Global:Config.model
    Read-Config

    $command_menu = "
You are now chatting with $model
    Type your chat message and hit <enter> to send. 
    Or choose a command from the menu.
==================================================================================
Name                        Command             Description
==================================================================================
Close Chat:                 Quit() or Exit()    End chat session. Alias Q()
Multiline input mode:       Multi()             Multiline text entry mode, Use Dot-escape to exit .<enter> 
Save/Export Current Chat:   Save() or S()       Export Contents of current chat messages to `$Env:GPT_CHAT_MESSAGES 
Import Saved Chat:          Import()            Get `$Env:GPT_CHAT_MESSAGES & append to current messages array.
Reset Chat Session:         Reset()             Clear messages array. Start fresh chat.
History:                    History()           Display Chat History. See Content of current messages array.
Config:                     Conf()              Display Current Configuration.
Setup:                      Setup()             Set API-Key, Modify system_msg, Inital Instructions to the model.
Help:                       Help()              Display this help menu.
    "
    Write-Host -ForegroundColor DarkMagenta $command_menu
    $Check = $false
    while($Check -eq $false){
        Switch -Regex (Read-Host -Prompt "$Question"){
            {'Quit()', 'Exit()', 'Q()' -contains $_ } {
                $Check = $true
            }
            {'Multi()', 'M()' -contains $_ } {
                Write-Host -ForegroundColor DarkMagenta "Multi Line Input. Empty line with . to end "
                [string]$MultiLineInput = Get-MultiLineInput
                $response = invoke-Bot -prompt "$MultiLineInput" -messages $global:messages # Send Current prompt and $messages history
                if($response){
                    $global:messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                } 
            }
            {'History()' -contains $_ } {
                Write-Host -ForegroundColor Cyan  ( $global:messages|ConvertTo-Json)  # write out chat history as json
           }
            {'Save()', 'S()' -contains $_ } { # json export chat history and display it 
                 $Env:GPT_CHAT_MESSAGES = $global:messages|ConvertTo-Json
                 Write-Host -ForegroundColor DarkCyan $Env:GPT_CHAT_MESSAGES  
            }
            {'Import()' -contains $_ } { # check $Env:GPT_CHAT_MESSAGES and see if it has an array and try to load it.
                #$Env:GPT_CHAT_MESSAGES = $global:messages|ConvertTo-Json
                $import_last = ($Env:GPT_CHAT_MESSAGES | ConvertFrom-Json) # prehaps some more checks here...
                if ( $import_last -is [array]){
                    $global:messages += $import_last
                }               
                Write-Host -ForegroundColor DarkCyan "Imported:`n$($Env:GPT_CHAT_MESSAGES)"
           }
           {'Clear()' -contains $_ } { # Clear export var 
                $Env:GPT_CHAT_MESSAGES = ""
           }
           {'Reset()' -contains $_ } { # Delete Current Chat History. Start over but don't exit. You can import saved chats
                $global:messages = @($global:messages[0]) # Keep only the inital system prompt
                $response = invoke-Bot -prompt "Ready?" -messages $global:messages # 
                if($response){
                    $global:messages += $response # add the response hash table to the global messages array
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
                $response = invoke-Bot -prompt "$_" -messages $global:messages  # Send Current prompt and $messages history
                if($response){
                    $global:messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                }               
            }
        }
    }
} 
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
}  # Promt for yes/no | y/n and return true/false

Function Set-PwshGPTConfig{
    param(
        [Parameter()][bool]$RunSetup = $false  
    )

    if( -not (Test-Path -Path $Global:Config.ConfigFile)){
        Write-Host -ForegroundColor Magenta "Config File not found $($Global:Config.ConfigFile)"
        $RunSetup = $true    
    } 

    if($RunSetup -and ( Read-PromptYesNo -Question "Run setup?" )){
        Write-Host -ForegroundColor Green "Creating configuration"
        # create the config dir if not exists.
        if(-not (Test-Path $Global:Config.ConfigPath )) { New-Item -ItemType Directory -Path $Global:Config.ConfigPath }
        # End script here if dir still not available.
        if( -not (Test-Path $Global:Config.ConfigPath ) ) {
            Write-Error "ConfigPath not found $($Global:Config.ConfigPath)"
            Get-Error
            exit
        }
        # GET API_KEY
        $Global:Config.API_KEY = Read-Host "Enter your API KEY"
        # SET SYSTEM MSG - A set of customizable instructions or addtional info for the bot 
        Write-Host -ForegroundColor Green "Current System Message:"
        Write-Host -ForegroundColor Cyan "$($Global:Config.system_msg)"
        Write-Host -ForegroundColor Green "Enter New system message or press <Enter> to accept current"
        $system_msg = Read-Host "system message>"
        if (-not ([string]::IsNullOrWhiteSpace($system_msg))) { 
           $Global:Config.system_msg = $system_msg  
        }
        Write-host -ForegroundColor Cyan "
        API_KEY    : $($Global:Config.API_KEY)
        Endpoint   : $($Global:Config.endpoint)
        Model      : $($Global:Config.model)
        ConfigPath : $($Global:Config.ConfigPath)
        ConfigFile : $($Global:Config.ConfigFile)
        System_Msg : $($Global:Config.system_msg)
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
    $Global:Config = (Get-Content $Global:Config.ConfigFile | ConvertFrom-Json )
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
    $global:messages = New-Object System.Collections.ArrayList  # Global messages array variable.
    $global:messages += @{ # Inital system message to set the tone of the conversation. Tweak to your liking
        role="system"
        content = "$($Global:Config.system_msg)"
    }

}

