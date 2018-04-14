ruleset driver_profile {
  meta {
    logging on
    shares __testing
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
        "attrs": [ "rating", "automaticBid", "automaticBidAmount" ]
      } ]
    }
    defaultRating = 3
    defaultAutomaticBid = true
    defaultAutomaticBidAmount = 3.00
    getProfile = function() {
      ent:profile.defaultsTo({
        "rating": defaultRating,
        "automaticBid": defaultAutomaticBid,
        "automaticBidAmount": defaultAutomaticBidAmount
      });
    }
  }
  rule profile_update {
    select when driver_profile update
    pre {
      rating = event:attr("rating").defaultsTo(getProfile(){"rating"})
      automaticBid = event:attr("automaticBid").defaultsTo(getProfile(){"automaticBid"})
      automaticBidAmount = event:attr("automaticBidAmount").defaultsTo(getProfile(){"automaticBidAmount"})
    }
    fired {
      ent:profile := {"rating": rating, "automaticBid": automaticBid, "automaticBidAmount": automaticBidAmount}
    }
  }
}
