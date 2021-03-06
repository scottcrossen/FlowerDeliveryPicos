ruleset store_profile {
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
        "domain": "store_profile",
        "type": "update",
        "attrs": [ "minRating", "requireBid" ]
      } ]
    }
    defaultRequireBid = false
    defaultMinRating = 3
    getProfile = function() {
      ent:profile.defaultsTo({
      "requireBid": defaultRequireBid,
      "minRating": defaultMinRating,
      "name": "N/A"
      });
    }
  }
  rule profile_update {
    select when store_profile update
    pre {
      requireBid = event:attr("requireBid").defaultsTo(getProfile(){"requireBid"})
      minRating = event:attr("minRating").defaultsTo(getProfile(){"minRating"})
      name = event:attr("name").defaultsTo(getProfile(){"name"})
    }
    fired {
      ent:profile := {"requireBid": requireBid, "minRating": minRating, "name": name}
    }
  }
}
