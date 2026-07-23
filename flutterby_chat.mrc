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
  .Set Regional Preference
  ..$iif(%preferred_region == AMER,$style(1)) AMER: set %preferred_region AMER | debug_output 4 Preferred region set to AMER
  ..$iif(%preferred_region == EMEA,$style(1)) EMEA: set %preferred_region EMEA | debug_output 4 Preferred region set to EMEA
  .Debug Options
  ..$style(%debug) Enable Debug Mode: set %debug $calc(1 - %debug) | debug_output $iif(%debug,enabled,disabled) | debug_output 4 Debug Mode: $iif(%debug,Enabled,Disabled)
  ..Debug Level
  ...$iif(%debug_level == 1,$style(1)) Level 1 (minimal): set %debug_level 1
  ...$iif(%debug_level == 2,$style(1)) Level 2 (verbose): set %debug_level 2
  ...$iif(%debug_level == 3,$style(1)) Level 3 (extreme): set %debug_level 3
  ...$iif(%debug_level == 4,$style(1)) Level 4 (insane): set %debug_level 4
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

  var %ps = %d $+ p = Read-Host %sq $+ Enter flutterby password for %nick $+ %sq -AsSecureString; %d $+ p %pipe ConvertFrom-SecureString %pipe Set-Content -LiteralPath %sq $+ %sec $+ %sq

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



on *:LOAD:{
  ;ensure the debug window is created and hidden on load
  set %debug 0
  set %debug_level 1
  set %color_info 12
  set %color_danger 4
  set %color_success 9
  set %color_debug 14
  set %color_warning 8
  set %color_client 63
  set %color_server 71

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
    /*
    This is a debug output function that will output to the debug window if %debug is enabled
    */
    if (%debug) {    
      ; If the window is hidden then show it
      if ($window(@Flutterby_Debug).state == hidden) {
        window -w3 @Flutterby_Debug
      }

      ; If the window does not exist then create it
      if (!$window(@Flutterby_Debug)) {
        window -ek @Flutterby_Debug
      }

      if ($1 <= %debug_level) {
        ; Output the message to the debug window
        echo $2 @Flutterby_Debug $3-
      }
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
    debug_output 1 %color_danger Error: Failed to initiate the HTTP request to change nick
  }

}


alias onNickChangeRequestComplete {

  var %id = $1
  if ($urlget(%id).error) {
    debug_output 2 %color_danger URL Get Error: $urlget(%id).error
    return
  }
  debug_output 2 %color_success $urlget($1).reply
}




/*

This is what pulls the passport token from the flutterby api and then connects to the chat server

*/

alias get_flutterby_passport {
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
    debug_output 1 %color_danger Error: Failed to initiate the HTTP request to retrieve Passport Token
  }

}


alias onPassportRequestComplete {

  var %id = $1
  if ($urlget(%id).error) {
    debug_output 2 %color_danger URL Get Error: $urlget(%id).error
    return
  }

  debug_output 2 %color_success Passport Response: $urlget($1).reply
  set %ircx_refresh $get_ircx_refresh($urlget($1).reply)
  set %passport_token $get_token($bvar(&response,1-).text)
  if (%retrying) {
    ;cycle through %retrying to send_auth to each socket that needs it
    var %i = 1
    var %j = $numtok(%retrying,59)
    debug_output 1 %color_warning Attempting re-auth on %j sockets.
    while (%i <= %j) {
      %retrying_socket = $gettok(%retrying,1,59)
      debug_output 1 %color_debug sending auth to %retrying_socket
      if (%retrying_socket) {
        set %retrying $remtok(%retrying,%retrying_socket,0,59) $+ $chr(59)
        send_auth %retrying_socket
      }
      inc %i
    }
  }
}


alias get_token {
  if ($regex($1-,/"token":"([^"]+)"/)) return $regml(1)
}

alias get_ircx_refresh {
  if ($regex($1-,/Set-Cookie:\s*ircx_refresh=([^;\r\n]+)/i)) return $regml(1)
}

alias send_auth {
  sockwrite -n $1 AUTH GateKeeperPassport I init
  sockwrite -n $1 AUTH GateKeeperPassport S response
  sockwrite -n $1 AUTH GateKeeperPassport S PASSPORT $+ %passport_token
  sockwrite -n $1 USER Rift 0 * Rift   
}


