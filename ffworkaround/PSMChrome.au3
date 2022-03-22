#AutoIt3Wrapper_UseX64=n
;~ Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 2)



;============================================================
;             PSM AutoIt iLoIE Dispatcher}
;             ---------------------------
;
; Created by J.C
; Sogeti ESEC
;============================================================
#include "PSMGenericClientWrapper.au3"
#include <MsgBoxConstants.au3>
#include <FileConstants.au3>
#include <File.au3>
#include <SendMessage.au3>
#include <WindowsConstants.au3>
#include "wd_core.au3"

;=======================================
; Consts & Globals
;=======================================

Local Const $WEB_DRIVER = "C:\Program Files (x86)\CyberArk\PSM\Components\geckodriver.exe"

Global $TargetUserName
Global $TargetPassword
Global $TargetAddress = "instagram.com/accounts/login"

;you can use this shit to close the web driver but i dont know if it keeeps
;all the vars value (global, const, etc)
; OnAutoItExitRegister("_CloseWebDriver")

; #FUNCTION# ====================================================================================================================
; Name...........: _SendSecure
; Description ...: This function send a string to a specific window control to prevent it to appears
;                  in keystrokes CyberArk audit.
; Parameters ....: $hWnd		 - The title/hWnd/class of the window to access.
; 				   $text 		 - The text of the window to access.
; 				   $controlID 	 - The control to interact with.
; 				   $string 		 - String to send securly.
; ===============================================================================================================================
Func _SendSecure($hWnd, $text, $controlID, $string)
   ; If Not IsHWnd($hWnd) Then $hWnd = GUICtrlGetHandle($hWnd)

    ; GetControl handle from windows handle
    $hWnd = ControlGetHandle($hWnd, $text, $controlID)

    For $i = 1 To StringLen($string)
	   Local $Char = StringMid($string, $i, 1)
	   _SendMessage($hWnd, $WM_CHAR, AscW($Char), 0)
    Next
 EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: _PortCheck
; Description ...: Check if port is available on interface
; Parameters ....: $py		 - interface addr.
; ===============================================================================================================================
Func _PortCheck($py = "127.0.0.1")
   Local $maxport = 60000
   Local $currentport = 4500
   Local $testport
   Local $returnedport

   Opt('TCPTimeout', 100)
   TCPStartup() ;Start TCP services
   while $currentport<$maxport
	  $testport = TCPConnect($py, $currentport)
	  TCPCloseSocket($testport)
	  If $testport <= 0 Then
		 $returnedport = $currentport
		 ExitLoop
	  Else
		 $currentport = $currentport + 1 ;go to next port
	  EndIf
   WEnd

   TCPShutdown ( ) ; Close TCP Services

   Return $returnedport
EndFunc

