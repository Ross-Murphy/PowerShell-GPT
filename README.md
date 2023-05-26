# PowerShell-GPT - an OpenAI Chat for PowerShell. v0.2
a simple GPT backed chat bot for PowerShell.
MIT License 
https://github.com/Ross-Murphy/PowerShell-GPT

### Questions.

What is this?
---
This started off as a way to have a simple coding and virtual assistant inside VSCode or in my other PowerShell task windows. 
I did not initially find an extension for VsCode to my liking. Also I thought it would be fun to code something like this. 

What's Next
---
There are several other PowerShell GPT API scripts out there and honestly if I had found them first I may not have started this at all. I've not looked at them in depth and I may like to borrow some of their ideas.
I would like to add some ability for the chat to interact with the shell in a limited capacity. 


### Examples
Great for generating boilerplate code or getting started on something.
---
![Example Chat ](images/Example1.PNG)

Single and multiline support.
![Example of Multiline Input](images/ExampleMulti.PNG)

Very Handy in the terminal window in VsCode.
![Very handy in vscode](images/vscode.PNG)



How to use ?
---
In this example you can add it to your profile and use it in VsCode

In vscode PS terminal window 
`code $PROFILE`

add the following adjusting for your own path to your Api key and location where you git cloned the repo.
```powershell

# Load OpenAI
$Env:API_KEY = Get-Content $HOME\.tokens\openai.private 
.C:\Operations\DEV\PowerShell-GPT\ask_a_bot.ps1

```

Or run it from the repo directory.
```
PS C:\DEV\PowerShell-GPT> . .\ask_a_bot.ps1
PS C:\\DEV\PowerShell-GPT> start-chat

You are now chatting with gpt-3.5-turbo
    Type your chat message and hit <enter> to send.
    Or choose a command from the menu.

    Name                        Command             Description
    ==================================================================================
    Close Chat:                 Quit() or Exit()    End chat session. Alias Q()
    Multiline input mode:       Multi()             Multiline text entry mode, Use Dot-escape to exit .<enter>
    Save/Export Current Chat:   Save() or S()       Export Contents of current chat messages to $Env:GPT_CHAT_MESSAGES
    Import Saved Chat:          Import()            Get $Env:GPT_CHAT_MESSAGES array and append it to the current messages array
    Reset Chat Session:         Reset()             Clear messages array. Start fresh chat.
    History:                    History()           Display Chat History. See the content of the current messages array.
    Help:                       Help()              Display this menu


: Good Day.         
Good day, Sir. How may I be of assistance to you?

: quit()

```

### Reference Material
https://platform.openai.com/docs/api-reference
