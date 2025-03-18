<#
.SYNOPSIS
    PowerShell-GPT is a module for interacting with OpenAI's GPT models directly from PowerShell.

.DESCRIPTION
    This module allows users to communicate with OpenAI's GPT models through the chat completions API.
    It provides a command-line interface for users to send prompts, receive responses, 
    and manage conversation history. The module supports multiple chat functions and configurable options.

    Key features include:
    - Sending prompts to the OpenAI API and receiving text responses.
    - Multi-line input mode for complex queries.
    - History management for saving and loading chat sessions.
    - Easy configuration setup for API keys, model selection, and debugging options.

.PARAMETER API_KEY
    The API key used for authentication with the OpenAI API. This must be set for the module to function.

.PARAMETER ENDPOINT
    The URL endpoint for accessing the OpenAI chat completions API. Defaults to 'https://api.openai.com/v1/chat/completions'.

.PARAMETER MODEL
    The default model to use for generating responses. Can be configured to use different model types provided by OpenAI.

.NOTES
    Author: Ross Murphy
    License: MIT License
    GitHub: https://github.com/Ross-Murphy/PowerShell-GPT
    OpenAI API Documentation: https://platform.openai.com/docs/api-reference

.EXAMPLES
    # To start a chat session:
    Start-Chat

    # To show the module help:
    Get-Help PowerShell-GPT -Full
    or
    Get-Help Start-Chat -Full
#>

# Cross-platform home directory
$Script:USERHOME = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)

# Create Object to hold config
$Script:Config = [PSCustomObject] @{
    API_KEY = ''
    endpoint = ""
    model = ""
    system_msg = ""
    ConfigPath = ""
    ConfigFile = ""
    Debugging = ""
    AppVersion = ""
}
$Script:Models = @(
    'gpt-4o-mini', # Default The Large Lang Model to use.
    'gpt-4o',
    'o1',
    'o3-mini'

)

# Set some defaults
$Config.ConfigPath = Join-Path -Path $USERHOME -ChildPath '.PowerShell-GPT' # Location of config dir
$Config.ConfigFile = Join-Path -Path $Config.ConfigPath -ChildPath 'PowerShell-GPT_config.json' # Default name of the config file.
$Config.endpoint = 'https://api.openai.com/v1/chat/completions' # The OpenAI endpoint for chat/completions
$Config.model = $Script:Models[0] # Default The Large Lang Model to use.
$Config.system_msg = "You are my helpful assistant. Please be brief." # Default system message. Can be configured during setup.
$Config.Debugging = '0' # Enable more verbose output for troubleshooting. Token counting.
$Config.AppVersion = '0.5.5' # Current module version

# --- Functions --- 
Function invoke-Bot { # Send current prompt and an array with messages history to API.
    param(
    [Parameter()][string]$api_key = $Script:Config.API_KEY,
    [Parameter()][string]$endpoint = $Script:Config.endpoint,
    [Parameter()][string]$model = $Script:Config.model,
    [Parameter()][array]$messages = $Script:Session.Messages,
    [Parameter()][string]$prompt
    )
    
<#
    .SYNOPSIS
        Sends a prompt and message history to the OpenAI API and returns the response.

    .DESCRIPTION
        The invoke-Bot function sends the current prompt and an array with message history to the OpenAI API.
        It formats the request according to the OpenAI Chat API requirements, sends the request, and returns the response.

    .PARAMETER api_key
        The OpenAI API key used for authentication. Defaults to the value in $Script:Config.API_KEY.

    .PARAMETER endpoint
        The OpenAI API endpoint URL. Defaults to the value in $Script:Config.endpoint.

    .PARAMETER model
        The OpenAI model to use for generating responses. Defaults to the value in $Script:Config.model.

    .PARAMETER messages
        An array of message objects representing the conversation history. Defaults to $Script:Session.Messages.

    .PARAMETER prompt
        The current user prompt to send to the API.

    .OUTPUTS
        Returns the bot's reply as a PSObject containing role and content properties, or $false if the request fails.

    .NOTES
        This function requires a valid OpenAI API key to function properly.
#>
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
    } | ConvertTo-Json -EscapeHandling EscapeNonAscii -Depth 10
   
    try {
        if ($Script:Config.Debugging){Write-Host -ForegroundColor Cyan "$($body)"}
        $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method Post -Body $body 
        if ($Script:Config.Debugging){Write-Host -ForegroundColor Cyan "$($response.content)"}
    }
    catch {
        Write-Host -ForegroundColor Red "Invoke-RestMethod - An error occurred: $($_.Exception.Message)"
        if ($Script:Config.Debugging){Write-Host -ForegroundColor Cyan "$($body)"}
        return $false
    }
    
    $bot_reply = ($response.choices[0].message )
    $Script:Session.Tokens = ($response.usage.total_tokens )
    return ($bot_reply |Write-Output)
}