;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main
;=======================================
Func Main()

   Local $hWnd ; Window Handler
   Local $iPid, $fPID
   Local $sSession = ""
   Local $sElement, $aElements, $sValue
   Local $sDesiredCapabilities = _
	 '{"desiredCapabilities":' & _
		 '{"javascriptEnabled":true,' & _
		 '"nativeEvents":true,' & _
		 '"acceptInsecureCerts":true}}'

   ; Initiate PSM Session Dispatcher - Do not delete

   Local Const $TARGET_HTML = "https://" & $TargetAddress & "/"
   Local Const $MAIN_WINDOW = "[REGEXPTITLE:(.*" & $TargetAddress & ".*)]"

   ; Init PSM Dispatcher utils wrapper
   ToolTip ("Initializing...")
   if (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   ; Get the dispatcher parameters
   FetchSessionParameters()

   if (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
	 Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   ;~ NEW METHOD
   ConsoleWrite("Test available port" & @CRLF)
   Local $startPort = _PortCheck() ;choose port
   ConsoleWrite("Available port found: ")
   ConsoleWrite($startPort & @CRLF)

   ConsoleWrite("Setting up geckodriver" & @CRLF)
   SetupGecko($sDesiredCapabilities, $startPort)
   ConsoleWrite("Setup done" & @CRLF)

   $iPid = _WD_Startup($startPort)
   ConsoleWrite($iPid & @CRLF)

   ;$sSession = _WD_CreateSession($sDesiredCapabilities)
   $sSession = _WD_CreateSession($fPID,$sDesiredCapabilities)
   $iNum = Number($fPID)
   ;ConsoleWrite($iPid & @CRLF)

   _WD_Navigate($sSession, $TARGET_HTML)

   If (PSMGenericClient_SendPID($iNum) <> $PSM_ERROR_SUCCESS) Then
      Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   Sleep(500)
   $sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//input[@name='username']")
   _WD_ElementAction($sSession, $sElement, 'value', $TargetUserName)
   Sleep(500)
   $sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//input[@type='password']")
   _WD_ElementAction($sSession, $sElement, 'value', $TargetPassword)
   Sleep(500)
   $sElement = _WD_FindElement($sSession, $_WD_LOCATOR_ByXPath, "//button[@type='submit']")
   _WD_ElementAction($sSession, $sElement, 'click')
   ConsoleWrite("Finished executing component" & @CRLF)
   __WD_CloseDriverByPID($iPid)

   PSMGenericClient_Term()

   Return $PSM_ERROR_SUCCESS
EndFunc


; #FUNCTION# ====================================================================================================================
; Name...........: Error
; Description ...: An exception handler - displays an error message and terminates the dispatcher
; Parameters ....: $ErrorMessage - Error message to display
; 				   $Code 		 - [Optional] Exit error code
; ===============================================================================================================================
Func Error($ErrorMessage, $Code = -1)

	; If the dispatcher utils DLL was already initialized, write an error log message and terminate the wrapper
	if (PSMGenericClient_IsInitialized()) Then
		LogWrite($ErrorMessage, True)
		PSMGenericClient_Term()
	EndIf

	Local $MessageFlags = BitOr(0, 16, 262144) ; 0=OK button, 16=Stop-sign icon, 262144=MsgBox has top-most attribute set

	MsgBox($MessageFlags, $ERROR_MESSAGE_TITLE, $ErrorMessage)

	; If the connection component was already invoked, terminate it
	if ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf

	Exit $Code
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: DispatcherParametersFetchSessionProperties
; Description ...: Fetches DispatcherParameters properties required for the session
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func DispatcherParametersFetchSessionProperties()

   If (PSMGenericClient_GetSessionProperty("CmdOptions", $CLIENT_OPTION) <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   If (PSMGenericClient_GetSessionProperty("ExecPath", $CLIENT_EXECUTABLE) <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   If (PSMGenericClient_GetSessionProperty("OverrideCertificateX", $OVERRIDE_X) <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf

   If (PSMGenericClient_GetSessionProperty("OverrideCertificateY", $OVERRIDE_Y) <> $PSM_ERROR_SUCCESS) Then
	  Error(PSMGenericClient_PSMGetLastErrorString())
   EndIf
EndFunc ;==>DispatcherParametersFetchSessionProperties


; #FUNCTION# ====================================================================================================================
; Name...........: PSMGenericClient_GetSessionProperty
; Description ...: Fetches properties required for the session
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func FetchSessionParameters()
	If (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	If (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
EndFunc


; #FUNCTION# ====================================================================================================================
; Name...........: GetCurrentPIDbyName
; Description ...: ; Get PID of $EXEC_NAME
; Parameters ....: $EXEC_NAME
; Return values .: Bolean
; ===============================================================================================================================
Func GetCurrentPIDbyName($EXEC_NAME)

   Local $PID = 0

   ; Searching for an active sqldeveloper64W process in our Session ID
   Local $nCurrentSession = ProcessIdToSessionId(@AutoItPID)
   Local $ProcessList = ProcessList($EXEC_NAME)
   For $i = 1 To $ProcessList[0][0]
	  if (ProcessIdToSessionId($ProcessList[$i][1]) == $nCurrentSession) Then
		 $PID = $ProcessList[$i][1]
		 ExitLoop
	  EndIf
   Next

   Return $PID
Endfunc

; #FUNCTION# ====================================================================================================================
; Name...........: ProcessIdToSessionId
; Description ...: Returns the session ID of the given process
; Parameters ....: $nProcessId     - Error message to display
; Return values .: Session ID
; ===============================================================================================================================
Func ProcessIdToSessionId($nProcessId)
	Local $pSessionId = DllStructCreate("DWORD")
	Local $aResult = DllCall("kernel32.dll", "bool", "ProcessIdToSessionId", "DWORD", $nProcessId, "ptr", DllStructGetPtr($pSessionId))

	If @error Then Return SetError(@error, @extendded, False)
	Return DllStructGetData($pSessionId, 1)
EndFunc   ;==>ProcessIdToSessionId

Func SetupGecko($sCapabilities, $port)
    _WD_Option('Driver', $WEB_DRIVER)
    _WD_Option('DriverParams', ' --log trace --port ' & $port)
    _WD_Option('Port', $port)
    $sDesiredCapabilities = '{"desiredCapabilities":{"javascriptEnabled":true,"nativeEvents":true,"acceptInsecureCerts":true}}'
EndFunc

Func SetupChrome($sDesiredCapabilities, $port=9515)
    _WD_Option('Driver', 'chromedriver.exe')
    _WD_Option('Port', 9515)
    _WD_Option('DriverParams', '--log-path="' & @ScriptDir & '\chrome.log"')
    $sDesiredCapabilities = '{"capabilities": {"alwaysMatch": {"chromeOptions": {"w3c": true }}}}'
EndFunc