/*
This is to track the server window
*/
alias flutterby_existing_cid {
  if (%flutterby.local.cid) {
    if ($scid(%flutterby.local.cid).status) return %flutterby.local.cid
  }

  unset %flutterby.local.cid
  return 0
}

on *:DISCONNECT:{
  if ($cid == %flutterby.local.cid) {
    debug_output 4 %color_info Flutterby local server window disconnected. Clearing saved CID.
    unset %flutterby.local.cid
  }
}


/*

This is a basic socket connector for the chat

*/
alias connect_to_flutterby_bak {

  window -ek @Flutterby_Debug

  if ($sock(sockbot*)) {
    sockclose sockbot.*
  }

  var %port =  $r(11111,59999)
  socklisten -n sockbot.listener. $+ %port %port
  server -m localhost %port


}

alias connect_to_flutterby {

  window -ek @Flutterby_Debug

  if ($sock(sockbot*)) {
    sockclose sockbot.*
  }
  

  var %port = $r(11111,59999)
  set %flutterby.local.port %port

  socklisten -n sockbot.listener. $+ %port %port


  ; If we already opened a localhost server window and it still exists, reuse it
  var %cid = $flutterby_existing_cid

  if ((%cid) || ($scid(0) == 1)) {
    scon %cid
    debug_output 3 %color_info Reusing existing Flutterby server window. CID: %cid

   
    
      debug_output 3 %color_info Existing Flutterby window found but disconnected. Reconnecting...
      server localhost %flutterby.local.port
    

    return
  }

  ; No existing usable server window, so start fresh

  ; -m is only used here when we truly need a new server window
  server -m localhost %port

  ; Save the new server window connection id
  set %flutterby.local.cid $cid

  debug_output 3 %color_info Opened new Flutterby server window. CID: %flutterby.local.cid Port: %flutterby.local.port
}

on *:socklisten:sockbot.listener.*: {
  var %match_num = $gettok($sockname,3,46)
  sockaccept sockbot.local. $+ %match_num
  sockopen sockbot.remote. $+ %match_num $+ .AMER irc.flutterby.chat 6667  
  sockopen sockbot.remote. $+ %match_num $+ .EMEA emea.flutterby.chat 6667
}

on *:sockread:sockbot.local.*: {
  .sockread -tn %data
  .tokenize 32 %data
  debug_output 1 %color_client --> $sockname $+ : $1-
  .var %match_num = $gettok($sockname,3,46)

  if ($sock(sockbot.remote. $+ %match_num $+ *)) {
    if ($1 == JOIN) {
      ;we need to send FINDS in place of JOIN since there are regional servers and each room is only on one server at a time
      set %pending_room $2
      sockwrite -n sockbot.remote. $+ %match_num $+ .* FINDS %pending_room
    } 
    else {
    sockwrite -n sockbot.remote. $+ %match_num $+ .* $1-
    }
  }
}

on *:sockopen:sockbot.remote.*: {
  ;sockwrite -n $sockname CAP REQ :redmondchat/persistent-session
  send_auth $sockname
}

