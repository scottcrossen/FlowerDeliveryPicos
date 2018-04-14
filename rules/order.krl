ruleset order {
  meta {
    logging on
    shares __testing
  }

  global {
    __testing = {
    }
    defaultCustomerContact = {
      "name": null,
      "phoneNumber": null,
      "flowerType": null
    }
    defaultAssignedDriver = {
      "name": null,
      "bid": -1
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
    }
    fired {
      ent:customerContact := {
        "name": customerName,
        "phoneNumber": number,
        "flowerType": flowerType
      };
      ent:assignedDriver := {
        "name": driverName,
        "bid": bid
      }
    }
  }

  rule bid {
    select when order bid
    pre {
      driverName = event:attr("driverName").defaultsTo(null)
      bid = event:attr("bid").defaultsTo(-1)
      currentBid = getAssignedDriver(){"bid"}
    }
    fired {
      ent:assignedDriver := {
        "name": driverName,
        "bid": bid
      } if bid > currentBid && driverName != null
    }
  }
}
