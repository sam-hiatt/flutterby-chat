 /*
This is a basic script to connect to irc.flutterby.chat with a registered account.
It stores the account password in an encrypted file. It also automatically retrieves the passport token and deletes it as soon as its used
 */
 
 menu * {
   Flutterby
   .Start/Restart Connection: connect_to_flutterby
   .Set Email: set %nick $$?="Enter your Flutterby email address:"
   .Set Password: setup_flutterby_password
   .Change Registered Nick: change_registered_nick
   .$style(%debug) Enable Debug Mode: set %debug $calc(1 - %debug) | debug_output $iif(%debug,enabled,disabled) | debug_output 4 Debug Mode: $iif(%debug,Enabled,Disabled)
 }

/*
  Prompts for the Flutterby password and saves it to an encrypted
  DPAPI-protected file at %USERPROFILE%\flutterby_password.sec.

  The password is encrypted for the current Windows user account and
  can later be decrypted by get_flutterby_password.
*/
alias setup_flutterby_password {
  var %sec = $envvar(USERPROFILE) $+ \flutterby_password.sec

  var %d = $chr(36)
  var %sq = $chr(39)
  var %pipe = $chr(124)

  var %ps = %d $+ p = Read-Host %sq $+ Enter flutterby password $+ %sq -AsSecureString; %d $+ p %pipe ConvertFrom-SecureString %pipe Set-Content -LiteralPath %sq $+ %sec $+ %sq

  run powershell -NoProfile -ExecutionPolicy Bypass -Command $qt(%ps)
}

 /*
get_flutterby_password
Description: This alias temporarily loads the stored password from a secure file and returns it for useage

 */

 alias get_flutterby_password {
  var %sec = $envvar(USERPROFILE) $+ \flutterby_password.sec

  if (!$isfile(%sec)) {
    echo -a flutterby_password.sec not found: %sec
    return
  }

  var %tmp = $envvar(TEMP) $+ \flutterby_pw_ $+ $ticks $+ .txt

  var %d = $chr(36)
  var %sq = $chr(39)
  var %pipe = $chr(124)

  var %ps = %d $+ s = Get-Content -LiteralPath %sq $+ %sec $+ %sq %pipe ConvertTo-SecureString; %d $+ b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR( %d $+ s); %d $+ pw = [Runtime.InteropServices.Marshal]::PtrToStringBSTR( %d $+ b); Set-Content -LiteralPath %sq $+ %tmp $+ %sq -Value %d $+ pw -NoNewline

  var %cmd = powershell -NoProfile -ExecutionPolicy Bypass -Command $qt(%ps)

  .comopen flutterby_wsh WScript.Shell
  if ($comerr) {
    echo -a Could not open WScript.Shell COM object.
    return
  }

  ; Run(command, windowStyle, waitOnReturn)
  noop $com(flutterby_wsh,Run,3,bstr*,%cmd,uint,0,bool,true)
  .comclose flutterby_wsh

  if (!$isfile(%tmp)) {
    echo -a PowerShell did not create temp password file.
    return
  }

  var %pw = $read(%tmp,1)
  .remove $qt(%tmp)

  return %pw
}


 
 on *:START:{
   set %debug 0
   window -ekh @Flutterby_Debug
     if (%nick == $null) {
    set %nick $$?="Enter your Flutterby email address:"
  }
  setup_flutterby_password
 }
 
 
 alias debug_output {  
   if ($1 == disabled) {
     window -h @Flutterby_Debug
   } 
   elseif ($1 == enabled) {
     noop
   }
   else {      
     if (%debug) {    
       ; If the window is hidden then show it
       if ($window(@Flutterby_Debug).state == hidden) {
         window -w3 @Flutterby_Debug
       }
 
       ; If the window does not exist then create it
       if (!$window(@Flutterby_Debug)) {
         window -ek @Flutterby_Debug
       }
 
       ; Output the message to the debug window
       echo $1 @Flutterby_Debug $2-
     }
   }
 }
 