Function Get-MultiLineInput { # Dot-escape to exit.  ".<enter> " 
    <#
    .SYNOPSIS
        Collects multi-line input from the user.

    .DESCRIPTION
        The Get-MultiLineInput function allows users to enter multiple lines of text.
        Input collection continues until the user enters a single dot ('.') on a line by itself.

    .OUTPUTS
        Returns a string containing all the input lines joined with newline characters.

    .NOTES
        To exit multi-line input mode, type a single dot ('.') on a line by itself and press Enter.
        Empty lines are preserved in the output.
    #>
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
        <#
    .SYNOPSIS
        Displays a menu of options and returns the user's selection.

    .DESCRIPTION
        The Read-Menu function generates a numbered menu from an array of options,
        prompts the user to make a selection, and returns the index of the selected option.
        The function validates user input and ensures it corresponds to a valid menu option.

    .PARAMETER Options
        An array of strings representing the menu options to display.

    .PARAMETER PromptText
        A string containing the text to display above the menu options.

    .OUTPUTS
        Returns the zero-based index of the selected option in the Options array,
        or $false if the user selects the cancel option (0).

    .NOTES
        Menu options are numbered starting from 1, but the function returns a zero-based index.
        Option 0 is always reserved for "Cancel" and returns $false.
    #>
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
    <#
        .SYNOPSIS
            Prompts the user for a yes/no response.

        .DESCRIPTION
            The Read-PromptYesNo function displays a question to the user and waits for a yes/no response.
            It accepts various forms of "yes" (y, yes) and "no" (n, no) responses, case-insensitive.
            The function continues to prompt until a valid response is received.

        .PARAMETER Question
            The question to display to the user.

        .OUTPUTS
            Returns $true for a "yes" response or $false for a "no" response.

        .EXAMPLE
            if(Read-PromptYesNo -Question "Do you want to continue?") {
                # Code to execute if user answers yes
            }
    #>
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

<#
    .SYNOPSIS
        Starts an interactive chat session with the OpenAI API.

    .DESCRIPTION
        The Start-Chat function initiates the main chat loop that handles user input and displays AI responses.
        It processes special commands for managing the chat session and sends regular input to the OpenAI API.
        The function maintains conversation history and handles token usage tracking.

    .PARAMETER messages
        An array of message objects representing the conversation history. Defaults to $Script:Session.Messages.

    .PARAMETER Question
        The prompt text to display when requesting user input. Defaults to a newline character.

    .NOTES
        This function supports various commands for managing the chat session:
        - Quit(), q, Exit() - Exit the chat loop
        - Q() - Quit but save chat history to environment variable
        - Multi(), M() - Enter multiline input mode
        - History() - Display chat history as JSON
        - Save(), S() - Export chat history to environment variable
        - Import(), I() - Import chat history from environment variable
        - Clear() - Clear exported chat history
        - Reset() - Delete current chat history and start over
        - Conf() - Show current configuration
        - Setup() - Configure settings
        - Help() - Show command menu options
#>
Function Start-Chat(){ # This is the main chat loop. It runs and watches input for run commands.
    param(
        [parameter()][array]$messages = $Script:Session.Messages,
        [parameter()][string]$Question = "`n" 
    )
    Read-Config # Read Json Configuration.
    Write-Host -ForegroundColor DarkMagenta (Get-CommandMenu) # Display the Command menu
    
    ### START input loop
    $Check = $false # When Check = $true the input loop will exit. 
    while($Check -eq $false){
        if ($Script:Config.Debugging){Write-Host -ForegroundColor Yellow "Current tokens $($Session.Tokens)"}
        # We use switch cases to give the chat admin commands.
        Switch -Regex (Read-Host -Prompt "$Question"){
            {'Quit()','q', 'Exit()' -contains $_ } { # Exit the chat loop
                $Check = $true
            }
            {'Q()' -contains $_ } { # Quit but save chat history to environment variable. 
                $Env:GPT_CHAT_MESSAGES = $Script:Session.Messages|ConvertTo-Json
                $Check = $true
            }
            {'Multi()', 'M()' -contains $_ } { # Enter multiline input mode.
                Write-Host -ForegroundColor DarkMagenta "Multi Line Input. Empty line with . to end "
                [string]$MultiLineInput = Get-MultiLineInput
                $response = invoke-Bot -prompt "$MultiLineInput" -messages $Script:Session.Messages # Send Current prompt and $messages history
                if($response){
                    # if a valid response is recieved we add the multiline prompt to the messages array.
                    $Script:Session.Messages += @{ 
                        role = 'user' 
                        content = "$MultiLineInput" 
                    }
                    $Script:Session.Messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                } 
            }
            {'History()' -contains $_ } { # write out chat history as json
                Write-Host -ForegroundColor Cyan  ( $Script:Session.Messages|ConvertTo-Json)  
           }
            {'Save()', 'S()' -contains $_ } { # json export chat history and display it 
                 $Env:GPT_CHAT_MESSAGES = $Script:Session.Messages|ConvertTo-Json
                 Write-Host -ForegroundColor DarkCyan $Env:GPT_CHAT_MESSAGES  
            }
            {'Import()', 'I()' -contains $_ } { # check $Env:GPT_CHAT_MESSAGES and see if it has an array and try to load it.
                #$Env:GPT_CHAT_MESSAGES = $Script:Session.Messages|ConvertTo-Json
                $import_last = ($Env:GPT_CHAT_MESSAGES | ConvertFrom-Json -Depth 10) # prehaps some more checks here...
                if ( $import_last -is [array]){
                    $Script:Session.Messages += $import_last
                }               
                Write-Host -ForegroundColor DarkCyan "Imported:`n$($Env:GPT_CHAT_MESSAGES)"
           }
           {'Clear()' -contains $_ } { # Clear export var 
                $Env:GPT_CHAT_MESSAGES = ""
           }
           {'Reset()' -contains $_ } { # Delete Current Chat History. Start over but don't exit. You can import saved chats
                $Script:Session.Messages = @($Script:Session.Messages[0]) # Keep only the inital system prompt
                $response = invoke-Bot -prompt "Ok?" -messages $Script:Session.Messages # 
                if($response){
                    $Script:Session.Messages += $response # add the response hash table to the global messages array
                    Write-Host -ForegroundColor Green $response.content  # display the response content to the console                  
                } else {
                    Write-Host -ForegroundColor DarkYellow "Warning. API Response is false."
                }              
           }
           {'Conf()' -contains $_ } { # Show current config
             Write-Host -ForegroundColor DarkMagenta "$(Get-Configuration)"
           }
           {'Setup()' -contains $_ } { # Setup config.
            Start-PowerShellGPTSetup
           }

           {'Help()' -contains $_ } { # Show command menu options
            Write-Host -ForegroundColor DarkMagenta (Get-CommandMenu)
           }
            default { # Regular single line chat input mode
                if ($_ -eq ''){ # Do not send a blank line to our butler. if someone just hits enter, send nothing.
                    continue
                }
                $response = invoke-Bot -prompt "$_" -messages $Script:Session.Messages  # Send Current prompt and $messages history
                if($response){
                    # With a valid reponse
                    $Script:Session.Messages += @{ # Format the user message and add to the message aray.
                        role = 'user' 
                        content = "$_" 
                    }
                    $Script:Session.Messages += $response # add the assistant response hash table to the global messages array
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
    <#
    .SYNOPSIS
        Configures the PowerShell-GPT module settings.

    .DESCRIPTION
        The Set-PwshGPTConfig function checks for an existing configuration file and runs the setup process if needed.
        It allows users to configure the OpenAI API key, system message, debugging options, and model selection.
        The function can write the configuration to a JSON file for persistence.

    .PARAMETER RunSetup
        A boolean value indicating whether to run the setup process regardless of whether a configuration file exists.
        Defaults to $false.

    .NOTES
        This function creates the configuration directory if it doesn't exist.
        The configuration is stored in a JSON file at the path specified in $Script:Config.ConfigFile.
    #>
    if( -not (Test-Path -Path $Script:Config.ConfigFile)){
        Write-Host -ForegroundColor Magenta "Config File not found $($Script:Config.ConfigFile)"
        $RunSetup = $true    
    } 

    if($RunSetup -and ( Read-PromptYesNo -Question "Run setup?" )){
        Write-Host -ForegroundColor Green "Configure PowerShell-GPT"    
        # create the config dir if not exists.
        if(-not (Test-Path $Script:Config.ConfigPath )) { 
            Write-Host -ForegroundColor Green "Creating configuration dir $($Script:Config.ConfigPath)"    
            New-Item -ItemType Directory -Path $Script:Config.ConfigPath 
        }
        # End script here if dir still not available.
        if( -not (Test-Path $Script:Config.ConfigPath ) ) {
            Write-Error "ConfigPath not found $($Script:Config.ConfigPath)"
            Get-Error
            exit
        }
        # GET API_KEY
        if( ($Script:Config.API_KEY.Length -gt 49 ) ){
            $apiKey = $Script:Config.API_KEY
            $firstPart = $apiKey.Substring(0, 15)  # First 15 characters
            $lastPart = $apiKey.Substring($apiKey.Length - 15)  # Last 15 characters
            #$middleObfuscated = '*' * ($apiKey.Length - 24)  # Obfuscate the middle part
            $middleObfuscated = '...***Obfuscated***...' # Obfuscate and trim the middle part
            $displayKey = $firstPart + $middleObfuscated + $lastPart    
            Write-Host -ForegroundColor Green "Current API Key: " -NoNewline
            Write-Host -ForegroundColor Cyan "$($displayKey)"
            Write-Host -ForegroundColor Green "Enter New API Key or press <Enter> to accept current."
        } else{
            Write-Host -ForegroundColor Green "Enter OpenAI API Key"
        }
        $api_key = Read-Host "OpenAI API Key>"
        if (-not ([string]::IsNullOrWhiteSpace($api_key ))) { 
           $Script:Config.API_KEY = $api_key 
        } 

        # SET SYSTEM MSG - A set of customizable instructions or addtional info for the bot 
        Write-Host -ForegroundColor Green "Current System Message: " -NoNewline
        Write-Host -ForegroundColor Cyan "$($Script:Config.system_msg)"
        Write-Host -ForegroundColor Green "Enter New system message or press <Enter> to accept current"
        $system_msg = Read-Host "system message>"
        if (-not ([string]::IsNullOrWhiteSpace($system_msg))) { 
           $Script:Config.system_msg = $system_msg  
        }
        
        # Enable Debugging
        If (-not [bool]($LoadedConfig.PSobject.Properties.name -match "Debugging")){
            Add-Member -force -InputObject $Script:Config -NotePropertyName Debugging -NotePropertyValue $False
        }# Test if config has Debugging property and if not add it. #bugfix in V.0.5.3
        Write-Host -ForegroundColor Green "Enable Debug messages: " -NoNewline
        If(Read-PromptYesNo -Question "?"){
            $Script:Config.Debugging = $true            
        }else {
            $Script:Config.Debugging = $false
        }

        Write-Host -ForegroundColor Green "Use Default Model: $($Script:Models[0])" -NoNewline
        If(Read-PromptYesNo -Question ""){
            $Script:Config.model = $Script:Models[0]
        }else {
            [int]$UserChoice = Read-Menu -options $Script:Models
            $Script:Config.model = $Script:Models[$UserChoice]
        }

        Write-host -ForegroundColor Cyan "
        API_KEY    : $($displayKey)
        Endpoint   : $($Script:Config.endpoint)
        Model      : $($Script:Config.model)
        ConfigPath : $($Script:Config.ConfigPath)
        ConfigFile : $($Script:Config.ConfigFile)
        System_Msg : $($Script:Config.system_msg)
        Debugging  : $($Script:Config.Debugging)
        AppVersion : $($Script:Config.AppVersion)
        "
        Write-Host -ForegroundColor Green "Write Configuration to $($Script:Config.ConfigFile) ?"
        if(Read-PromptYesNo -Question "Write config?"){
            Set-Content -Path $Script:Config.ConfigFile -Value ($Script:Config | ConvertTo-Json -EscapeHandling EscapeNonAscii )
        }
    } 
}

Function Start-PowerShellGPTSetup{
    <#
    .SYNOPSIS
        Initiates the PowerShell-GPT setup process.

    .DESCRIPTION
        The Start-PowerShellGPTSetup function is a wrapper that calls Set-PwshGPTConfig with the RunSetup parameter set to $true,
        forcing the configuration setup process to run.

    .NOTES
        This function is typically used when the user wants to reconfigure the module settings.
    #>
    Set-PwshGPTConfig -RunSetup $true
}


Function Read-Config(){
        <#
    .SYNOPSIS
        Reads and processes the PowerShell-GPT configuration.

    .DESCRIPTION
        The Read-Config function checks for the existence of a configuration file and runs setup if needed.
        It loads the configuration from the JSON file, validates it, and initializes the session with the system message.
        The function also handles version checking and upgrades.

    .OUTPUTS
        No direct output, but initializes the $Script:Config and $Script:Session objects with configuration values.

    .NOTES
        This function is called at the start of a chat session to ensure proper configuration.
        It will exit the script if no valid API key is found.
    #>
    # Run setup if no config file found
    if ( ($null -eq $Script:Config.ConfigFile) -or (-not (Test-Path $Script:Config.ConfigFile))  ) {
        Set-PwshGPTConfig
    }

    # Read config json into global:config obj
    #$Script:Config = (Get-Content $Script:Config.ConfigFile | ConvertFrom-Json )
    
    $LoadedConfig = (Get-Content $Script:Config.ConfigFile | ConvertFrom-Json )
    
    If( (-not [bool]($LoadedConfig.PSobject.Properties.name -match "AppVersion")) -or ($LoadedConfig.AppVersion -ne $Script:Config.AppVersion) ){
        Write-Host -ForegroundColor DarkMagenta `
        "AppVersion $($Script:Config.AppVersion) does not match value in config file
         $($Script:Config.ConfigFile)
         Running setup to upgrade config"
         Add-Member -force -InputObject $Script:Config -NotePropertyName AppVersion -NotePropertyValue $Script:Config.AppVersion
         Start-PowerShellGPTSetup
    } else{
        $Script:Config = $LoadedConfig
    }

    If($null -eq $Script:Config) {
        Write-Host -ForegroundColor Red "ERROR. Config not loaded. Exiting."
        Exit 1
    }
    # test loading API key as go / no-go
    If( ($null -eq $Script:Config.API_KEY )){
        Write-Host -ForegroundColor Red "No valid API key loaded. Exiting."
        Exit
    }

    # Setup Messages Array
    # Format of a user message is [{"role": "user", "content": "Hello! My name is Ross."}]
    # Format of a response is [{"role": "assistant", "content": "Hello Ross, I am ChatGPT."}]
    # Format of a system message [{"role": "system", "content": "You are my helpful assistant."}]
    # ---
    $Script:Session = New-Object -TypeName PSObject -Property @{
        Messages = New-Object -TypeName System.Collections.ArrayList
        Tokens   = 0
    }

   # $Script:Session.Messages = New-Object System.Collections.ArrayList  # Global messages array variable.
    $Script:Session.Messages += @{ # Inital system message to set the tone of the conversation. Tweak to your liking
        role="system"
        content = "$($Script:Config.system_msg)"
    }

}


Function Get-ObfuscatedKey{
    param(
        [parameter()][string]$apiKey =  $Script:Config.API_KEY 
    )
    <#
    .SYNOPSIS
        Creates an obfuscated version of the API key for display purposes.

    .DESCRIPTION
        The Get-ObfuscatedKey function takes an API key and returns a partially obfuscated version
        that shows only the first and last 15 characters, with the middle portion replaced by a placeholder.
        This allows displaying the key in logs or UI without exposing the full key.

    .PARAMETER apiKey
        The API key to obfuscate. Defaults to $Script:Config.API_KEY.

    .OUTPUTS
        Returns a string containing the obfuscated API key.

    .EXAMPLE
        $displayKey = Get-ObfuscatedKey
        Write-Host "Using API key: $displayKey"
    #>
    $firstPart = $apiKey.Substring(0, 15)  # First 15 characters
    $lastPart = $apiKey.Substring($apiKey.Length - 15)  # Last 15 characters
    #$middleObfuscated = '*' * ($apiKey.Length - 24)  # Obfuscate the middle part
    $middleObfuscated = '...***Obfuscated***...' # Obfuscate and trim the middle part
    $displayKey = $firstPart + $middleObfuscated + $lastPart
    return $displayKey
}


Function Get-Configuration{
        <#
    .SYNOPSIS
        Returns a formatted string containing the current configuration.

    .DESCRIPTION
        The Get-Configuration function creates a formatted string that displays all the current
        configuration settings of the PowerShell-GPT module, including the obfuscated API key,
        endpoint, model, file paths, system message, debugging status, and application version.

    .OUTPUTS
        Returns a string containing the formatted configuration information.

    .EXAMPLE
        Write-Host (Get-Configuration)
    #>
    [string]$ObfuscatedKey = Get-ObfuscatedKey
    [string]$output =  "
    API_KEY    : $($ObfuscatedKey)
    Endpoint   : $($Script:Config.endpoint)
    Model      : $($Script:Config.model)
    ConfigPath : $($Script:Config.ConfigPath)
    ConfigFile : $($Script:Config.ConfigFile)
    System_Msg : $($Script:Config.system_msg)
    Debugging  : $($Script:Config.Debugging)
    AppVersion : $($Script:Config.AppVersion)
"

    return $output
}


Function Get-CommandMenu{
    <#
    .SYNOPSIS
        Returns a formatted string containing the command menu.

    .DESCRIPTION
        The Get-CommandMenu function creates a formatted string that displays all available
        commands and their descriptions for the PowerShell-GPT chat interface.
        This menu is shown to users to help them navigate the chat functionality.

    .OUTPUTS
        Returns a string containing the formatted command menu.

    .EXAMPLE
        Write-Host (Get-CommandMenu)
    #>
    $command_menu = "
    You are now chatting with $($Script:Config.model).  Type your chat message and hit <enter> to send. 
    Or choose a command from the menu.
---    
GPT-PowerShell Version: $($Script:Config.AppVersion)
==================================================================================
Name                        Command             Description 
==================================================================================
Close Chat:                 Quit() or Exit()    End chat session. Alias Q is quick exit. Alias Q() is Save and Quit.
Multiline input mode:       Multi() or M()      Multiline text entry mode, Use Dot-escape to exit .<enter> 
Save/Export Current Chat:   Save() or S()       Export Contents of current chat messages to `$Env:GPT_CHAT_MESSAGES 
Import Saved Chat:          Import() or I()     Import content of `$Env:GPT_CHAT_MESSAGES & append to current messages array.
Reset Chat Session:         Reset()             Clear messages array. Start fresh chat.
History:                    History()           Display Chat History. See Content of current messages array.
Config:                     Conf()              Display Current Configuration.
Setup:                      Setup()             Setup  config options. API-Key, system_msg, model context, debug msg
Help:                       Help()              Display this help menu.
    "
    return $command_menu
}

Export-ModuleMember -Function Start-Chat