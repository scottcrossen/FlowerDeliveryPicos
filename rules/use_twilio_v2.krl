ruleset use_twilio_v2 {
  meta {
    use module manage_profile
    use module twilio_keys
    use module twilio_v2 alias twilio
        with account_sid = keys:twilio("account_sid")
             auth_token =  keys:twilio("auth_token")
    provides send_sms
    shares __testing, messages
  }

  global {
    __testing = {
      // Make messages available as a query. (testing purposes)
      "queries": [ {
        "name": "messages",
        "args": [ "pageSize", "page", "to", "from" ]
      }],
      "events": [ {
        "domain": "test",
        "type": "new_message",
        "attrs": [ "to", "from", "message" ]
      }, {
        // Make messages available as an event too. (testing purposes)
        "domain": "test",
        "type": "messages",
        "attrs": [ "pageSize", "page", "to", "from" ]
      } ]
    }
    // I couldn't find a better way to do this so I just referenced the function like so
    messages = twilio:messages
  }

  rule test_send_sms {
    select when test new_message
    pre {
      toPhoneNumber = manager_profile:getProfile(){"toPhoneNumber"}.defaultsTo(event:attr("to"))
    }
    twilio:send_sms(toPhoneNumber,
                    event:attr("from"),
                    event:attr("message")
                   )
  }

  rule get_messages {
    select when test messages
    pre {
      messages = twilio:messages(event:attr("pageSize"),
                                     event:attr("page"),
                                     event:attr("to"),
                                     event:attr("from")
                                    )
    }
    send_directive("messages", messages)
  }
}
