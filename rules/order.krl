ruleset order {
  meta {
    logging on
    shares __testing, getCustomerContact, getAssignedDriver
    provides getCustomerContact, getAssignedDriver
  }

  global {
    __testing = {
      "queries": [ {
        "name": "getCustomerContact"
      }, {
        "name": "getAssignedDriver"
      } ]
    }
    defaultCustomerContact = {
      "name": null,
      "phoneNumber": null,
      "flowerType": null
    }
    defaultAssignedDriver = {
      "name": null,
      "bid": -1,
      "requireBid": false,
      "eci": null
    }
    getCustomerContact = function() {
      ent:customerContact.defaultsTo(defaultCustomerContact);
    }
    getAssignedDriver = function() {
      ent:assignedDriver.defaultsTo(defaultAssignedDriver);
    }
  }

  rule driver_updated {
    select when order update
    pre {
      customerName = event:attr("customerName").defaultsTo(getCustomerContact(){"name"})
      number = event:attr("phoneNumber").defaultsTo(getCustomerContact(){"phoneNumber"})
      flowerType = event:attr("flowerType").defaultsTo(getCustomerContact(){"flowerType"})
      driverName = event:attr("driverName").defaultsTo(getAssignedDriver(){"name"})
      bid = event:attr("bid").defaultsTo(getAssignedDriver(){"bid"})
      requireBid = event:attr("requireBid").defaultsTo(getAssignedDriver(){"requireBid"})
      driverEci = event:attr("driverEci").defaultsTo(getAssignedDriver(){"driverEci"})
    }
    fired {
      ent:customerContact := {
        "name": customerName,
        "phoneNumber": number,
        "flowerType": flowerType
      };
      ent:assignedDriver := {
        "name": driverName,
        "bid": bid,
        "requireBid": requireBid,
        "eci": driverEci
      }
    }
  }

  rule bid {
    select when order bid
    pre {
      driverName = event:attr("driverName").defaultsTo(null).as("String")
      bid = event:attr("bid").defaultsTo(-1)
      driverEci = event:attr("driverEci").defaultsTo(null)
      currentBid = getAssignedDriver(){"bid"}.as("Number")
      requireBid = getAssignedDriver(){"requireBid"}.as("Boolean")
    }
    fired {
      ent:assignedDriver := {
        "name": driverName,
        "bid": bid,
        "requireBid": requireBid,
        "eci": driverEci
      } if (currentBid == -1 || requireBid) && bid > currentBid && driverName != null && driverEci != null
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule assign {
    select when order assign
    // TODO: this
  }


  rule fulfilled {
    select when order fulfilled
    // TODO: this
  }
}
