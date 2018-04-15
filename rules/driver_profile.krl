ruleset driver_profile {
  meta {
    logging on
    shares __testing, getProfile
    provides getProfile
  }

  global {
    __testing = {
      "queries": [ {
        "name": "getProfile"
      } ],
      "events": [ {
        "domain": "driver_profile",
        "type": "update",
        "attrs": [ "rating", "automaticBid", "automaticBidAmount", "carryingCapacity" ]
      } ]
    }
    defaultRating = 3
    defaultAutomaticBid = true
    defaultAutomaticBidAmount = 3.00
    defaultCarryingCapacity = 10
    getProfile = function() {
      ent:profile.defaultsTo({
        "rating": defaultRating,
        "automaticBid": defaultAutomaticBid,
        "automaticBidAmount": defaultAutomaticBidAmount,
        "carryingCapacity": defaultCarryingCapacity,
        "name": "N/A"
      });
    }
  }
  rule profile_update {
    select when driver_profile update
    pre {
      rating = event:attr("rating").defaultsTo(getProfile(){"rating"})
      automaticBid = event:attr("automaticBid").defaultsTo(getProfile(){"automaticBid"})
      automaticBidAmount = event:attr("automaticBidAmount").defaultsTo(getProfile(){"automaticBidAmount"})
      carryingCapacity = event:attr("carryingCapacity").defaultsTo(getProfile(){"carryingCapacity"})
      name = event:attr("name").defaultsTo(getProfile(){"name"})
    }
    fired {
      ent:profile := {
        "rating": rating,
        "automaticBid": automaticBid,
        "automaticBidAmount": automaticBidAmount,
        "carryingCapacity": carryingCapacity,
        "name": name
      }
    }
  }
}
