ruleset reporting {

    meta {
        configure using 
                auth_token = ""
                email = ""
        provides report_ZOHO
        shares report_ZOHO, __testing
    }

    global {
        report_ZOHO = defaction(tstamp, cust_name, cust_phone, flwr_type, driver, bid) {
            tstamp = time:strftime(tstamp, "%F %T");
            email = "trydalch0320+462@gmail.com";
            auth_token = "991b83e834c6528fd439c3ae14a37c36";
            dbname = "CS462"
            tblname = "FlowerOrders"
            url = "https://reportsapi.zoho.com/api/"+email + "/" + dbname+ "/" + tblname
            params = "?ZOHO_ACTION=ADDROW&ZOHO_OUTPUT_FORMAT=JSON&ZOHO_ERROR_FORMAT=JSON&ZOHO_API_VERSION=1.0&authtoken="+auth_token+
                        "&Time="+tstamp+"&CustomerName="+cust_name+"&CustomerPhone="+cust_phone+"&FlowerType="+flwr_type+"&AssignedDriver="+driver+"&Bid="bid;
            http:post(url + params)
        }

        __testing = { "queries": [ {"name":"report_ZOHO}],
                      "events" : []}
    }
}