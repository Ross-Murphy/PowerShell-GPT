# PowerShell-GPT - an OpenAI Chat for PowerShell.
# https://github.com/Ross-Murphy/PowerShell-GPT
# MIT License
# https://platform.openai.com/docs/api-reference
#
$ConfigPath = Join-Path -Path $HOME -ChildPath '\.PowerShell-GPT\'
$ConfigFile = (Join-Path -Path $($ConfigPath) -ChildPath 'PowerShell-GPT_config.json')
$ApiKeyFile = (Join-Path -Path $($ConfigPath) -ChildPath 'openai.private' )

Function invoke-Bot { # Send current prompt and an array with messages history to API.
    param(
    [Parameter()][string]$api_key = $Global:api_key,
    [Parameter()][string]$endpoint = $Global:endpoint,
    [Parameter()][array]$messages = $Global:messages,
    [Parameter(Mandatory=$true)][string]$prompt
    )
    if ($null -eq $api_key){return $false}

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
    $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body $body 
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
Function Read-Prompt(){
    param(
        [parameter()][array]$messages = $global:messages,
        [parameter()][string]$Question = "`n" 
    )
    $command_menu = "You are now chatting with $model
    Type your chat message and hit <enter> to send. 
    Or choose a command from the menu.

    Name                        Command             Description
    ==================================================================================
    Close Chat:                 Quit() or Exit()    End chat session. Alias Q()
    Multiline input mode:       Multi()             Multiline text entry mode, Use Dot-escape to exit .<enter> 
    Save/Export Current Chat:   Save() or S()       Export Contents of current chat messages to `$Env:GPT_CHAT_MESSAGES 
    Import Saved Chat:          Import()            Get `$Env:GPT_CHAT_MESSAGES array and append it to the current messages array
    Reset Chat Session:         Reset()             Clear messages array. Start fresh chat.
    History:                    History()           Display Chat History. See the content of the current messages array.
    Help:                       Help()              Display this menu
    "
    Write-Host -ForegroundColor DarkMagenta $command_menu
    Read-Config 
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
                $global:messages += $response # add the response hash table to the global messages array
                Write-Host -ForegroundColor Green $response.content  # display the response content to the console                
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
           {'Help()' -contains $_ } { # Clear export var 
            Write-Host -ForegroundColor DarkMagenta $command_menu
           }
           {'Reset()' -contains $_ } { # Delete Current Chat History. Start over but don't exit. You can import saved chats
                $global:messages = @($global:messages[0]) # Keep only the inital system prompt
                $response = invoke-Bot -prompt "Ready?" -messages $global:messages # 
                $global:messages += $response # add the response hash table to the global messages array
                Write-Host -ForegroundColor Green $response.content  # display the response content to the console                
           }
            default { 
                if ($_ -eq ''){ # Do not send a blank line to our butler
                    continue
                }
                $response = invoke-Bot -prompt "$_" -messages $global:messages  # Send Current prompt and $messages history
                $global:messages += $response # add the response hash table to the global messages array
                Write-Host -ForegroundColor Green $response.content  # display the response content to the console                
            }
        }
    }
} 
Function Read-PromptYesNo([string]$Question){
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
    $RunSetup = $false
   
    if( -not (Test-Path -Path  $ApiKeyFile  )){
        Write-Host -ForegroundColor Magenta "API Key File not found $ApiKeyFile"
        $RunSetup = $true       
    }

    if( -not (Test-Path -Path $ConfigFile)){
        Write-Host -ForegroundColor Magenta "Config File not found $ConfigFile"
        $RunSetup = $true    
    } 

    if($RunSetup -and ( Read-PromptYesNo -Question "Run setup?" )){
        Write-Host -ForegroundColor Yellow "This is where we load stuff"
    } 


}

Function Read-Config(){
    # Run setup if no config file or API Key
    if ( (-not (Test-Path $ConfigFile) -or ( -not (Test-Path -Path $ApiKeyFile ))  ) ) {
        Set-PwshGPTConfig
        return 0
    } 
    # If the API key is not loaded and the file exists attempt to load the key
    if ( $null -eq $Env:OPENAI_API_KEY ){
        $Env:OPENAI_API_KEY = Get-Content $ApiKeyFile
        $Global:api_key = $Env:OPENAI_API_KEY
    } 

    
# You can set the API key as an environment var or however you like
# $Env:API_KEY = 'sk-OPEN-API-KEY'
$Global:api_key = $Env:API_KEY
# https://platform.openai.com/account/api-keys

# Set the API endpoint and headers
# https://platform.openai.com/docs/models/model-endpoint-compatibility
$Global:endpoint = "https://api.openai.com/v1/chat/completions" 
$Global:model = 'gpt-3.5-turbo' #  

# Setup Messages Array
$global:messages = New-Object System.Collections.ArrayList  # Global messages array variable.
$global:messages += @{ # Inital system message to set the tone of the conversation. Tweak to your liking
    role="system"
    content = "You are my helpful assistant. Please be brief. Address me as 'Sir', in the tone of a butler."
}
# Format of a user message is [{"role": "user", "content": "Hello! My name is Ross."}]
# Format of a response is [{"role": "assistant", "content": "Hello Ross, I am ChatGPT."}]
# Format of a system message [{"role": "system", "content": "You are my helpful assistant."}]
}

# Start Chat Prompt
# Read-Prompt
New-Alias  -Force -Name "Start-chat" -Value Read-Prompt
