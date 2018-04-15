ruleset use_zoho {
    meta {
        use module zoho_keys
        use module zoho_sheets alias zoho
            with    auth_token = keys:zoho("auth_token")
                    email = keys:zoho("email")
        shares __testing
    }

    global {
        __testing = {
            "queries": [],
            "events": [ {"domain":"order", "type":"report", "attrs": ["cust_name","cust_phone","flwr_type","driver","bid"]}]
        }
    }

    rule report {
        select when zoho report {
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