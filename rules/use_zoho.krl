ruleset use_zoho {
    meta {
        use module zoho_keys
        use module zoho_sheets alias zoho
            with    auth_token = keys:zoho("auth_token")
                    email = keys:zoho("email")
        provides report_ZOHO
        shares __testing, report_ZOHO
    }

    global {
        
    }

    rule report {
        select when order report {
            pre {
                tstamp = time:now()
                cust_name = event:attr("cust_name")
                cust_phone = event:attr("cut_phone")
                flwr_type = event:attr("flwr_type")
                driver = event:attr("driver")
                bid = event:attr("bid")
            }
            if true then
                zoho:report_ZOHO(tstamp, cust_name, cust_phone, flwr_type, driver, bid)
        }
    }
}