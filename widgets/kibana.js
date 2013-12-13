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
          console.error("Can not save dashboard '" + save.title + "'")
          return false;
        }
      );
  };

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

  function onInstanceLinkClicked(instance, returnValue, userValue) {
    return function() {
      console.debug("value = " + returnValue.value);
      var url = parseUrl(returnValue.value); 
      var root = url.protocol + "//" + url.hostname + ":" + config.elasticsearchPort;
      console.debug("root is " + root)
      var ejsClient = getClient(root)
      var dashboard = dashboardForInstance(instance)
      elasticsearchSaveDashboard(ejsClient, dashboard, function() {
        url.hash = "#/dashboard/elasticsearch/" + dashboard.title
        console.log(url)
        document.location = url
      })
    }
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
                      1, 
                      2
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
                          "query": "@fields.instId == \"" + instance.id + "\"", 
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
  
  return {
    layout: 'inline',
    render: function(instance, returnValue, userValue) {
      return $("<a/>").text("See logs").attr("href", "#").click(
        onInstanceLinkClicked(instance, returnValue, userValue)
      ).get(0);
    },
    renderSmall: function(instance, returnValue, userValue) {
      return $("<a/>").text("See logs").attr("href", "#").click(
        onInstanceLinkClicked(instance, returnValue, userValue)
      ).get(0);
    }
  }

})()

