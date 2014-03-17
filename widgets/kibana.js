oldGetWidgetName = app.propertyWidgets.getWidgetName

app.propertyWidgets.getWidgetName = function(instance, returnValue, userValue) {
  if (returnValue.id.indexOf &&
      (returnValue.id.indexOf("kibana-instance-dashboard") >= 0 ||
       returnValue.id.indexOf("logging-dashboard") >= 0)) {
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

  function elasticsearchSaveDashboard(client, dashboard, onSuccess, onFailure) {
      var save = jQuery.extend(true, {}, dashboard);
      var id = save.title;

      var request = client.Document(config.kibana_index, 'dashboard', id).source({
        user: 'guest',
        group: 'guest',
        title: save.title,
        dashboard: JSON.stringify(save)
      });

      console.debug("Saving dashboard '" + dashboard.title + "'")
      return request.doIndex(onSuccess, onFailure);
  };

  function elasticsearchMetaForInstance(client, instanceId, onSuccess, onFailure) {
    // TODO: this is heavy, should use simple facet without script
    var request = client.Request()
      .query(client.QueryStringQuery("instId:\"" + instanceId + "\""))
      .size(0)
      .facet(client.TermsFacet("steps").script("_source[\"stepname\"]"))
      .facet(client.TermsFacet("jobs").script("_source[\"jobId\"]"))
      .facet(client.TermsFacet("vms").script("_source[\"host\"]"));

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

        var jobs = [];
        var jobTerms = r['facets']['jobs']['terms'];
        for (var i = 0; i < jobTerms.length; ++i) {
          jobs.push(jobTerms[i]['term']);
        }

        onSuccess({'vms': vms, 'steps': steps, 'jobs': jobs});
      },
      onFailure)
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
    var port = config.elasticsearchPort;
    if (url.protocol == "https:") {
      port += 1;
    }
    var root = url.protocol + "//" + url.hostname + ":" + port;
    return root;
  }

  function onInstanceLinkClicked(instance, returnValue, userValue) {
    return function() {
      var ejsClient = getClient(elasticsearchUrl(returnValue.value));
      var dashboard = dashboardForInstance(instance)

      elasticsearchSaveDashboard(ejsClient, dashboard,
        function() {
          var url = parseUrl(returnValue.value);
          url.hash = "#/dashboard/elasticsearch/" + dashboard.title;
          window.location = url
        },
        function() {
          alert("Can not connect to logging dashboard.")
          throw "Can not save dashboard '" + dashboard.title + "'"
        })
    }
  }

  // TODO move to css
  var dropdownStyle = "display: inline; padding: 0px; background-color: #fcf8e3; color: #805813;"

  var mozillaWarning =
    'If you are using Firefox, either enable mixed content on this page by clicking ' +
    '<img height="15" width="15" src="http://qubell-logging.s3.amazonaws.com/ff-shield.png" >&nbsp;icon in address bar, ' +
    'or disable mixed content blocking by disabling <tt>block_active_content</tt> flag in <tt>about:config</tt>.';

  function onLogParametersClicked(instance, returnValue, userValue) {
    function onShowFilteredLogs(ev) {
      var ejsClient = getClient(elasticsearchUrl(returnValue.value));

      var $dropdown = $(ev.target).parent(".dropdown-menu");
      function collectCheckboxes(dataAttribute) {
        var choosenAttrs = [];
        var els = $dropdown.find("[" + dataAttribute + "]");
        for (var i = 0; i < els.length; ++i) {
          if (els[i].checked) {
            choosenAttrs.push(els[i].getAttribute(dataAttribute));
          }
        }
        return choosenAttrs;
      }

      var choosenSteps = collectCheckboxes('data-step-name');
      var choosenVms = collectCheckboxes('data-vm-addr');
      var choosenJobs = collectCheckboxes('data-job-id');

      var dashboard = withFilters(dashboardForInstance(instance),
        filterVms(choosenVms).concat(filterSteps(choosenSteps)).concat(filterJobs(choosenJobs)));
      elasticsearchSaveDashboard(ejsClient, dashboard,
        function() {
          var url = parseUrl(returnValue.value);
          url.hash = "#/dashboard/elasticsearch/" + dashboard.title;
          window.location = url
        },
        function() {
          var msg =
            'Can not upload dashboard settings to logging dashboard. ' +
            'Check that logger instance with address ' +
            '<a style="' + dropdownStyle + '" href="' + parseUrl(returnValue.value).host + '">' + parseUrl(returnValue.value).host + '</a>' +
            ' is running.';
          if ($.browser.mozilla) {
            msg += '<br/><br/>' + mozillaWarning;
          }
          renderFailedDropdown($dropdown, msg);
        })
    }

    function clearDropdown($el) {
      $el.empty();
      $el.removeClass("alert");
    }

    function renderWaitingDropdown($el, vms) {
      clearDropdown($el);
      var target = $('<li style="width: 160px; height: 100px;"/>');
      $el.append(target);
      var spinner = new Spinner({left: '55px', top: '30px'}).spin(target.get(0));
    }

    function renderFailedDropdown($el, message) {
      clearDropdown($el);
      $el.addClass("alert");
      $el.append($('<li style="word-break: break-word;">' + message + '</li>'));
    }

    function renderDropdown($ul, steps, vms, jobs) {
      clearDropdown($ul);
      $ul.attr("style", "padding: 10px");
      // $el = $("<li/>"); // breaks render in Chrome
      // $ul.append($el);
      $el = $ul;

      function addItems(attr, items) {
        for (var i = 0; i < items.length; ++i) {
          $item = $('<label class="checkbox"/>').append($('<input/>').attr('type', 'checkbox').attr(attr, items[i])).append(items[i]);
          $el.append($item);
        }
      }

      $el.append('<h4>Jobs</h4>');
      addItems('data-job-id', jobs);

      $el.append('<h4>Steps</h4>');
      addItems('data-step-name', steps);

      $el.append('<h4>VMs</h4>');
      addItems('data-vm-addr', vms);

      $el.append($('<a class="btn">Open</a>').click(onShowFilteredLogs))
    }

    return function() {
      var $el = $(this);
      var $dropdown = $el.siblings(".dropdown-menu");
      renderWaitingDropdown($dropdown);

      var ejsClient = getClient(elasticsearchUrl(returnValue.value));
      elasticsearchMetaForInstance(ejsClient, instance.id,
        function(meta) {
          renderDropdown($dropdown, meta.steps, meta.vms, meta.jobs)
        },
        function() {
          var msg =
            'Can not load information about stored logs. ' +
            'Check that logger instance with address ' +
            '<a style="' + dropdownStyle + '" href="http://' + parseUrl(returnValue.value).host + '">' + parseUrl(returnValue.value).host + '</a>' +
            ' is running.'
          if ($.browser.mozilla) {
            msg += '<br/><br/>' + mozillaWarning;
          }
          renderFailedDropdown($dropdown, msg);
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

  function fieldFilter(fieldName) {
    return function(values) {
      if (values.length > 0) {
        var queryString = values.map(function(value) { return fieldName + ':"' + value + '"' }).join(" OR ");
        return [newFilter(queryString)];
      } else {
        return [];
      }
    }
  }

  var filterVms = fieldFilter('host');

  var filterSteps = fieldFilter('stepname');

  var filterJobs = fieldFilter('jobId');

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
                              "stepname",
                              "host",
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
                          "query": "instId:\"" + instance.id + "\"",
                          "type": "querystring"
                      }
                  }
              },
              "query": {
                  "idQueue": [
                      1,
                      2,
                      3,
                      4,
                      5
                  ],
                  "ids": [
                      1,
                      2,
                      3,
                      4,
                      5
                  ],
                  "list": {
                      "1": {
                          "alias": "",
                          "color": "#FF0000",
                          "enable": true,
                          "id": 1,
                          "pin": false,
                          "query": "@severity:FATAL",
                          "type": "lucene"
                      },
                      "2": {
                          "alias": "",
                          "color": "#E24D42",
                          "enable": true,
                          "id": 2,
                          "pin": false,
                          "query": "@severity:ERROR",
                          "type": "lucene"
                      },
                      "3": {
                          "alias": "",
                          "color": "#EAB839",
                          "enable": true,
                          "id": 3,
                          "pin": false,
                          "query": "@severity:WARN*",
                          "type": "lucene"
                      },
                      "4": {
                          "alias": "",
                          "color": "#7EB26D",
                          "enable": true,
                          "id": 4,
                          "pin": false,
                          "query": "@severity:INFO",
                          "type": "lucene"
                      },
                      "5": {
                          "alias": "",
                          "color": "#6ED0E0",
                          "enable": true,
                          "id": 5,
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
        .click(function() { if (!$(this).parent().hasClass("open")) openDropdownHandler.apply(this); }));
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

