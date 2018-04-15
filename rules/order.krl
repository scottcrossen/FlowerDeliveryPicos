ruleset order {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module use_twilio_v2
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
      "flowerType": null,
      "requestedTime": null,
      "requiredTime": null
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
    getOrderId = function() {
      ent:orderId.defaultsTo(null);
    }
    getParentEci = function() {
      ent:parentEci.defaultsTo(null);
    }
  }

  rule driver_updated {
    select when order update
    pre {
      customerName = event:attr("customerName").defaultsTo(getCustomerContact(){"name"})
      number = event:attr("phoneNumber").defaultsTo(getCustomerContact(){"phoneNumber"})
      flowerType = event:attr("flowerType").defaultsTo(getCustomerContact(){"flowerType"})
      requestedTime = event:attr("requestedTime").defaultsTo(getCustomerContact(){"requestedTime"})
      requiredTime = event:attr("requiredTime").defaultsTo(getCustomerContact(){"requiredTime"})
      driverName = event:attr("driverName").defaultsTo(getAssignedDriver(){"name"})
      bid = event:attr("bid").defaultsTo(getAssignedDriver(){"bid"})
      requireBid = event:attr("requireBid").defaultsTo(getAssignedDriver(){"requireBid"})
      driverEci = event:attr("driverEci").defaultsTo(getAssignedDriver(){"driverEci"})
      orderId = event:attr("orderId").defaultsTo(getOrderId())
      parentEci = event:attr("parentEci").defaultsTo(getParentEci())
    }
    fired {
      ent:customerContact := {
        "name": customerName,
        "phoneNumber": number,
        "flowerType": flowerType,
        "requestedTime": requestedTime,
        "requiredTime": requiredTime
      };
      ent:assignedDriver := {
        "name": driverName,
        "bid": bid,
        "requireBid": requireBid,
        "eci": driverEci
      };
      ent:orderId := orderId;
      ent:parentEci := parentEci;
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
    select when order assign where ent:assignedDriver{"bid"} >= 0
    pre {
      driverEci = getAssignedDriver(){"eci"}
      orderId = getOrderId()
    }
    event:send({
      "eci": driverEci,
      "domain": "driver",
      "type": "order_assigned",
      "attrs": {
        "eci": meta:eci,
        "orderId": orderId
      }
    })
    fired {
      raise sms event "new_message" attributes {
        "to": getCustomerContact(){"phoneNumber"},
        "message": getCustomerContact(){"name"}.as("String") +
          "; Your " +
          getCustomerContact(){"flowerType"}.as("String") +
          " are expected to arrive by the required time of " +
          getCustomerContact(){"requiredTime"}.as("String") +
          "."
      }
    }
  }

  rule assign_fail {
    select when order assign where ent:assignedDriver{"bid"} < 0
    fired {
      schedule order event assign at time:add(time:now(), {"seconds": 5})
    }
  }

  rule fulfilled {
    select when order fulfilled
    pre {
      parent_eci = getParentEci()
      orderId = getOrderId()
    }
    event:send({
      "eci": parent_eci,
      "domain": "store",
      "type": "complete_order",
      "attrs": {
        "orderId": orderId
      }
    })
    fired {
      raise sms event "new_message" attributes {
        "to": getCustomerContact(){"phoneNumber"},
        "message": getCustomerContact(){"name"}.as("String") +
          "; Thanks for using our flower service!"
      }
      // TODO: Trevor: Make call to other API
      raise zoho event "report" attributes {
        "cust_name" = getCustomerContact(){"name"},
        "cust_phone" = getCustomerContact(){"phoneNumber"},
        "flwr_type" = getCustomerContact(){"flowerType"},
        "driver" = getAssignedDriver(){"name"},
        "bid = getAssignedDriver(){"bid"}
      }
    }
  }
}
