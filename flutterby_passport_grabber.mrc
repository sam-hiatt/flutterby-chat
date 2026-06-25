
alias get_flutterby_passport {
  var %url = https://flutterby.chat/api/passport/login



  ; ---- Headers ----
  bset -t &headers -1 Content-Type: application/json $+ $crlf
  bset -t &headers -1 User-Agent: mIRC $+ $crlf
  bset -t &headers -1 Host: flutterby.chat $+ $crlf
  bset -t &headers -1 Connection: keep-alive $+ $crlf $+ $crlf

  ; ---- Body ----
  bset -t &body 1 $chr(123)

  bset -t &body -1 "nick": $+ $qt($$?="Enter your email address") $+ ,
  bset -t &body -1 "password": $+ $qt($$?="Enter your password")

  bset -t &body -1 $chr(125)

  ; ---- POST ----
  var %id = $urlget(%url,pb,&response,onfPassportRequestComplete,&headers,&body)

  if (%id == 0) {
    debug_output 4 Error: Failed to initiate the HTTP request to retrieve Passport Token
  }

}


alias onfPassportRequestComplete {

  var %id = $1
  if ($urlget(%id).error) {
    debug_output 4 URL Get Error: $urlget(%id).error
    return
  }
  ; Retrieve the response message from the &binvar
  set %passport_token $get_token($bvar(&response,1-).text)
  echo Passport token saved to $chr(37) $+ passport_token %passport_token
}


alias get_token {
  if ($regex($1-,/"token":"([^"]+)"/)) return $regml(1)
}

