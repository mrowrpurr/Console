scriptName __Console__ extends Quest hidden
{[INTERNAL] Allows Console to store persistent data and perform operations on Console open/close}

; Stores the currently installed version of Console
float property CurrentlyInstalledVersion auto

; The console height at the time the mod is loaded (recalculated on game save loads)
int property InitialConsoleHeight auto

; The console width at the time the mod is loaded (recalculated on game save loads)
int property InitialConsoleWidth auto

; The console X position at the time the mod is loaded (recalculated on game save loads)
int property InitialConsoleX auto

; The console Y position at the time the mod is loaded (recalculated on game save loads)
int property InitialConsoleY auto

; Adds to the Papyrus logs with the prefix [Console]
function Log(string text) global
    Debug.Trace("[Console] " + text)
endFunction

function LogCustomSwfRequiredError(string functionName) global
    Log(functionName + " could not be called. Requires Console's custom console.swf which is not currently installed. Note: it should be build-in to the primary distributed Console mod.")
endFunction

event OnInit()
    ; Set the currently installed version of this mod on first-time mod initialization
    CurrentlyInstalledVersion = Console.GetConsoleVersion()
    ResetData()
endEvent

; Helper to get an instance of __Console__ for use in the public Console interface
__Console__ function GetInstance() global
    return Game.GetFormFromFile(0x800, "Console.esp") as __Console__
endFunction

; Returns true if the currently console.swf used by the game is our customized version for Console
bool function GetIsConsoleConsoleInstalled() global
    return GetInstance().IsConsoleConsoleInstalled
endFunction

; Starts listening for custom commands (if not already)
; and registers the provided event name which will be
; invoked as an SKSE mod event.
;
; If not already listening, then custom console commands will be enabled.
; This disables built-in console command functionality.
function RegisterForCustomCommands(string eventName, bool enableCustomCommandsIfNotAlready = true)
    if GetRegisteredCustomCommandEventIndex(eventName) > -1
        Log("Custom Command Event '" + eventName + "' cannot be registered because it is already registered.")
        return
    endIf
    if RegisteredCustomCommandEvents
        RegisteredCustomCommandEvents = Utility.ResizeStringArray(RegisteredCustomCommandEvents, RegisteredCustomCommandEvents.Length + 1)
    else
        RegisteredCustomCommandEvents = new string[1]
    endIf
    RegisteredCustomCommandEvents[RegisteredCustomCommandEvents.Length - 1] = eventName
    if ! IsCustomConsoleCommandsEnabled
        if enableCustomCommandsIfNotAlready
            EnableCustomConsoleCommands()
        else
            Log("Custom Command Event '" + eventName + "' will never fire because custom commands are not enabled.")
        endIf
    endIf
endFunction

; Unregisters the provided event name from receiving
; custom console commands.
;
; If there are no other registered custom console command
; listeners, then custom console commands will be
; disabled (unless disableCustomCommandsIfLastEvent is set to false)
function UnregisterForCustomCommands(string eventName, bool disableCustomCommandsIfLastEvent = true)
    if ! RegisteredCustomCommandEvents
        Log("Custom Command Event '" + eventName + "' cannot be unregistered, there are no registered events.")
        return
    endIf
    int eventIndex = GetRegisteredCustomCommandEventIndex(eventName)
    if eventIndex == -1
        Log("Custom Command Event '" + eventName + "' cannot be unregistered, it is not currently registered.")
        return
    endIf
    if RegisteredCustomCommandEvents.Length == 1
        RegisteredCustomCommandEvents = None
        if disableCustomCommandsIfLastEvent
            DisableCustomConsoleCommands()
        endIf
    else
        string[] updatedArray = Utility.ResizeStringArray(RegisteredCustomCommandEvents, RegisteredCustomCommandEvents.Length - 1)
        int index = 0
        int updatedArrayIndex = 0
        while index < RegisteredCustomCommandEvents.Length
            if index != eventIndex
                updatedArray[updatedArrayIndex] = RegisteredCustomCommandEvents[index]
                updatedArrayIndex += 1
            endIf
            index += 1
        endWhile
        RegisteredCustomCommandEvents = updatedArray
    endIf
