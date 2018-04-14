ruleset manage_drivers {
  meta {
    logging on
    shares __testing
  }

  global {
    __testing = {
      "events": [ {
        "domain": "drivers",
        "type": "new"
      } ]
    }
  }

  rule drivers_add {
    select when drivers new
    pre {
      nextId = ent:currentChildId.defaultsTo(0).as("Number") + 1
      children = wrangler:children()
      exists = (children.filter(function(child) {
        child{"name"} == "driver " + nextId.as("String")
      }).length() != 0)
    }
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": "driver " + nextId.as("String"),
          "color": "#00ff00"
        } if not exists;
      ent:currentChildId := nextId
    }
  }


  rule drivers_add_rules {
    select when wrangler child_initialized
    pre {
      eci = event:attr("eci")
    }
    every {
      event:send({
        "eci": eci,
        "eid": "install-ruleset",
        "domain": "wrangler",
        "type": "install_rulesets_requested",
        "attrs": {
          "rids": [
            "io.picolabs.subscription",
            "gossip.krl"
          ]
        }
      })
    }
  }
}
