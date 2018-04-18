ruleset store {
  meta {
    use module store_profile alias profile
    logging on
    shares __testing, getOrders, getKnownDrivers
  }

  global {
    __testing = {
      "queries": [ {
        "name": "getKnownDrivers",
        "name": "getOrders"
      } ],
      "events": [ {
        "domain": "store",
        "type": "new_order",
        "attrs": [ "name", "phoneNumber", "flowerType", "requestedTime", "requiredTime" ]
      }, {
        "domain": "store",
        "type": "add_driver",
        "attrs": [ "eci" ]
      } ]
    }
    getKnownDrivers = function() {
      ent:drivers.defaultsTo([])
    }
    getOrders = function() {
      ent:orders.defaultsTo([])
    }
  }

  rule add_driver {
    select when store add_driver
    pre {
      driverEci = event:attr("eci")
      knownDrivers = getKnownDrivers().filter(function(givenDriverEci) {
        givenDriverEci != driverEci
      })
    }
    event:send({
      "eci": driverEci,
      "domain": "wrangler",
      "type": "subscription",
      "attrs": {
        "name": "Driver/Store Connection",
        "Rx_role": "store",
        "Tx_role": "driver",
        "channel_type": "subscription",
        "wellKnown_Tx": meta:eci
      }
    })
    fired {
      ent:drivers := getKnownDrivers().append(driverEci)
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule new_order {
    select when store new_order
    pre {
      orderId = random:uuid()
      contactName = event:attr("name").defaultsTo(null)
      contactPhoneNumber = event:attr("phoneNumber").defaultsTo(null)
      contactFlowerType = event:attr("flowerType").defaultsTo(null)
      contactRequestedTime = event:attr("requestedTime").defaultsTo(null)
      contactRequiredTime = event:attr("requiredTime").defaultsTo(null)
    }
    fired {
      raise wrangler event "child_creation" attributes {
        "name": "Order " + orderId.as("String"),
        "color": "#0000ff",
        "orderId": orderId,
        "parentEci": meta:eci,
        "contactName": contactName,
        "contactPhoneNumber": contactPhoneNumber,
        "contactFlowerType": contactFlowerType,
        "contactRequestedTime": contactRequestedTime,
        "contactRequiredTime": contactRequiredTime
      } if contactName != null && contactPhoneNumber != null && contactFlowerType != null;
    }
  }

  rule order_add_rules {
    select when wrangler child_initialized
    pre {
      eci = event:attr("eci")
      orderId = event:attr("rs_attrs"){"orderId"}
      parentEci = event:attr("rs_attrs"){"parentEci"}
      contactName = event:attr("rs_attrs"){"contactName"}
      contactPhoneNumber = event:attr("rs_attrs"){"contactPhoneNumber"}
      contactFlowerType = event:attr("rs_attrs"){"contactFlowerType"}
      contactRequestedTime = event:attr("rs_attrs"){"contactRequestedTime"}
      contactRequiredTime = event:attr("rs_attrs"){"contactRequiredTime"}
    }
    event:send({
      "eci": eci,
      "eid": "install-ruleset",
      "domain": "wrangler",
      "type": "install_rulesets_requested",
      "attrs": {
        "rids": [
          "io.picolabs.subscription",
          "order",
          "twilio_keys",
          "use_twilio_v2",
          "twilio_v2",
          "use_zoho",
          "zoho_keys",
          "zoho"
        ]
      }
    });
    fired {
      raise store event "subscribe_to_child" attributes {
        "eci": eci,
        "orderId": orderId,
        "parentEci": parentEci,
        "contactName": contactName,
        "contactPhoneNumber": contactPhoneNumber,
        "contactFlowerType": contactFlowerType,
        "contactRequestedTime": contactRequestedTime,
        "contactRequiredTime": contactRequiredTime
      } on final
    }
  }

  rule subscribe_to_child {
    select when store subscribe_to_child
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
    }
    event:send({
      "eci": eci,
      "domain": "wrangler",
      "type": "subscription",
      "attrs": {
        "name": "Store/Order Connection",
        "Rx_role": "store",
        "Tx_role": "order",
        "channel_type": "subscription",
        "wellKnown_Tx": meta:eci
      }
    })
    fired {
      ent:orders := ent:orders.defaultsTo({});
      ent:orders{[orderId]} := eci;
      raise store event "set_order_info" attributes event:attrs on final
    }
  }

  rule set_order_info {
    select when store set_order_info
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
      parentEci = event:attr("parentEci")
      contactName = event:attr("contactName")
      contactPhoneNumber = event:attr("contactPhoneNumber")
      contactFlowerType = event:attr("contactFlowerType")
      contactRequestedTime = event:attr("contactRequestedTime")
      contactRequiredTime = event:attr("contactRequiredTime")
      requireBid = profile:getProfile(){"requireBid"}
    }
    event:send({
      "eci": eci,
      "domain": "order",
      "type": "update",
      "attrs": {
        "requireBid": requireBid,
        "customerName": contactName,
        "phoneNumber": contactPhoneNumber,
        "flowerType": contactFlowerType,
        "requestedTime": contactRequestedTime,
        "requiredTime": contactRequiredTime,
        "orderId": orderId,
        "parentEci": parentEci
      }
    })
    fired {
      raise store event "start_order" attributes {
        "eci": eci,
        "orderId": orderId
      } on final
    }
  }

  rule start_order {
    select when store start_order
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
    }
    fired {
      raise store event "propagate_order" attributes {
        "eci": eci,
        "orderId": orderId
      };
      schedule store event "assign_order" at time:add(time:now(), {"seconds": 5}) attributes {
        "eci": eci,
        "orderId": orderId
      }
    }
  }

  rule propagate_order {
    select when store propagate_order
    foreach getKnownDrivers() setting (driverEci)
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
      minRating = profile:getProfile(){"minRating"}
    }
    event:send({
      "eci": driverEci,
      "domain": "driver",
      "type": "new_order",
      "attrs": {
        "eci": eci,
        "orderId": orderId,
        "minRating": minRating
      }
    })
  }

  rule assign_order {
    select when store assign_order
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
    }
    event:send({
      "eci": eci,
      "domain": "order",
      "type": "assign"
    })
  }

  rule complete_order {
    select when store complete_order
    pre {
      orderId = event:attr("orderId")
    }
    fired {
      raise wrangler event "child_deletion" attributes {
        "name": "Order " + orderId.as("String")
      }
    }
  }
}
