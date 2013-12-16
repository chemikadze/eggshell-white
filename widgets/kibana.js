oldGetWidgetName = app.propertyWidgets.getWidgetName

app.propertyWidgets.getWidgetName = function(instance, returnValue, userValue) {
  if (returnValue.id === "kibana-instance-dashboard") {
    return 'KibanaLogs'
  } else if (oldGetWidgetName) {
    return oldGetWidgetName(instance, returnValue, userValue)
  } else {
    return 'Default';
  }         
}

app.propertyWidgets.KibanaLogs = (function() {

  var config = {
    kibana_index: "kibana-int",
    elasticsearchPort: 9200
  }

  function elasticsearchSaveDashboard(client, dashboard, onSuccess) {
      var save = jQuery.extend(true, {}, dashboard);
      var id = save.title;

      var request = client.Document(config.kibana_index, 'dashboard', id).source({
        user: 'guest',
        group: 'guest',
        title: save.title,
        dashboard: JSON.stringify(save)
      });

      console.debug("Saving dashboard '" + dashboard.title + "'")
      return request.doIndex(
        // Success
        function(result) {
          console.log("Dashboard '" + save.title + "' saved")
          onSuccess(result);
          return result;
        },
        // Failure
        function() {
          alert("Can not connect to logging dashboard.")
          throw "Can not save dashboard '" + save.title + "'"
        }
      );
  };

  function elasticsearchMetaForInstance(client, instanceId, onSuccess) {
    // TODO: this is heavy, should use simple facet without script
    var request = client.Request()
      .query(client.QueryStringQuery("@fields.instId:\"" + instanceId + "\""))
      .size(0)
      .facet(client.TermsFacet("steps").script("_source[\"@fields\"][\"stepname\"]"))
      .facet(client.TermsFacet("vms").script("_source[\"@source_host\"]"));
    
    request.doSearch(
      function(r) {
        var steps = [];        
        var stepTerms = r['facets']['steps']['terms'];
        for (var i = 0; i < stepTerms.length; ++i) {
          steps.push(stepTerms[i]['term']);
        }

        var vms = [];        
        var vmsTerms = r['facets']['vms']['terms'];
        for (var i = 0; i < vmsTerms.length; ++i) {
          vms.push(vmsTerms[i]['term']);
        }

        onSuccess({'vms': vms, 'steps': steps});
      },
      function() {
        alert("Can not get list of steps");
        throw "Can not get list of steps";
      })
  }

  function ejsFor(root) {
    // TODO: can not be used concurrently :(
    ejs.client = ejs.jQueryClient(root);
    return ejs
  }

  getClient = ejsFor

  var urlRegex = /https?:\/\/[a-zA-Z0-9-]+(:\d+)?.*/

  function parseUrl(url) {
    // thnx jlong: https://gist.github.com/jlong/2428561
    var parser = document.createElement('a');
    parser.href = url;
    return parser;
  }  

  function elasticsearchUrl(kibanaUrl) {
    var url = parseUrl(kibanaUrl); 
    var root = url.protocol + "//" + url.hostname + ":" + config.elasticsearchPort;
    return root;
  }

  function onInstanceLinkClicked(instance, returnValue, userValue) {
    return function() {      
      var ejsClient = getClient(elasticsearchUrl(returnValue.value));
      var dashboard = dashboardForInstance(instance)

      elasticsearchSaveDashboard(ejsClient, dashboard, function() {
        var url = parseUrl(returnValue.value); 
        url.hash = "#/dashboard/elasticsearch/" + dashboard.title;
        window.location = url
      })
    }
  }

  function onLogParametersClicked(instance, returnValue, userValue) {
    function onShowFilteredLogs(ev) {
      var ejsClient = getClient(elasticsearchUrl(returnValue.value));

      var $dropdown = $(ev.target).parent(".dropdown-menu");
      var choosenSteps = [];
      var choosenVms = [];      

      var stepEls = $dropdown.find("[data-step-name]");
      for (var i = 0; i < stepEls.length; ++i) {
        if (stepEls[i].checked) {
          choosenSteps.push(stepEls[i].getAttribute('data-step-name'));
        }
      }

      var vmEls = $dropdown.find("[data-vm-addr]");
      for (var i = 0; i < vmEls.length; ++i) {
        if (vmEls[i].checked) {
          choosenVms.push(vmEls[i].getAttribute('data-vm-addr'));
        }
      }      
        
      var dashboard = withFilters(dashboardForInstance(instance), filterVms(choosenVms).concat(filterSteps(choosenSteps)));
      elasticsearchSaveDashboard(ejsClient, dashboard, function() {
        var url = parseUrl(returnValue.value); 
        url.hash = "#/dashboard/elasticsearch/" + dashboard.title;
        window.location = url
      })
    }

    function renderWaitingDropdown($el, vms) {
      $el.empty();
      var target = $('<li style="width: 160; height: 100;"/>');
      $el.append(target);
      var spinner = new Spinner({left: '55', top: '30'}).spin(target.get(0));
    }

    function renderDropdown($ul, steps, vms) {    
      $ul.empty();
      $ul.attr("style", "padding: 10px");
      // $el = $("<li/>"); // breaks render in Chrome
      // $ul.append($el);
      $el = $ul; 
      $el.append('<h4>Steps</h4>');
      for (var i = 0; i < steps.length; ++i) {
        $step = $('<label class="checkbox"/>').append($('<input/>').attr('type', 'checkbox').attr('data-step-name', steps[i])).append(steps[i]);
        $el.append($step);
      }
      $el.append('<h4>VMs</h4>');
      for (var i = 0; i < vms.length; ++i) {
        $vm = $('<label class="checkbox"/>').append($('<input/>').attr('type', 'checkbox').attr('data-vm-addr', vms[i])).append(vms[i]);
        $el.append($vm);
      }
      $el.append($('<a class="btn">Open</a>').click(onShowFilteredLogs))
    }

    return function() {
      var $el = $(this);
      var $dropdown = $el.siblings(".dropdown-menu"); 
      renderWaitingDropdown($dropdown);

      var ejsClient = getClient(elasticsearchUrl(returnValue.value));
      elasticsearchMetaForInstance(ejsClient, instance.id, function(meta) {
        renderDropdown($dropdown, meta.steps, meta.vms)
      });
    }
  }

  function newFilter(queryString) {
    return {
      "active": true, 
      "alias": "", 
      "id": -1, 
      "mandate": "must", 
      "query": queryString, 
      "type": "querystring"
    }
  }

  function filterVms(vms) {
    if (vms.length > 0) {
      var queryString = vms.map(function(vmAddr) { return '@source_host:"' + vmAddr + '"' }).join(" OR ");
      return [newFilter(queryString)];
    } else {
      return [];
    }
  }

  function filterSteps(steps) {
    if (steps.length > 0) {
      var queryString = steps.map(function(step) { return '@fields.stepname:"' + step + '"' }).join(" OR ");
      return [newFilter(queryString)];
    } else {
      return [];
    }
  }

  function withFilters(dashboard, filters) {
    var dashFilters = dashboard['services']['filter'];
    var idBase = Math.max.apply(Math, dashFilters['ids']) + 1;
    for (var i = 0; i < filters.length; ++i) {
      var filter = filters[i];
      var id = idBase + i;
      filter['id'] = id;
      dashFilters['ids'].push(id);
      dashFilters['list'][id.toString()] = filter;
    }
    return dashboard;
  }

  function dashboardForInstance(instance) {
    return {
          "title": "Logs for '" + instance.name + "'",
          "editable": true, 
          "failover": false, 
          "index": {
              "default": "NO_TIME_FILTER_OR_INDEX_PATTERN_NOT_MATCHED", 
              "interval": "hour", 
              "pattern": "[logstash-]YYYY.MM.DD.HH", 
              "warm_fields": true
          }, 
          "loader": {
              "hide": false, 
              "load_elasticsearch": true, 
              "load_elasticsearch_size": 20, 
              "load_gist": false, 
              "load_local": false, 
              "save_default": false, 
              "save_elasticsearch": true, 
              "save_gist": false, 
              "save_local": false, // seems broken 
              "save_temp": true, 
              "save_temp_ttl": "30d", 
              "save_temp_ttl_enable": true
          }, 
          "nav": [
              {
                  "collapse": false, 
                  "enable": true, 
                  "filter_id": 0, 
                  "notice": false, 
                  "now": true, 
                  "refresh_intervals": [
                      "5s", 
                      "10s", 
                      "30s", 
                      "1m", 
                      "5m", 
                      "15m", 
                      "30m", 
                      "1h", 
                      "2h", 
                      "1d"
                  ], 
                  "status": "Stable", 
                  "time_options": [
                      "5m", 
                      "15m", 
                      "1h", 
                      "6h", 
                      "12h", 
                      "24h", 
                      "2d", 
                      "7d", 
                      "30d"
                  ], 
                  "timefield": "@timestamp", 
                  "type": "timepicker"
              }
          ], 
          "panel_hints": true, 
          "pulldowns": [
              {
                  "collapse": false, 
                  "enable": true, 
                  "history": [
                      "@severity:DEBUG", 
                      "@severity:INFO", 
                      "@severity:WARN", 
                      "@severity:ERROR", 
                      "*"
                  ], 
                  "notice": false, 
                  "pinned": true, 
                  "query": "*", 
                  "remember": 10, 
                  "type": "query"
              }, 
              {
                  "collapse": true, 
                  "enable": true, 
                  "notice": false, 
                  "type": "filtering"
              }
          ], 
          "refresh": false, 
          "rows": [
              {
                  "collapsable": true, 
                  "collapse": false, 
                  "editable": true, 
                  "height": "200px", 
                  "notice": false, 
                  "panels": [
                      {
                          "annotate": {
                              "enable": false, 
                              "field": "_type", 
                              "query": "*", 
                              "size": 20, 
                              "sort": [
                                  "_score", 
                                  "desc"
                              ]
                          }, 
                          "auto_int": true, 
                          "bars": true, 
                          "derivative": false, 
                          "editable": true, 
                          "fill": 3, 
                          "grid": {
                              "max": null, 
                              "min": 0
                          }, 
                          "group": [
                              "default"
                          ], 
                          "interactive": true, 
                          "interval": "5m", 
                          "intervals": [
                              "auto", 
                              "1s", 
                              "1m", 
                              "5m", 
                              "10m", 
                              "30m", 
                              "1h", 
                              "3h", 
                              "12h", 
                              "1d", 
                              "1w", 
                              "1y"
                          ], 
                          "legend": true, 
                          "legend_counts": true, 
                          "lines": false, 
                          "linewidth": 3, 
                          "mode": "count", 
                          "options": true, 
                          "percentage": false, 
                          "pointradius": 5, 
                          "points": false, 
                          "queries": {
                              "ids": [
                                  1, 
                                  2, 
                                  3, 
                                  4
                              ], 
                              "mode": "all"
                          }, 
                          "resolution": 100, 
                          "scale": 1, 
                          "show_query": true, 
                          "span": 12, 
                          "spyable": true, 
                          "stack": true, 
                          "time_field": "@timestamp", 
                          "timezone": "browser", 
                          "title": "Events over time", 
                          "tooltip": {
                              "query_as_alias": true, 
                              "value_type": "cumulative"
                          }, 
                          "type": "histogram", 
                          "value_field": null, 
                          "x-axis": true, 
                          "y-axis": true, 
                          "y_format": "none", 
                          "zerofill": true, 
                          "zoomlinks": true
                      }
                  ], 
                  "title": "Graph"
              }, 
              {
                  "collapsable": true, 
                  "collapse": false, 
                  "editable": true, 
                  "height": "350px", 
                  "notice": false, 
                  "panels": [
                      {
                          "all_fields": false, 
                          "editable": true, 
                          "error": false, 
                          "field_list": false, 
                          "fields": [                              
                              "@timestamp", 
                              "@fields.stepname", 
                              "@source_host", 
                              "@severity",
                              "@message"
                          ], 
                          "group": [
                              "default"
                          ], 
                          "header": true, 
                          "highlight": [], 
                          "localTime": false, 
                          "normTimes": true, 
                          "offset": 0, 
                          "overflow": "min-height", 
                          "pages": 5, 
                          "paging": true, 
                          "queries": {
                              "ids": [
                                  1, 
                                  2, 
                                  3, 
                                  4
                              ], 
                              "mode": "all"
                          }, 
                          "size": 100, 
                          "sort": [
                              "@timestamp", 
                              "desc"
                          ], 
                          "sortable": true, 
                          "span": 12, 
                          "spyable": true, 
                          "status": "Stable", 
                          "style": {
                              "font-size": "9pt"
                          }, 
                          "timeField": "@timestamp", 
                          "trimFactor": 300, 
                          "type": "table"
                      }
                  ], 
                  "title": "Events"
              }
          ], 
          "services": {
              "filter": {
                  "idQueue": [
                  //    1, 
                  //    2
                  ], 
                  "ids": [
                      1, 
                      0
                  ], 
                  "list": {
                      "0": {
                          "active": true, 
                          "alias": "", 
                          "field": "@timestamp", 
                          "from": "now-1d", 
                          "id": 0, 
                          "mandate": "must", 
                          "to": "now", 
                          "type": "time"
                      }, 
                      "1": {
                          "active": true, 
                          "alias": "", 
                          "id": 1, 
                          "mandate": "must", 
                          "query": "@fields.instId:\"" + instance.id + "\"", 
                          "type": "querystring"
                      }
                  }
              }, 
              "query": {
                  "idQueue": [
                      1, 
                      2, 
                      3, 
                      4
                  ], 
                  "ids": [
                      1, 
                      2, 
                      3, 
                      4
                  ], 
                  "list": {
                      "1": {
                          "alias": "", 
                          "color": "#E24D42", 
                          "enable": true, 
                          "id": 1, 
                          "pin": false, 
                          "query": "@severity:ERROR", 
                          "type": "lucene"
                      }, 
                      "2": {
                          "alias": "", 
                          "color": "#EAB839", 
                          "enable": true, 
                          "id": 2, 
                          "pin": false, 
                          "query": "@severity:WARN*", 
                          "type": "lucene"
                      }, 
                      "3": {
                          "alias": "", 
                          "color": "#7EB26D", 
                          "enable": true, 
                          "id": 3, 
                          "pin": false, 
                          "query": "@severity:INFO", 
                          "type": "lucene"
                      }, 
                      "4": {
                          "alias": "", 
                          "color": "#6ED0E0", 
                          "enable": true, 
                          "id": 4, 
                          "pin": false, 
                          "query": "@severity:DEBUG", 
                          "type": "lucene"
                      }
                  }
              }
          }, 
          "style": "light"
      }
  }

  function renderButton(isDashboardItem, openAllHandler, openDropdownHandler) {
    var group = $('<div class="btn-group">');
    group.append(
      $('<button class="btn">Open logs...</button>')
      .click(openAllHandler));
    if (!isDashboardItem) { // TODO: dashboads has `overflow: hidden` style, so dropdown can not be displayed
      group.append(
        $('<button class="btn dropdown-toggle" data-toggle="dropdown">&nbsp;<span class="caret"></span>&nbsp;</button>')
        .click(openDropdownHandler));
      group.append($('<ul class="dropdown-menu"></ul>').click(function(event) { event.stopPropagation();}));
    } else {
      group.find(".btn").addClass("btn-mini");    
    }
    return group;
  }
  
  return {
    layout: 'inline',
    render: function(instance, returnValue, userValue) {
      return renderButton(false, 
        onInstanceLinkClicked(instance, returnValue, userValue), 
        onLogParametersClicked(instance, returnValue, userValue)).get(0);
    },
    renderSmall: function(instance, returnValue, userValue) {
      return renderButton(true, 
        onInstanceLinkClicked(instance, returnValue, userValue), 
        onLogParametersClicked(instance, returnValue, userValue)).get(0);
    }
  }

})()