/*

This is for the nick changer

*/


 alias change_registered_nick {
   var %url = https://flutterby.chat/api/passport/me/nick
 if ($1) {
  var %new_nick = $1
 } 
 else {
   var %new_nick = $$?="Enter your new Flutterby nick:"
 }
   ; ---- Headers ----
   bset -t &headers -1 Content-Type: application/json $+ $crlf
   bset -t &headers -1 User-Agent: mIRC $+ $crlf
   bset -t &headers -1 Host: flutterby.chat $+ $crlf
   bset -t &headers -1 Cookie: ircx_refresh= $+ %ircx_refresh $+ $crlf
   bset -t &headers -1 Authorization: Bearer %passport_token $+ $crlf
   bset -t &headers -1 Connection: keep-alive $+ $crlf $+ $crlf
 
   ; ---- Body ----
   bset -t &body 1 $chr(123)
 
   bset -t &body -1 "nick": $+ $qt(%new_nick) 
 
   bset -t &body -1 $chr(125)
 
   ; ---- POST ----
   var %id = $urlget(%url,ub,&response,onNickChangeRequestComplete,&headers,&body)
   if (%id == 0) {
     debug_output 4 Error: Failed to initiate the HTTP request to change nick
   }
 
 }
 
 
alias onNickChangeRequestComplete {
 
   var %id = $1
   if ($urlget(%id).error) {
     debug_output 4 URL Get Error: $urlget(%id).error
     return
   }
 }




/*

This is what pulls the passport token from the flutterby api and then connects to the chat server

*/

 alias connect_to_flutterby {
   var %url = https://flutterby.chat/api/passport/login
 
 
 
   ; ---- Headers ----
   bset -t &headers -1 Content-Type: application/json $+ $crlf
   bset -t &headers -1 User-Agent: mIRC $+ $crlf
   bset -t &headers -1 Host: flutterby.chat $+ $crlf
   bset -t &headers -1 Connection: keep-alive $+ $crlf $+ $crlf
 
   ; ---- Body ----
   bset -t &body 1 $chr(123)
 
   bset -t &body -1 "nick": $+ $qt(%nick) $+ ,
   bset -t &body -1 "password": $+ $qt($get_flutterby_password)
 
   bset -t &body -1 $chr(125)
 
   ; ---- POST ----
   var %id = $urlget(%url,pb,&response,onPassportRequestComplete,&headers,&body)
   
   if (%id == 0) {
     debug_output 4 Error: Failed to initiate the HTTP request to retrieve Passport Token
   }
 
 }
 
 
 alias onPassportRequestComplete {
 
   var %id = $1
   if ($urlget(%id).error) {
     debug_output 4 URL Get Error: $urlget(%id).error
     return
   }
   
   debug_output 4 Passport Response: $urlget($1).reply
   set %ircx_refresh $get_ircx_refresh($urlget($1).reply)
   set %passport_token $get_token($bvar(&response,1-).text)
   flutterby_sockbot
 }
 
 
 alias get_token {
   if ($regex($1-,/"token":"([^"]+)"/)) return $regml(1)
 }

 alias get_ircx_refresh {
  if ($regex($1-,/Set-Cookie:\s*ircx_refresh=([^;\r\n]+)/i)) return $regml(1)
}
 
 
 
 /*
 
 This is a basic socket connector for the chat
 
 */
 alias flutterby_sockbot {
 
   window -ek @Flutterby_Debug
 
   if ($sock(sockbot*)) {
     sockclose sockbot.*
   }
 
    var %port =  $r(11111,59999)
     socklisten -n sockbot.listener. $+ %port %port
     server -m localhost %port
  
 
 }
 
 on *:socklisten:sockbot.listener.*: {
   var %match_num = $gettok($sockname,3-,46)
   sockaccept sockbot.local. $+ %match_num
   sockopen sockbot.remote. $+ %match_num irc.flutterby.chat 6667
 }
 
 on *:sockread:sockbot.local.*: {
   sockread -tn %data
   tokenize 32 %data
   debug_output 6 --> $sockname $+ : $1-   
   var %match_num = $gettok($sockname,3-,46)

   if ($sock(sockbot.remote. $+ %match_num)) {
     sockwrite -n sockbot.remote. $+ %match_num $1-
   }
 }
 
 on *:sockopen:sockbot.remote.*: {
   sockwrite -n $sockname CAP REQ :redmondchat/take-over
   sockwrite -n $sockname AUTH GateKeeperPassport I init
   sockwrite -n $sockname AUTH GateKeeperPassport S response
   sockwrite -n $sockname AUTH GateKeeperPassport S PASSPORT $+ %passport_token
   sockwrite -n $sockname USER Rift 0 * Rift   
      ;unset %passport_token
 }
 
 on *:sockread:sockbot.remote.*: {
   ; Read the incoming data from the server
   sockread -tn %data
   tokenize 32 %data
   var %match_num = $gettok($sockname,3-,46)
   debug_output 3 <-- IRC Server $sockname %data
 
 
     sockwrite -n sockbot.local. $+ %match_num $1- 
 }
