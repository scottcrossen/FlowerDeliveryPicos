ruleset manage_stores {
  meta {
    logging on
    shares __testing
  }

  global {
    __testing = {
      "events": [ {
        "domain": "stores",
        "type": "new"
      } ]
    }
  }

  rule stores_add {
    select when stores new
    pre {
      nextId = ent:currentChildId.defaultsTo(0).as("Number") + 1
    }
    fired {
      raise wrangler event "child_creation"
        attributes {
          "name": "Store " + nextId.as("String"),
          "color": "#ff0000"
        } if not exists;
      ent:currentChildId := nextId
    }
  }


  rule stores_add_rules {
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
            "io.picolabs.subscription"
          ]
        }
      })
    }
  }
}
