ruleset driver {
  meta {
    use module driver_profile alias profile
    logging on
    shares __testing
  }

  global {
    __testing = {
      "queries": [ {
        "name": "getAssignedOrders"
      } ]
    }
    getAssignedOrders = function() {
      ent:assignedOrders.defaultsTo({})
    }
  }

  rule new_order {
    select when driver new_order
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
      minRating = event:attr("minRating")
    }
    fired {
      raise gossip event "create_rumor" attributes {
        "originId": orderId,
        "messageContent": {
          "eci": eci,
          "minRating": minRating
        }
      };
      raise gossip event "new_rumor" attributes {
        "message": {
          "orderId": orderId,
          "eci": eci,
          "minRating": minRating
        }
      }
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule gossip_received {
    select when gossip new_rumor
    pre {
      eci = event:attr("message"){"eci"}
    }
    event:send({
      "eci": eci,
      "domain": "wrangler",
      "type": "subscription",
      "attrs": {
        "name": "Driver/Order Connection",
        "Rx_role": "driver",
        "Tx_role": "order",
        "channel_type": "subscription",
        "wellKnown_Tx": meta:eci
      }
    })
    fired {
      raise driver event "make_bid" attributes event:attrs on final
    }
  }

  rule make_bid {
    select when driver make_bid
    pre {
      eci = event:attr("message"){"eci"}
      orderId = event:attr("message"){"orderId"}
      minRating = event:attr("message"){"minRating"}
      rating = profile:getProfile(){"rating"}.as("Number")
      automaticBid = profile:getProfile(){"automaticBid"}.as("Boolean")
      automaticBidAmount = profile:getProfile(){"automaticBidAmount"}.as("Number")
      carryingCapacity = profile:getProfile(){"carryingCapacity"}.as("Number")
      name = profile:getProfile(){"name"}.as("String")
    }
    if rating >= minRating && automaticBid && getAssignedOrders().length() < carryingCapacity
    then
    event:send({
      "eci": eci,
      "domain": "order",
      "type": "bid",
      "attrs": {
        "bid": automaticBidAmount,
        "driverName": name,
        "driverEci": meta:eci
      }
    })
  }

  rule order_assigned {
    select when driver order_assigned
    pre {
      eci = event:attr("eci")
      orderId = event:attr("orderId")
    }
    fired {
      ent:assignedOrders{[orderId]} := eci
    }
  }

  rule order_fulfilled {
    select when driver order_fulfilled
    pre {
      orderId = event:attr("orderId")
      orderEci = getAssignedOrders(){"orderId"}.defaultsTo(null)
    }
    if orderEci != null
    then
    event:send({
      "eci": orderEci,
      "domain": "order",
      "type": "fulfilled"
    })
    fired {
      clear ent:assignedOrders{[orderId]}
    }
  }
}
