ruleset store {
  meta {
    logging on
    shares __testing
  }

  global {
    __testing = {
      "events": [ {
        "domain": "order",
        "type": "new",
        "attrs": [ "name", "phoneNumber", "flowerType" ]
      }, {
        "domain": "store",
        "type": "add_driver",
        "attrs": [ "eci" ]
      } ]
    }
    getKnownDrivers = function() {
      ent:drivers.defaultsTo([])
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
    select when order new
    pre {
      orderId = random:uuid()
      contactName = event:attr("name").defaultsTo(null)
      contactPhoneNumber = event:attr("phoneNumber").defaultsTo(null)
      contactFlowerType = event:attr("flowerType").defaultsTo(null)
    }
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": "Order " + orderId.as("String"),
          "color": "#0000ff",
          "orderId": "orderId",
          "contactName": contactName,
          "contactPhoneNumber": contactPhoneNumber,
          "contactFlowerType": contactFlowerType
        } if contactName != null && contactPhoneNumber != null && contactFlowerType != null;
      ent:currentChildId := nextId
    }
  }

  rule order_add_rules {
    select when wrangler child_initialized
    pre {
      eci = event:attr("eci")
      orderId = event:attr("rs_attrs"){"orderId"}
      contactName = event:attr("rs_attrs"){"contactName"}
      contactPhoneNumber = event:attr("rs_attrs"){"contactPhoneNumber"}
      contactFlowerType = event:attr("rs_attrs"){"contactFlowerType"}
    }
    event:send({
      "eci": eci,
      "eid": "install-ruleset",
      "domain": "wrangler",
      "type": "install_rulesets_requested",
      "attrs": {
        "rids": [
          "io.picolabs.subscription",
          "order"
        ]
      }
    });
    fired {
      ent:orders := ent:orders.defaultsTo({});
      ent:orders{orderId} := eci;
      raise store event "set_order_info" attributes {
        "eci": eci,
        "orderId": orderId,
        "contactName": contactName,
        "contactPhoneNumber": contactPhoneNumber,
        "contactFlowerType": contactFlowerType
      } on final
    }
  }

  rule set_order_info {
    select when store set_order_info
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
      contactName = event:attr("contactName")
      contactPhoneNumber = event:attr("contactPhoneNumber")
      contactFlowerType = event:attr("contactFlowerType")
    }
    every {
      event:send({
        "eci": eci,
        "domain": "order",
        "type": "update",
        "attrs": {
          "customerName": contactName,
          "phoneNumber": contactPhoneNumber,
          "flowerType": contactFlowerType
        }
      });
      raise store event "start_order" attributes {
        "eci": eci,
        "orderId": orderId
      } on final
    }
  }
}
