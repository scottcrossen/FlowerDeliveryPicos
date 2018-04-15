ruleset use_twilio_v2 {
  meta {
    use module twilio_keys
    use module twilio_v2 alias twilio
        with account_sid = keys:twilio("account_sid")
             auth_token =  keys:twilio("auth_token")
    provides send_sms
    shares __testing, messages
  }

  global {
    __testing = {
      "queries": [ {
        "name": "messages",
        "args": [ "pageSize", "page", "to", "from" ]
      }],
      "events": [ {
        "domain": "sms",
        "type": "new_message",
        "attrs": [ "to", "from", "message" ]
      }, {
        "domain": "sms",
        "type": "messages",
        "attrs": [ "pageSize", "page", "to", "from" ]
      } ]
    }
    defaultFromPhoneNumber = "15093591239"
    defaultToPhoneNumber = "15097951660"
    messages = twilio:messages
  }

  rule send_sms {
    select when sms new_message
    twilio:send_sms(
      event:attr("to").defaultsTo(defaultToPhoneNumber),
      event:attr("from").defaultsTo(defaultFromPhoneNumber),
      event:attr("message")
    )
  }

  rule get_messages {
    select when sms messages
    pre {
      messages = twilio:messages(
        event:attr("pageSize"),
        event:attr("page"),
        event:attr("to"),
        event:attr("from")
      )
    }
    send_directive("messages", messages)
  }
}