on *:sockread:sockbot.remote.*: {
  ; Read the incoming data from the server
  .sockread -tn %data
  .tokenize 32 %data
  var %match_num = $gettok($sockname,3,46)
  debug_output 1 %color_server <-- IRC Server $sockname %data

  if ($2 == 910) {
    ;the server is telling us that the passport token is invalid, so we need to get a new one and try again
    if (!%retrying) {
      set %retrying $sockname $+ $chr(59)
    } 
    else {
      set %retrying $addtok(%retrying,$sockname,59)
    }
    get_flutterby_passport
  } 
  elseif ($2 == 321) {
    inc %numeric.counter.321
    ;block duplicate 321 responses to prevent messing up the channel listing but send the first 321 response
    if (%numeric.counter.321 == 1) {
            debug_output 4 %color_info sending 321 response after collecting %numeric.counter.321 321 responses
      sockwrite -n sockbot.local. $+ %match_num $1-
      debug_output 4 %color_info collecting 321 responses
    }
    elseif (%numeric.counter.321 >= $sock(sockbot.remote. $+ %match_num $+ .*,0)) {
      ;we have collected all open 322 responses so now we can send a single one
      

      unset %numeric.counter.321
    }
  }
    elseif ($2 == 323) {
       inc %numeric.counter.323
       debug_output 4 %color_info writing to numeric.counter.323 %numeric.counter.323
    ;block duplicate 323 responses to prevent messing up the channel listing but send the last 323 response
    if (%numeric.counter.323 < $sock(sockbot.remote. $+ %match_num $+ .*,0)) {
     
      debug_output 4 %color_info collecting 323 responses
    }
    elseif (%numeric.counter.323 >= $sock(sockbot.remote. $+ %match_num $+ .*,0)) {
      ;we have collected all open 322 responses so now we can send a single one
      
      debug_output 4 %color_info sending 323 response after collecting %numeric.counter.323 323 responses
      sockwrite -n sockbot.local. $+ %match_num $1-
      unset %numeric.counter.323
    }

    
  }
  elseif ($2 == 322) {
    /*
      We will parse the 322 responses to compensate for the dual server response. Each server responds with all channels however the server responds with the correct number of participants only if the room exists on that server.
      In order to accurately determine which server hosts a particular room, we need to track the responses from both servers and only consider the participant count from the server that actually hosts the room.
      This can be done by filtering the first token in the topic ([AMER], [EMEA], [APAC]) and only considering the participant count from the server that matches the region indicated by that token.
    */
    if (($regex($1-,/^:\S+\s+322\s+\S+\s+\S+\s+\S+\s+:\[([^\]]+)\]/)) && $gettok($sockname,4,46) == $regml(1)) {
      ;This meaans our socket matches the region of the room and therefore we will allow this to paass to the client as it should contain the correct participant count
      sockwrite -n sockbot.local. $+ %match_num $1-
    }
    else {
      debug_output 4 %color_info Skipping 322 response for $sockname as it does not match the region of the room. Compared: $gettok($sockname,4,46) vs $regex($1-,/^:\S+\s+322\s+\S+\s+\S+\s+\S+\s+:\[([^\]]+)\]/,1)
    }
  }
  elseif ($2 == 403) {
    /*
     The room doesn't exist. this message is received when sending a FINDS on a room that doesn't exist. it also is received when sending commands such as MODE <room_name>
     Since we can receive this in different contexts, we need to check if we have a pending room and if so, we can assume we received it will trying to join the room
    */
    if (%pending_room) {
      ;create the room in the user's preferred region and then join it. if the user has not set a preferred region, default to AMER
      if (!%preferred_region) { 
        set %preferred_region AMER
      }
      sockwrite -n sockbot.remote. $+ %match_num $+ . $+ %preferred_region JOIN %pending_room
      unset %pending_room
      }
    
  }
  elseif ($2 == 911) {
    ;we have been banned from authing so stop the retry
    unset %retrying  
  }
  elseif ($2 == 613) {
    ;the server is telling us that the room is hosted on another server, so we need to redirect the user to that server    
    
    if (%pending_room) {
      debug_output 1 %color_info redirecting to $gettok($4,1,58) to join room %pending_room
      join_chat $gettok($4,1,58) %pending_room
      unset %pending_room
    }
    
  }
  elseif (*@redirect* iswm $1) {
    /*
    @redirect=5.78.220.30:6667 :irc.flutterby.chat NOTICE %#thelobby :Room %#thelobby is hosted on another chat server (amer) at 5.78.220.30:6667 — reconnect there to join it.
    Now we have the IP address of the server where the room is located so we need to determine which of our remote sockets matches that IP
    */
    
    if ($regex($1,/@redirect=([0-9.]+):/)) {
      var %ip = $regml(1)
      join_chat %ip $4
    } 
    else {
      debug_output 1 %color_error Could not extract IP address from redirect message: $1-
    }
    
  }
  else {

    sockwrite -n sockbot.local. $+ %match_num $1- 
  }
}

alias join_chat {
  
  var %i = 1
  while ($sock(sockbot.remote.*,%i)) {
    if ($1* iswm $sock(sockbot.remote.*,%i).ip) {
       debug_output 3 %color_info MATCH FOUND $sock(sockbot.remote.*,%i).name IP: $+ $sock(sockbot.remote.*,%i).ip
       sockwrite -n $sock(sockbot.remote.*,%i) JOIN $2
    } 
    else {
      debug_output 3 %color_info $sock(sockbot.remote.*,%i).name IP: $+ $sock(sockbot.remote.*,%i).ip
    }
    inc %i
  }
}