endFunction

; Get the index in the RegisteredCustomCommandEvents array of the provided event name
; Returns -1 if not found
int function GetRegisteredCustomCommandEventIndex(string eventName)
    int index = 0
    while index < RegisteredCustomCommandEvents.Length
        if RegisteredCustomCommandEvents[index] == eventName
            return index
        endIf
        index += 1
    endWhile
    return -1
endFunction

; Enables "custom console commands" functionality
function EnableCustomConsoleCommands()
    Console.DisableNativeEnterReturnKeyHandling()
    IsCustomConsoleCommandsEnabled = true
    RegisterForMenu(Console.GetMenuName())
endFunction

; Disables "custom console commands" functionality
function DisableCustomConsoleCommands()
    UnregisterForMenu(Console.GetMenuName())
    Console.EnableNativeEnterReturnKeyHandling()
    IsCustomConsoleCommandsEnabled = false
endFunction

event OnMenuOpen(string menuName)
    if menuName == Console.GetMenuName()
        RegisterForKey(ENTER_KEY)
        RegisterForKey(RETURN_KEY)
    endIf
endEvent

event OnMenuClose(string menuName)
    if menuName == Console.GetMenuName()
        UnregisterForKey(ENTER_KEY)
        UnregisterForKey(RETURN_KEY)
    endIf
endEvent

event OnKeyDown(int keyCode)
    if keyCode == ENTER_KEY || keyCode == RETURN_KEY
        if RegisteredCustomCommandEvents
            int index = 0
            while index < RegisteredCustomCommandEvents.Length
                string eventName = RegisteredCustomCommandEvents[index]
                string currentInputText
                if IsConsoleConsoleInstalled
                    currentInputText = Console.GetAndClearInputText()
                else
                    ; Hack for vanilla, get the last line from the Commands list
                    currentInputText = Console.GetMostRecentCommandHistoryItem()
                endIf
                SendModEvent(eventName, currentInputText, 0.0)
                index += 1
            endWhile
        endIf
    endIf
endEvent

; Called on initial mod load and player load games
function ResetData()
    ClearCache()
    SaveCurrentConsoleDimensions()
endFunction

function SaveCurrentConsoleDimensions()
    InitialConsoleWidth = Console.GetCurrentWidth()
    InitialConsoleHeight = Console.GetCurrentHeight()
    InitialConsoleX = Console.GetPositionX()
    InitialConsoleY = Console.GetPositionY()
endFunction

; Reset the caches of whether various things are installed
; Reset on original mod installation and then on player load game events
function ClearCache()
    __isConsoleConsoleInstalled = -1
    IsCustomConsoleCommandsEnabled = false
    InitialConsoleWidth = -1
    InitialConsoleHeight = -1
    InitialConsoleX = -1
    InitialConsoleY = -1
endFunction

int ENTER_KEY = 28
int RETURN_KEY = 156

; Array of the currently registered events for custom commands (or None)
string[] RegisteredCustomCommandEvents

; Cache of whether the native [Enter]/[Return] handling of the console is disabled
bool IsCustomConsoleCommandsEnabled = false

; Cache of whether the Console custom console.swf is installed
int __isConsoleConsoleInstalled = -1

; Property which is true if the currently console.swf used by the game is our customized version for Console
bool property IsConsoleConsoleInstalled
    bool function get()
        if __isConsoleConsoleInstalled == -1
            bool isInstalled = UI.GetBool(Console.GetMenuName(), Console.GetTarget("IsConsoleConsole"))
            if isInstalled
                __isConsoleConsoleInstalled = 1
            else
                __isConsoleConsoleInstalled = 0
            endIf
        endIf
        return __isConsoleConsoleInstalled == 1
    endFunction
endProperty

