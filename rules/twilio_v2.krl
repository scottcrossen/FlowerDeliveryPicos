ruleset twilio_v2 {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides send_sms, messages
  }

  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
         "From":from,
         "To":to,
         "Body":message
       })
    }
    messages = function(pageSize, page, to, from) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json>>;
       full_query = (base_url +
         "?PageSize=" + ((pageSize == "" || pageSize == null) => "50" | pageSize) +
         ((page == "" || page == null) => "" | "&Page=" + page) +
         ((to == "" || to == null) => "" | "&To=" + to) +
         ((from == "" || to == null) => "" | "&From=" + from)).klog("full message query:");
       http:get(full_query)
    }
  }
}
