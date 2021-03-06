#include <Array.au3>
#include <InetConstants.au3>
#include <MsgBoxConstants.au3>
#include <String.au3>
#include "IRC.au3"

#include "Config.au3" ; Load configuration

Opt("TCPTimeout", $TIMEOUT)

Global $g_iServerSocket
Global $g_aMessage[0]

_Bot_Connect()

While 1
	$g_aMessage = _IRC_WaitForNextMsg($g_iServerSocket, True)
	If @error Then
		Call($__g_IRC_sLoggingFunction, "Error! Got disconnected from the IRC Server! TCPRecv @error: " & @extended, False)
		_Bot_Connect()
		ContinueLoop
	EndIf
	Call($g_sBotFunction, $g_aMessage)
WEnd

Func _Bot_Connect()
	$g_iServerSocket = _IRC_Connect($SERVER, $PORT)
	If @error Then Exit MsgBox($MB_ICONERROR, "Connection Error", "Failed to connect to the IRC Server! (@error: " & @error & ' & @extended: ' & @extended & ')')
	_IRC_AuthPlainSASL($g_iServerSocket, $USERNAME, $PASSWORD)
	If @error Then Exit MsgBox($MB_ICONERROR, "Login Failed!", "Failed to login into the IRC Server! (@error: " & @error & ' & @extended: ' & @extended & ')')
	_IRC_SetUser($g_iServerSocket, $USERNAME, $REALNAME)
	If @error Then Exit MsgBox($MB_ICONERROR, "Error while setting the user!", "An connection error occured during communication with the server! (@error: " & @error & ')')
	_IRC_SetNick($g_iServerSocket, $NICKNAME)
	If @error Then Exit MsgBox($MB_ICONERROR, "Error while setting the nickname!", "An connection error occured during communication with the server! (@error: " & @error & ')')
	For $sChannel In $CHANNELS
		_IRC_JoinChannel($g_iServerSocket, $sChannel)
	Next
	Return True
EndFunc

Func _Bot_Quit($sReason)
	_IRC_Quit($g_iServerSocket, $sReason)
	_IRC_Disconnect($g_iServerSocket)
	Exit
EndFunc

Func _Bot_DefaultBotFunction($aMessage)
	Local Const $COMMAND_PREFIX = '!'
	Switch $aMessage[$IRC_MSGFORMAT_COMMAND]
		Case "PRIVMSG"
			$aMessage = _IRC_FormatPrivMsg($aMessage)
			If Not StringLeft($aMessage[$IRC_PRIVMSG_MSG], StringLen($COMMAND_PREFIX)) = $COMMAND_PREFIX Then Return True
			Local $aCommand = StringSplit($aMessage[$IRC_PRIVMSG_MSG], ' ')
			Switch StringTrimLeft($aCommand[1], StringLen($COMMAND_PREFIX))
				Case "ping"
					_IRC_SendMessage($g_iServerSocket, $aMessage[$IRC_PRIVMSG_REPLYTO], "pong")

				Case "say"
					_IRC_SendMessage($g_iServerSocket, $aMessage[$IRC_PRIVMSG_REPLYTO], _ArrayToString($aCommand, ' ', 2))

				Case "quit"
					If _Bot_IsAdmin($aMessage[$IRC_PRIVMSG_SENDER_HOSTMASK]) Then
						_Bot_Quit("Quit Requested by " & $aMessage[$IRC_PRIVMSG_SENDER])
					Else
						_IRC_SendMessage($g_iServerSocket, $aMessage[$IRC_PRIVMSG_REPLYTO], "Never.")
					EndIf

				Case "notice"
					If _Bot_IsOP($aMessage[$IRC_PRIVMSG_SENDER_HOSTMASK]) Then
						_IRC_SendNotice($g_iServerSocket, $aCommand[2], _ArrayToString($aCommand, ' ', 3))
					EndIf

				Case "msg"
					If _Bot_IsOP($aMessage[$IRC_PRIVMSG_SENDER_HOSTMASK]) Then
						_IRC_SendMessage($g_iServerSocket, $aCommand[2], _ArrayToString($aCommand, ' ', 3))
					EndIf
			EndSwitch

		Case "PING"
			_IRC_Pong($g_iServerSocket, $aMessage[2])
	EndSwitch
EndFunc

Func _Bot_IsOP($sHostmask)
	Return $g_oOpUsers.Exists($sHostmask) Or $g_oAdminUsers.Exists($sHostmask)
EndFunc

Func _Bot_IsAdmin($sHostmask)
	Return $g_oAdminUsers.Exists($sHostmask)
EndFunc