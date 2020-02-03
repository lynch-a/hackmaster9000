function send_to_active_terminal(cmd) {
    var active_term = $("#terminal-container").find(".hm9k-term.active").first();

    if ($(active_term).length) {
      var tid = active_term.attr("id");
      console.log("sending binary for tool:  tid: " + tid + " | cmd: " + cmd);
      terminal_server.send_binary("s:"+tid+":"+cmd);
    } else {
      terminal_server.send('new_terminal', null);
    }
}

function schedule_or_run(tool_name, cmd) {
  var run_in_background = $("#"+tool_name+"-run-in-background").prop("checked");
  var dry_run = $("#"+tool_name+"-dry-run").prop("checked");

  var run_every_mins = 0;

  var run_every_toggle = $("#"+tool_name+"-run-every-toggle").prop("checked");
  if (run_every_toggle) {
    var run_every_mins_input = $("#"+tool_name+"-run-every").val();
    if (run_every_mins_input.length > 0) {
      run_every_mins = run_every_mins_input
    }
  }

  // what to do when it's backgrounded or scheduled
  if (run_in_background || run_every_mins > 0) {
    create_job(cmd, run_every_mins, run_in_background);
  } else {
    // experiment: run everything as a job
    // create_job(cmd, run_every_mins, false);
    // conclusion: DUMB

    if (dry_run) {
      send_to_active_terminal(cmd);
    } else {
      send_to_active_terminal(cmd + "\n");
    } 
  }
}

function create_job(cmd, run_every_minutes, background) {
  // if they  specified a repeat job, the job should not have a max number of runtimes by default
  var max_runtimes = "1";
  if (parseInt(run_every_minutes, 10) > 0) {
    max_runtimes = "0";
  }

  var add_job_event_data = {
    job_type: "TOOL",
    job_data: cmd,
    job_run_every: run_every_minutes.toString(),
    job_max_runtimes: max_runtimes,
    job_run_in_background: background
  };

  api_server.send('add-job', add_job_event_data);
}

// SETUP TERMINAL SERVER CONNECTION
var terminal_server = new TerminalEventsDispatcher("ws://"+window.location.hostname+":8081");

// SETUP API/INTERFACE SERVER CONNECTION
var api_server = new ApiEventsDispatcher("ws://"+window.location.hostname+":8082");

$(document).ready(function() {
  console.log("ready!");

  var is_refreshing = true;

  var terminal_height = 400; // in pixels

  var terminals = [];

  hterm.defaultStorage = new lib.Storage.Local();

  // authenticate to API server
  api_server.bind('open', function() {
    var api_token = $(".credential-div-please-dont-xss-me").attr("terminal-token");
    var uuid = $(".credential-div-please-dont-xss-me").attr("project-id");

    console.log("authenticating API ws connection");
    auth_event_data = {api_token: api_token, uuid: uuid};
    api_server.send('auth', auth_event_data);
  });


  // SETUP API ENDPOINT LISTENERS

  api_server.bind('add-scan-config', function(data) {
    var name = data["name"];
    var tool_name = data["tool_name"];
    var id = data["id"];

    // todo: xss here, doesn't sanitize name or id :^)
    // consider using an ERB to render the <option> ? is there a better way?
    var o = new Option(name, id);
    $(o).html(name);

    $(".load-saved-config[tool-name='"+tool_name+"']").append(o);
  });

  api_server.bind('notification', function(data) {    
    var message = data["message"];
    var type = data["type"]

    $.notify({
      // options
      message: message
    },{
      // settings
      type: type,
      placement: {
          from: "top",
          align: "right"
        },
    });
  });

  function update_or_insert_datatables_row(table_selector, row_selector, data_id) {
    var row_index = 0;
    var table = $(table_selector).last().DataTable();

    // get data for new row
    $.ajax({
        type: "GET",
        url: $(table.table().body()).attr('update-url') + data_id, // ex: "/projects/1/domains/" + "1"
        success: function (data) {
          // find the row (it may not exist)
          var row = table.row(row_selector);

          if (row.data()) { // row exists, remove it
            //console.log("found existing row, removing it");
            row_index = row.index(); // save the index, we will replace the index with new data
            row.remove().draw();
          } else {
            //console.log("adding new row...");
          }

          // add the new row
          row = $(table_selector).last().DataTable().row.add(
              $(data)[0] // a <tr>
            ).draw();    

          $(row).addClass(row_selector); // add the row selector to new row

          $(".selectable").selectable({ // make everything selectable that should be
            filter:'td',
            cancel: '.no-select'
          });


          // unbind/bind all host comment actions
          $('.host-comment').each(function(index) {
            $(this).unbind('submit');

            $(this).bind('submit', function(event) {
              // get comment
              var comment = $(this).find("textarea").val();
              var host_id = $(this).attr("data-host-id");

              // submit to api server
              new_host_comment_event_data = {id: host_id, comment: comment};
              api_server.send('new-host-comment', new_host_comment_event_data);

              event.preventDefault();
            });
          });

          // unbind/bind all domain comment actions
          $('.domain-comment').each(function(index) {
            $(this).unbind('submit');

            $(this).bind('submit', function(event) {
              // get comment
              var comment = $(this).find("textarea").val();
              var domain_id = $(this).attr("data-domain-id");

              // submit to api server
              new_domain_comment_event_data = {id: domain_id, comment: comment};
              api_server.send('new-domain-comment', new_domain_comment_event_data);

              event.preventDefault();
            });
          });
        }
    });          
  }

  api_server.bind('update-domain', function(data) {
    var dnsrecord_id = data["id"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#domain-table', // table selector
    //  ".domain-row-"+dnsrecord_id, // row selector (doesn't have to exist, creates if not)
    //  dnsrecord_id // the id it should fetch to update the row
    //);

    if (is_refreshing)
      domain_dtable.ajax.reload(null, false);

  });

  api_server.bind('update-host', function(data) {
    var host_id = data["id"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#host-table', // table selector
    //  ".host-row-"+host_id, // row selector (doesn't have to exist, creates if not)
    //  host_id // the id it should fetch to update the row
    //);
    if (is_refreshing)
      host_dtable.ajax.reload(null, false);
  });

  api_server.bind('add-dirsearch', function(data) {
    var dnsrecord_id = data["dnsrecord_id"];
    var hostname = data["hostname"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#domain-table', // table selector
    //  ".domain-row-"+dnsrecord_id, // row selector (doesn't have to exist, creates if not)
    //  dnsrecord_id // the id it should fetch to update the row
    //);
    if (is_refreshing)
    domain_dtable.ajax.reload(null, false);

    $.notify({
        message: 'Dirsearch results for ' + hostname + ' have been added/updated.',
        url: '#domains-'+dnsrecord_id,
      // target: '_blank'
      },{
        type: 'info'
      });
  });

  api_server.bind('add-trigger', function(data) {
    var trigger_id = data["id"];
    var trigger_name = data["name"];

    // update row in datatable
    update_or_insert_datatables_row(
      '#trigger-table', // table selector
      ".trigger-row-"+trigger_id, // row selector (doesn't have to exist, creates if not)
      trigger_id // the id it should fetch to update the row
    );

    $.notify({
        message: 'Trigger ' + trigger_name + ' has been added/updated.',
        url: '#triggers-'+trigger_id,
      // target: '_blank'
      },{
        type: 'info'
      });
  });

  api_server.bind('add-service', function(data) {
    // todo.. update that a service was discovered
    console.log("should have added service!");
  });

  api_server.bind('update-application', function(data) {
    var web_application_id = data["id"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#web-application-table', // table selector
    //  ".web-application-row-"+web_application_id, // row selector (doesn't have to exist, creates if not)
    //  web_application_id // the id it should fetch to update the row
    //);
    if (is_refreshing)
    web_application_dtable.ajax.reload(null, false);

  });

  api_server.bind('new-page', function(data) {
    if (is_refreshing)
    web_application_dtable.ajax.reload(null, false);
  });


  api_server.bind('set-web-application-risk', function(data) {
    // find host_id in host page, update its corresponding colors
    var web_application_id = data["id"];
    var risk = data["risk"];

    var colors = {
      "0": "table-secondary",
      "1": "table-info",
      "2": "table-warning",
      "3": "table-danger",
    };

    var color = colors[risk];

    $("#web-application-heading-"+web_application_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    // find the domain in the datatable
    $("#web-application-heading-"+web_application_id).addClass(color);


    // look for this application in the domains view
    $(".domain-web-application-"+web_application_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    $(".domain-web-application-"+web_application_id).addClass(color);


    // look for application in the hosts view
    $(".host-web-application-"+web_application_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    $(".host-web-application-"+web_application_id).addClass(color);

    // look for hosts in the applications view
    $(".web-application-host-"+web_application_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });

    $(".web-application-host-"+web_application_id).addClass(color);
  });


  api_server.bind('set-domain-risk', function(data) {
    // find host_id in host page, update its corresponding colors
    var domain_id = data["id"];
    var risk = data["risk"];

    var colors = {
      "0": "table-secondary",
      "1": "table-info",
      "2": "table-warning",
      "3": "table-danger",
    };

    var color = colors[risk];

    $("#domain-heading-"+domain_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    // find the domain in the datatable
    $("#domain-heading-"+domain_id).addClass(color);

    // look for this domain in the hosts view
    $(".host-domain-"+domain_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });

    // look for this domain in the web app view
    $(".web-application-domain-"+domain_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    
    $(".host-domain-"+domain_id).addClass(color);
    $(".web-application-domain-"+domain_id).addClass(color);


    // set the value of the select
    $("#domain-heading-"+domain_id).find(".domain-set-risk").val(risk);
  });

  api_server.bind('hide-web-application', function(data) {
    // find host_id in host page, update its corresponding colors
    var id = data["id"];

    // refresh the web app dtable, it is hidden now
    web_application_dtable.ajax.reload(null, false);

    // but also refresh the domain tab, because it shows web apps and needs to be updated
    domain_dtable.ajax.reload(null, false);
  });

  api_server.bind('refresh-tables', function(data) {
    if (is_refreshing) {
      web_application_dtable.ajax.reload(null, false);
      domain_dtable.ajax.reload(null, false);
      host_dtable.ajax.reload(null, false);
      dns_record_dtable.ajax.reload(null, false);

    }
  });

  api_server.bind('refresh-jobs', function(data) {
    job_dtable.ajax.reload(null, false);
  });


  api_server.bind('set-host-risk', function(data) {
    // find host_id in host page, update its corresponding colors
    var host_id = data["id"];
    var risk = data["risk"];

    var colors = {
      "0": "table-secondary",
      "1": "table-info",
      "2": "table-warning",
      "3": "table-danger",
    };

    var color = colors[risk];

    // strip off current color
    $("#host-heading-"+host_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    // add the new color
    $("#host-heading-"+host_id).addClass(color);

    // look for this host in the domains view
    $(".domain-host-"+host_id).removeClass(function (index, className) {
      return (className.match (/(^|\s)table-\S+/g) || []).join(' ');
    });
    $(".domain-host-"+host_id).addClass(color);

    // set the value of the select
    $("#host-heading-"+host_id).find(".host-set-risk").val(risk);
  });

  api_server.bind('unpause-trigger', function(data) {
    // find host_id in host page, update its corresponding colors
    var trigger_id = data["id"];
    var trigger_name = data["name"]

    // update row in datatable
    update_or_insert_datatables_row(
      '#trigger-table', // table selector
      ".trigger-row-"+trigger_id, // row selector (doesn't have to exist, creates if not)
      trigger_id // the id it should fetch to update the row
    );

    $.notify({
        message: 'Auto Scan ' + trigger_name + ' has been enabled.',
        url: '#triggers-'+trigger_id
      },{
        type: 'info'
      });
  });

  api_server.bind('pause-trigger', function(data) {
    // find host_id in host page, update its corresponding colors
    var trigger_id = data["id"];
    var trigger_name = data["name"]

    // update row in datatable
    update_or_insert_datatables_row(
      '#trigger-table', // table selector
      ".trigger-row-"+trigger_id, // row selector (doesn't have to exist, creates if not)
      trigger_id // the id it should fetch to update the row
    );

    $.notify({
        message: 'Auto Scan ' + trigger_name + ' has been disabled.',
        url: '#triggers-'+trigger_id
      },{
        type: 'info'
      });
  });

  api_server.bind('foreground-trigger', function(data) {
    // find host_id in host page, update its corresponding colors
    var trigger_id = data["id"];
    var trigger_name = data["name"]

    // update row in datatable
    update_or_insert_datatables_row(
      '#trigger-table', // table selector
      ".trigger-row-"+trigger_id, // row selector (doesn't have to exist, creates if not)
      trigger_id // the id it should fetch to update the row
    );

    $.notify({
        message: 'Trigger ' + trigger_name + ' has been foregrounded.',
        url: '#triggers-'+trigger_id
      },{
        type: 'info'
      });
  });

  api_server.bind('background-trigger', function(data) {
    // find host_id in host page, update its corresponding colors
    var trigger_id = data["id"];
    var trigger_name = data["name"]

    // update row in datatable
    update_or_insert_datatables_row(
      '#trigger-table', // table selector
      ".trigger-row-"+trigger_id, // row selector (doesn't have to exist, creates if not)
      trigger_id // the id it should fetch to update the row
    );

    $.notify({
        message: 'Trigger ' + trigger_name + ' has been backgrounded.',
        url: '#triggers-'+trigger_id
      },{
        type: 'info'
      });
  });

  api_server.bind('web-application-comment', function(data) {
    var web_application_id = data["id"];
    var web_application_name = data["web_application_comment"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#web-application-table', // table selector
    //  ".web-application-row-"+web_application_id, // row selector (doesn't have to exist, creates if not)
    //  web_application_id // the id it should fetch to update the row
    //);

    web_application_dtable.ajax.reload(null, false);

    $.notify({
        message: 'Comment for Web Application ' + web_application_name + ' has been added/updated.',
        url: '#web-application-'+web_application_id
      },{
        type: 'info'
      });
  });

  api_server.bind('new-domain-comment', function(data) {
    var dnsrecord_id = data["id"];
    var dns_name = data["dns_name"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#domain-table', // table selector
    //  ".domain-row-"+dnsrecord_id, // row selector (doesn't have to exist, creates if not)
    //  dnsrecord_id // the id it should fetch to update the row
    //);

    domain_dtable.ajax.reload(null, false);

    $.notify({
        message: 'Comment for domain ' + dns_name + ' has been added/updated.',
        url: '#domains-'+dnsrecord_id
      },{
        type: 'info'
      });
  });

  api_server.bind('new-host-comment', function(data) {
    var host_id = data["id"];
    var ip = data["ip"];

    // update row in datatable
    //update_or_insert_datatables_row(
    //  '#host-table', // table selector
    //  ".host-row-"+dnsrecord_id, // row selector (doesn't have to exist, creates if not)
    //  dnsrecord_id // the id it should fetch to update the row
    //);

    host_dtable.ajax.reload(null, false);


    $.notify({
        message: 'Comment for host ' + ip + ' has been added/updated.',
        url: '#hosts-'+host_id
      },{
        type: 'info'
      });
  });

  terminal_server.bind('open', function(data) {
    // auth should be the first thing that the socket does when it opens
    console.log("should have sent auth data?");

    var ttoken = $(".credential-div-please-dont-xss-me").attr("terminal-token");
    var uuid = $(".credential-div-please-dont-xss-me").attr("project-id");

    auth_event_data = {terminal_token: ttoken, uuid: uuid};
    terminal_server.send('auth', auth_event_data);
    console.log("bound open action...");
  });

  function initiate_terminal(tid, decorateTo) {
    var term = new hterm.Terminal();
    terminals[tid] = term;

    term.onTerminalReady = function() {
        // setup hTerm stuff:
        console.log("terminal initiated");

        $(decorateTo).addClass("initialized");

        const io = term.io.push();

        io.onVTKeystroke = (str) => {
            terminal_server.send_binary("s:"+tid+":"+str);
        };

        io.sendString = (str) => {
            terminal_server.send_binary("s:"+tid+":"+str);
        };

        io.onTerminalResize = (columns, rows) => {
            var resize_event_data = {tid: tid, row: rows, col: columns};
            terminal_server.send('resize', resize_event_data);
        };
    }

    term.decorate(decorateTo);
    term.installKeyboard();
    //term.setCursorPosition(0, 0);
    term.setCursorVisible(true);
    term.prefs_.set('ctrl-c-copy', true);
    term.prefs_.set('ctrl-v-paste', true);
    term.prefs_.set('use-default-window-copy', true);
    term.prefs_.set('font-size', 14);

    setTimeout(function() {
      // hide all of the terminals - this will be after they've loaded because of settimeout
      $(".terminals-go-here").find(".tab-pane.active").each(function() { $(this).removeClass("active"); $(this).removeClass("show"); });
      // set all of the tabs as inactive
      $("#terminal-container").find(".terminal-nav-link").each(function() { console.log("setting tab to inactive"); $(this).removeClass("active"); $(this).removeClass("show"); });


      // make the last terminal active
      var last_terminal = $(".terminals-go-here").children().last();
      last_terminal.addClass("active");
      last_terminal.addClass("show");
      // and make its tab active too
      var associated_tab = $(".terminal-tabs-go-here").find("#tab-"+last_terminal.attr('id'));
      associated_tab.addClass("active");
      associated_tab.addClass("show");
    }, 700)

  }

  function insert_terminal_divs(tid) {
    $.get('/request_terminal_tab/'+tid, function(data){
      // set all of the terminal tabs to inactive
      //$("#terminal-container").find(".terminal-nav-link").each(function() { console.log("setting tab to inactive"); $(this).removeClass("active"); $(this).removeClass("show"); });

      $(data, $("#terminal-container")[0].ownerDocument).appendTo(".terminal-tabs-go-here");
    });

    // request the shell html partial for this terminal and load it onto the page
    $.get('/request_terminal/'+tid, function(data){
      var term_div = $(data, $("#terminal-container")[0].ownerDocument).appendTo(".terminals-go-here");

      // tell hterm to decorate to the div we made
      initiate_terminal(tid, $(".terminals-go-here").find(".hm9k-term[id='"+tid+"']")[0]);
      
      // tell the backend to attach to the terminal
      connect_terminal_event_data = {tid: tid};
      terminal_server.send('connect_terminal', connect_terminal_event_data);
    });
  }


  lib.init(function() {
    // setup primary websocket connection here, establish message handlers like...

    terminal_server.bind('new_terminal', function(data) {
      var tid = data["tid"];

      insert_terminal_divs(tid);
    });

    terminal_server.bind('existing_terminals', function(data) {
      var terminals = data["terminals"];

      $.each(terminals, function(index, terminal) {
        var tid = terminal["tid"];

        insert_terminal_divs(tid);
      })
    });

    // got stdout event from server
    terminal_server.bind('stdout', function(data) {
      //console.log("writing to term... tid: " + data["tid"]);
      //console.log("writing to term... data: " + data["msg"]);
      term = terminals[data["tid"]]; // which terminal should it write to?
      term.io.print(data["msg"]);
      //term.io.print(new TextDecoder("utf-8").decode(data));
    });

    terminal_server.bind("job-started", function(data) {
      message = data["message"]
      // received message from websocket to change the color of a host
      $.notify({
        // options
        message: message
      },{
        // settings
        type: "danger",
        placement: {
            from: "top",
            align: "center"
          }
      });
    });
  });

  function rand_str7() {
    return ""+Math.random().toString(36).substring(7)
  }


  $('body').on('click', '.send-to-autoscan', function() {
    var tool_name = $(this).attr("data-tool-name");
    var replacer_str = $(this).attr("data-target-replacer");


    // replace the target parameter with an autoscan-friendly text
      var save = $("#"+tool_name+"-target").val();
    $("#"+tool_name+"-target").val(replacer_str);

    // round up the boys
    var cmd = window["generate_"+tool_name+"_command"]("%rand7%");

    // switch to autoscan window with info filled out
    var save = $("#trigger-shell-cmd").val;
    $("#trigger-shell-cmd").val(cmd);
    $('.nav-link[href="#autoscan"]').tab('show');

    // clean up
    $("#"+tool_name+"-target").val(save);
  });
  

  function generate_wfuzz_command() {
    var cmd = "wfuzz -v -c --interact";

    var output_name = "wfuzz-"+Math.random().toString(36).substring(7)+".json,json"
    cmd += " -f " + output_name;

    if ($("#wfuzz-toggle-concurrent").prop("checked")) {
      cmd += " -t " + $("#wfuzz-concurrent").val();
    }

    if ($("#wfuzz-toggle-delay-between-requests").prop("checked")) {
      cmd += " -s " + $("#wfuzz-delay-between-requests").val();
    }

    if ($("#wfuzz-toggle-follow-redirect").prop("checked")) {
      cmd += " -L " + $("#wfuzz-follow-redirect").val();
    }

    //if ($("#wfuzz-toggle-delay-between-requests").prop("checked")) {
    //  cmd += " --req-delay " + $("#wfuzz-delay-between-requests").val();
    //}

    //if ($("#wfuzz-toggle-max-connect-time").prop("checked")) {
    //  cmd += " --con-delay " + $("#wfuzz-max-connect-time").val();
    //}

    if ($("#wfuzz-default-script").prop("checked")) {
      cmd += " -A";
    }

    if ($("#wfuzz-scan-mode").prop("checked")) {
      cmd += " -Z";
    }

    // fuzz all parameters, no FUZZ needed - todo - this doesn't seem to work in wfuzz?
    if ($("#wfuzz-alltype").prop("checked")) {
      cmd += " -V allvars";
    }

    // dropdown

    target = $("#wfuzz-method").val();
    if (target != "") {
      cmd += " -X " + target;
    }

    // dropdown
    target = $("#wfuzz-payload").val();
    if (target != "") {
      cmd += " -z file," + target;
    }

    if ($("#wfuzz-toggle-cookie").prop("checked")) {
      if ($("#wfuzz-cookie").val() != "") {
        cmd += " -b '" + $("#wfuzz-cookie").val() + "'";
      }
    }

    if ($("#wfuzz-toggle-postdata").prop("checked")) {
      if ($("#wfuzz-postdata").val() != "") {
        cmd += " -d '" + $("#wfuzz-postdata").val() + "'";
      }
    }

    if ($("#wfuzz-toggle-headers").prop("checked")) {
      if ($("#wfuzz-header").val() != "") {
        console.log("headers: " + $("#wfuzz-headers").val());
        console.log("----");
        var replaced_headers = $("#wfuzz-headers").val().replace(/(\r\n|\n|\r)/gm,";");

        cmd += " -H '" + replaced_headers + "'";
      }
    }

    // 
    //if ($("#wfuzz-toggle-basic-auth").prop("checked")) {
    //  cmd += " --basic";
    //}

    // dropdown for "show by: code, length, word, chars" and
    // "hide by [[code:]]" [input]
    if ($("#wfuzz-toggle-hide-by").prop("checked")) {
      cmd += " --h" + $("#wfuzz-hide-by").val();
      cmd += " " + $("#wfuzz-hide-by-value").val();
    }

    // dropdown for "show by: code, length, word, chars" and
    // "hide by [[code:]]" [input]
    if ($("#wfuzz-toggle-show-by").prop("checked")) {
      cmd += " --s" + $("#wfuzz-show-by").val();
      cmd += " " + $("#wfuzz-show-by-value").val();
    }

    //cmd += " --field r"

    var target = $("#wfuzz-target").val();
    if (target != "") {
      cmd += " " +target;
    }

    return cmd;
  }

  $("#wfuzz-run").click(function() {
    
    //// hooooolll up'
    // before dirsearch is run, we want so support multiple targets
    // we save and split the target list by " "
    // for each target, we set the target box
    // and schedule_or_run
    var target = $("#wfuzz-target").val().trim();
    var cmd = generate_wfuzz_command();
    schedule_or_run("wfuzz", cmd);
  });

/////////////////////////// gitgot -v

  function generate_gitgot_command() {
    var cmd = "gitgot";

    var organization_exists = false;
    var organization = $("#gitgot-organization").val();

    if (organization != "") {
      organization_exists = true;
    }

    var search = $("#gitgot-search").val();
    if (search != "") {
      if (organization_exists) {
        cmd += " -q 'org:" + organization + " " + search + "'";
      } else {
        cmd += " -q '" + search + "'";
      }
    }

    if ($("#gitgot-toggle-regexlist").prop("checked")) {
      var regex_list = $("#gitgot-regexlist").val();
      cmd += " -f " + regex_list;
    }

    if ($("#gitgot-toggle-state").prop("checked")) {
      var state = $("#gitgot-state").val();
      cmd += " -r " + state;
    }
    return cmd;
  }

  $("#gitgot-run").click(function() {
    var cmd = generate_gitgot_command();
    schedule_or_run("gitgot", cmd);
  });


  function generate_pwn_vnc_command() {
    var cmd = "pwnVNC";

    var target = $("#pwn-vnc-target").val();
    if (target != "") {
      cmd += " "+ target;
    }

    var port = $("#pwn-vnc-port").val();
    if (port != "") {
        cmd += " " + port;
    }

    return cmd;
  }

  $("#pwn-vnc-run").click(function() {
    
    //// hooooolll up'
    // before check-vnc is run, we want so support multiple targets
    // we save and split the target list by " "
    // for each target, we set the target box
    // and schedule_or_run
    var target = $("#pwn-vnc-target").val().trim();

    var targets = target.split(" ");

    if (targets.length > 1) {
      // definitely run as BG job. EDIT: maybe no
      //$("#dirsearch-run-in-background").prop('checked', true);

      for(var i = 0; i < targets.length; i++) {
        $("#pwn-vnc-target").val(targets[i]);
        if ($("#pwn-vnc-target").val().length > 1) { // ignore empty target problems
          var cmd = generate_pwn_vnc_command();
          schedule_or_run("pwn-vnc", cmd);
        }
      }
    } else {
      var cmd = generate_pwn_vnc_command();
      schedule_or_run("pwn-vnc", cmd);
    }
  });

  //////
  

  function generate_rip_git_command() {
    var cmd = "rip-git";

    var target = $("#rip-git-target").val();
    if (target != "") {
      cmd += " -m -o ./ -u "+ target;
    }

    return cmd;
  }

  $("#rip-git-run").click(function() {
    
    var cmd = generate_rip_git_command();
    schedule_or_run("rip-git", cmd);
  });

  function generate_bounty_targets_data_cmd() {
    cmd = "curl https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/domains.txt -o btd-domains.txt"
    return cmd;
  }

  $("#bounty-targets-data-run").click(function() {
    var cmd = generate_bounty_targets_data_cmd();
    schedule_or_run("bounty-targets-data", cmd);
  });

  $("#subbrute-run").click(function() {
      var cmd = "subbrute.py -p";

      var output_name = $("#subbrute-output").val();
      if (output_name != "") {
        output_name = output_name.replace(/\%target\%/g, $("#subbrute-target").val());

          cmd += " -o subbrute-"+output_name+".csv";
      }

      var target = $("#subbrute-target").val();
      if (target != "") {
          cmd += " "+target;
      }

      send_to_active_terminal(cmd + "\n");
  });

  function generate_wpscan_command() {
    var cmd = "wpscan";

    var target_url = $("#wpscan-target").val();
    if(target_url.length > 0) {
      cmd += " --url " + target_url;
    }

    var stealthy = $("#wpscan-stealthy").prop("checked");
    if(stealthy) {
      cmd += " --stealthy";
    }

    // generate enumerate option value
    var enumerate_options = [];

    var enumerate_all_plugins = $("#wpscan-enumerate-ap").prop("checked");
    if (enumerate_all_plugins)
      enumerate_options.push("ap");

    var enumerate_users = $("#wpscan-enumerate-users").prop("checked");
    if (enumerate_users)
      enumerate_options.push("users");

    var enumerate_vulnerable_plugins = $("#wpscan-enumerate-vp").prop("checked");
    if (enumerate_vulnerable_plugins)
      enumerate_options.push("vp");

    var enumerate_vulnerable_themes = $("#wpscan-enumerate-vt").prop("checked");
    if (enumerate_vulnerable_themes)
      enumerate_options.push("vt");

    if (enumerate_options.length > 0) {
      cmd += " --enumerate " + enumerate_options.join(",");
    }

    return cmd
  }

  $("#wpscan-run").click(function () {
    var cmd = generate_wpscan_command();

    schedule_or_run("wpscan", cmd);
  });

  function generate_xtreme_scraper_command() {
    var cmd = "xtreme-scraper";

    var output = $("#xtreme-scraper-output").val();
    if (output != "") {
        cmd += " -o=" + output;
    }

    var pages = $("#xtreme-scraper-pages").val();
    if (pages != "") {
        cmd += " -p="+ pages;
    }

    return cmd;
  }

  $("#xtreme-scraper-run").click(function() {
    var cmd = generate_xtreme_scraper_command();
    schedule_or_run("xtreme-scraper", cmd);
  });

  // -----

  function generate_top_minecraft_command() {
    var cmd = "topminecraftservers";

    var output = $("#top-minecraft-output").val();
    if (output != "") {
        cmd += " -o=" + output;
    }

    var pages = $("#top-minecraft-pages").val();
    if (pages != "") {
        cmd += " -p="+ pages;
    }

    return cmd;
  }

  $("#top-minecraft-run").click(function() {
    var cmd = generate_top_minecraft_command();
    schedule_or_run("top-minecraft", cmd);
  });

  function generate_sqlmap_command() {
    var cmd = "sqlmap";

    var target = $("#sqlmap-target").val();
    if (target != "") {
        cmd += " -u \"" + target + "\"";
    }

    var level = $("#sqlmap-level").val();
    if (level != "") {
        cmd += " --level=" + level;
    }

    var risk = $("#sqlmap-risk").val();
    if (risk != "") {
        cmd += " --risk=" + risk;
    }

    var test_params = $("#sqlmap-params-included").val();
    if (test_params != "") {
        cmd += " -p \"" + test_params + "\"";
    }

    var cookies = $("#sqlmap-cookies").val();
    if (cookies != "") {
        cmd += " --cookie=\"" +cookies + "\"";
    }

    return cmd;
  }

  $("#sqlmap-run").click(function() {
    var cmd = generate_sqlmap_command();
    schedule_or_run("sqlmap", cmd);
  });

  function generate_crtsh_command() {
    var cmd = "curl 'https://crt.sh/?q=";

    var target = $("#crtsh-target").val();
    if (target != "") {
        cmd += encodeURI(target);
    }

    cmd += "&output=json'"


    cmd += " -o \"crtsh-" + Math.random().toString(36).substring(7) + ".json\"";
    

    return cmd;
  }

  $("#crtsh-run").click(function() {
      var cmd = generate_crtsh_command();

      schedule_or_run("crtsh", cmd);
  });

  function generate_breach_compilation_command() {

  }

  $("#breach-compilation-run").click(function() {
      var cmd = "/BreachCompilation/query.sh ";

      var target_name = $("#breach-compilation-target").val();
      if (target_name != "") {
          cmd += target_name;
      }

      send_to_active_terminal(cmd + "\n");
  });

  $("#hashcat-run").click(function() {
      var cmd = "hashcat";

      var attack_mode = $("#hashcat-attack-mode").val();
      if (attack_mode != "") {
          cmd += " -a " + attack_mode;
      }

      var hash_mode = $("#hashcat-hash-mode").val();
      if (hash_mode != "") {
          cmd += " -m " + hash_mode;
      }

      var target_hash = $("#hashcat-target-hash").val();
      if (target_hash != "") {
          cmd += " " + target_hash;
      }

      var wordlist = $("#hashcat-wordlist").val();
      if (wordlist != "") {
          cmd += " " + wordlist
      }

      var rule_file = $("#hashcat-rule-file").val();
      if (rule_file != "") {
          cmd += " -r " +rule_file
      }

      send_to_active_terminal(cmd + "\n");
  });

  $(".clear-data").click(function() {
      $.get("/clear", function( data ) {
        location.reload();
      });
  });



  // delete the console from the ui, send a message to the server that the tid should be killed
  $('body').on('click', '.close-terminal', function() {
    var tid = $(this).attr("tid"); // get TID from button clicked

    // put this back 
    
    if ($(".footer")[0].style.height == "35%") {
      $(".footer").removeAttr("style");
    } else {
      //$(".footer").css("height", "35%");
    }
    

    // todo: 
    // get a handle to the terminal to the right of this terminal

    // no handle? try the terminal to the left

    // got a handle? make that terminal visible.

    // no handle? minimize the terminal pane.


    // delete terminals from main terminal view
    $('.hm9k-term[id="'+tid+'"]').remove();

    // delete terminals in the terminal navbar
    $('.terminal-nav-link[id="tab-'+tid+'"]').remove();

    // send terminal-close message
    close_terminal_event_data = {tid: tid};
    terminal_server.send('close-terminal', close_terminal_event_data);
  });


  $('body').on('click', '.define-application', function(e) {
    // make input box to define application name
    var service_id = $(this).attr("service-id");
    var new_app_form = '<form class="new-application" service-id="'+service_id+'">' +
      '<input type="text" name="app-name" class="form-control form-control-sm" size="10" placeholder="New web app name">' +
    '</form>';

    $(this).parent().append(new_app_form)
    $(this).remove();
    return false;
  });

  $('body').on('submit', '.new-application', function(e) {
    // submit new app to api server
    var service_id = $(this).attr("service-id");
    var name = $(this).find("input[name='app-name']").val()

    console.log("making new app")

    new_application_event_data = {service_id: service_id, name: name};
    api_server.send('new-application', new_application_event_data);
    
    e.preventDefault();
    return false;
  });

  function SelectSelectableElement (selectableContainer, elementsToSelect)
  {
      // add unselecting class to all elements in the styleboard canvas except the ones to select
      $(".ui-selected", selectableContainer).not(elementsToSelect).removeClass("ui-selected").addClass("ui-unselecting");
      
      // add ui-selecting class to the elements to select
      $(elementsToSelect).not(".ui-selected").addClass("ui-selecting");

      // trigger the mouse stop event (this will select all .ui-selecting elements, and deselect all .ui-unselecting elements)
      selectableContainer.data("ui-selectable")._mouseStop(null);
  }

  /////// DOMAIN TABLE BELOW
  var domain_dtable = $('#domain-table').DataTable( {
    fnDrawCallback: function() {
      $("#domain-table thead").remove();
    },
    lengthMenu: [ [10, 50, 100, -1], [10, 50, 100, "All"] ],
    deferRender:    false,
    autoWidth:      false,  
    lengthChange:   true,
    processing: true,
    serverSide: true,
    "oLanguage": {
      "sLengthMenu": "_MENU_",
      "sSearch": ""
    },
    "ajax":{
      url : current_page_no_hash()+"/domains", // json datasource
      type: "POST",
      error: function() {
        console.log("Domain datatable failed to load");
      }
    },
    paging: true,
    columns: [
      { "data": "card", className: "domain" }
    ],
    buttons: [
          {
          text: 'TLDs only',
          action: function () {
            //SelectSelectableElement($("#domain-table"), $("td"));
            domain_dtable.search('tld:true').draw();;
          }
      },
      {
          text: 'Select all',
          action: function () {
            //SelectSelectableElement($("#domain-table"), $("td"));
            $("#domain-table").find("td").each(function(index) {
              if ($(this).hasClass("noselect")) { return true; }
              $(this).addClass("ui-selected");
              $("#domain-table").data("ui-selectable")._mouseStop(null);
            });
          }
      },
      {
          text: 'Unselect all',
          action: function () {
            $("#domain-table").find("td").each(function(index) {
              $(this).removeClass("ui-selected");
              $("#domain-table").data("ui-selectable")._mouseStop(null);
            });
          }
      },
      {
        extend: 'collection',
        text: 'Send to',
        buttons: [
          {
            text: 'nmap', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-nmap"]').tab('show');

              var targets = "";

              $(".domain.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#nmap-target").val(targets.trim());
            }
          },
          {
            text: 'dig', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-dig"]').tab('show');

              var targets = "";

              $(".domain.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#dig-target").val(targets.trim());
            }
          },
          {
            text: 'dnscan', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-dnscan"]').tab('show');

              var targets = "";

              $(".domain.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#dnscan-target").val(targets.trim());
            }
          },
          {
            text: 'screenshot2', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-screenshot2"]').tab('show');

              var targets = "";

              $(".domain.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#screenshot2-target").val(targets.trim());
            }
          }
        ]
      }
    ],
    initComplete: function () {
      domain_dtable.buttons().container().appendTo( $('#domain-table_wrapper .row:eq(0)') );
    }
  });

  /////// HOST TABLE BELOW
  var host_dtable = $('#host-table').DataTable( {
    fnDrawCallback: function() {
      $("#host-table thead").remove();
    },
    deferRender:    false,
    autoWidth:      false,  
    processing: true,
    serverSide: true,
    searching: true,
    "oLanguage": {
      "sLengthMenu": "_MENU_",
      "sSearch": ""
    },
    "ajax": {
      url: current_page_no_hash()+"/hosts", // json datasource
      type: "POST",
      error: function() {
        console.log("Host datatable failed to load");
      }
    },
    paging: true,
    columns: [
      { "data": "card", className: "host" }
    ],
    buttons: [
      {
        text: 'Select all',
        action: function () {
          //SelectSelectableElement($("#domain-table"), $("td"));
          $("#host-table").find("td").each(function(index) {
            if ($(this).hasClass("noselect")) { return true; }
            $(this).addClass("ui-selected");
            $("#host-table").data("ui-selectable")._mouseStop(null);
          });
        }
      },
      {
        text: 'Unselect all',
        action: function () {
          $("#host-table").find("td").each(function(index) {
            $(this).removeClass("ui-selected");
            $("#host-table").data("ui-selectable")._mouseStop(null);
          });
        }
      },
      {
        extend: 'collection',
        text: 'Send to',
        buttons: [
          {
            text: 'nmap', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-nmap"]').tab('show');

              var targets = "";

              $(".host.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#nmap-target").val(targets.trim());
            }
          },
          {
            text: 'screenshot2', action: function() {
              //$('.nav-pills a[href="#tools"]').tab('show');
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-screenshot2"]').tab('show');
              //$('.nav-tabs a[href="#tab-screenshot2"]').tab('show');

              var targets = "";

              $(".host.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              console.log(targets);

              $("#screenshot2-target").val(targets.trim());
            }
          },
          {
            text: 'testssl', action: function() {
              //$('.nav-pills a[href="#tools"]').tab('show');
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-testssl"]').tab('show');
              //$('.nav-tabs a[href="#tab-screenshot2"]').tab('show');

              var targets = "";

              $(".host.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              console.log(targets);

              $("#testssl-target").val(targets.trim());
            }
          }
        ]
      }
    ],
    initComplete: function () {
      host_dtable.buttons().container().appendTo( $('#host-table_wrapper .row:eq(0)') );
    }
  });

/////// DNS Record TABLE BELOW
var dns_record_dtable = $('#dns-record-table').DataTable( {
  fnDrawCallback: function() {
    $("#dns-record-table thead").remove();
  },
  deferRender:    false,
  autoWidth:      false,  
  processing: true,
  serverSide: true,
  searching: true,
  "oLanguage": {
    "sLengthMenu": "_MENU_",
    "sSearch": ""
  },
  "language": {
    "searchPlaceholder": "Filter by domain name"
  },
  "ajax": {
    url: current_page_no_hash()+"/dns_records", // json datasource
    type: "POST",
    error: function() {
      console.log("DNS Record datatable failed to load");
    }
  },
  paging: true,
  columns: [
    { "data": "card", className: "domain" }
  ],
  buttons: [
    {
      text: 'Select all',
      action: function () {
        $("#dns-record-table").find("td").each(function(index) {
          if ($(this).hasClass("noselect")) { return true; }
          $(this).addClass("ui-selected");
          $("#dns-record-table").data("ui-selectable")._mouseStop(null);
        });
      }
    },
    {
      text: 'Unselect all',
      action: function () {
        $("#dns-record-table").find("td").each(function(index) {
          $(this).removeClass("ui-selected");
          $("#dns-record-table").data("ui-selectable")._mouseStop(null);
        });
      }
    }
  ],
  initComplete: function () {

  }
});

   /////// WEB APP TABLE BELOW
  var web_application_dtable = $('#web-application-table').DataTable( {
    fnDrawCallback: function() {
      $("#web-application-table thead").remove();
    },
    "oLanguage": {
      "sLengthMenu": "_MENU_",
      "sSearch": ""
    },
    "language": {
      "searchPlaceholder": ""
    },
    lengthMenu: [ [10, 50, 100, -1], [10, 50, 100, "All"] ],
    deferRender:    false,
    autoWidth:      false,  
    lengthChange:   true,
    processing: true,
    serverSide: true,
    "ajax":{
      url: (current_page_no_hash()+"/web_applications"), // json datasource
      type: "POST",
      error: function() {
        console.log("Web app datatable failed to load");
      }
    },
    paging: true,
    columns: [
      { "data": "card", className: "web-application" }
    ],
    buttons: [
    {
        text: 'Select all',
        action: function () {
          //SelectSelectableElement($("#domain-table"), $("td"));
          $("#web-application-table ").find("td").each(function(index) {
            if ($(this).hasClass("noselect")) {return true;}
            $(this).addClass("ui-selected");
            $("#web-application-table").data("ui-selectable")._mouseStop(null);
          });

        }
    },
    {
        text: 'Unselect all',
        action: function () {
          $("#web-application-table").find("td").each(function(index) {
            $(this).removeClass("ui-selected");
            $("#web-application-table").data("ui-selectable")._mouseStop(null);
          });
        }
    },
      {
        extend: 'collection',
        text: 'Send to',
        buttons: [
          {
            text: 'dirsearch', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-dirsearch"]').tab('show');

              var targets = "";

              $(".web-application.ui-selected").each(function() {
                targets += $(this).find(".card").attr("target") + " ";
              });

              $("#dirsearch-target").val(targets.trim());
            }
          },
          {
            text: 'dnscan', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-dirsearch"]').tab('show');

              var targets = "";

              $(".web-application.ui-selected").each(function() {
                targets += $(this).find(".card").attr("domain") + " ";
              });

              $("#dnscan-target").val(targets.trim());
            }
          },
          {
            text: 'wayback-machine-scraper', action: function() {
              //$('.nav-pills a[href="#tools"]').tab('show');
              //$('.nav-tabs a[href="#tab-nmap"]').tab('show');
            }
          },
          {
            text: 'screenshot2', action: function() {
              $('.nav-link[href="#tools"]').tab('show');
              $('.nav-link[href="#tab-screenshot2"]').tab('show');

              var targets = "";

              $(".web-application.ui-selected").each(function() {
                targets += $(this).find(".card").attr("domain") + " ";
              });

              $("#screenshot2-target").val(targets.trim());
            }
          }
        ]
      }
    ],
    initComplete: function () {
      web_application_dtable.buttons().container().appendTo( $('#web-application-table_wrapper .row:eq(0)') );
    }
  });

 /////// JOB TABLE BELOW
var job_dtable = $('#job-table').DataTable( {
  fnDrawCallback: function() {
    $("#job-table thead").remove();
  },
  lengthMenu: [ [10, 50, 100, -1], [10, 50, 100, "All"] ],
  deferRender:    false,
  autoWidth:      false,  
  lengthChange:   true,
  processing: true,
  serverSide: true,
  "ajax":{
    url: (current_page_no_hash()+"/jobs"), // json datasource
    type: "POST",
    error: function() {
      console.log("job datatable failed to load");
    }
  },
  paging: true,
  columns: [
    { "data": "card", className: "job" }
  ],
  buttons: [
  {
      text: 'Select all',
      action: function () {
        $("#job-table ").find("td").each(function(index) {
          $(this).addClass("ui-selected");
          $("#job-table").data("ui-selectable")._mouseStop(null);
        });

      }
  },
  {
      text: 'Unselect all',
      action: function () {
        $("#job-table").find("td").each(function(index) {
          $(this).removeClass("ui-selected");
          $("#job-table").data("ui-selectable")._mouseStop(null);
        });
      }
  },
    {
      extend: 'collection',
      text: 'Action',
      buttons: [
        {
          text: 'Delete', action: function() {
            $(".job.ui-selected").each(function() {
              // do something with each job
              var job_id = $(this).find(".card").attr("id");
              delete_job_event_data = {job_id: job_id};
              api_server.send('delete-job', delete_job_event_data);
            });
          }
        }
      ]
    }
  ],
  initComplete: function () {
    job_dtable.buttons().container()
        .appendTo( $('#job-table_wrapper .col-md-6:eq(0)') );
  }
});

  /////// TRIGGER TABLE BELOW
  var trigger_dtable = $('#trigger-table').DataTable( {
    autoWidth:      false,  
    lengthChange:   true,
    paging: false,
    columns: [
      {"width": "10%", "targets": 0}, // active
      {"width": "10%", "targets": 1}, // description
      {"width": "80%", "targets": 2} // command line
    ],
    buttons: [
      {
        text: 'Pause all',
        action: function () {
          $("#trigger-table").find(".trigger-pause").each(function (index) {
            if ($(this).prop('checked')) {
              $(this).trigger('click'); // unclick it
            } else {

            }
          });
        }
      },
      {
        text: 'Unpause all',
        action: function () {
          $("#trigger-table").find(".trigger-pause").each(function (index) {
            if ($(this).prop('checked')) {

            } else {
              $(this).trigger('click'); // click it
            }
          });
        }
      }
    ]
  });

  trigger_dtable.buttons().container()
      .appendTo( '#trigger-table_wrapper .col-md-6:eq(0)' );



  $('a[data-toggle="tab"]').on('shown.bs.tab', function(e){
     $($.fn.dataTable.tables(true)).DataTable()
        .columns.adjust();
  });

  //$('#domain-table tbody').on('click', 'tr', function () {
  //    var data = table.row( this ).data();
  //    alert( 'You clicked on '+data[0]+'\'s row' );
  //} );


  $('body').on('click', '.web-application-expand-button', function() {
    if ($(this).attr("aria-expanded") == "false") {
      $("#"+$(this).attr("aria-controls")).find(".page-table").each(function(index, obj) {
          if (!$.fn.DataTable.isDataTable(this)) {
            $(this).DataTable({
              "autoWidth": true,
              "columnDefs": [
                { "width": "80%", "targets": 0},
                { "width": "10%", "targets": 1},
                { "width": "10%", "targets": 2}
              ]
            });
          }
      });
    }
  });



  $('a[class^="nav-link"]').on('shown.bs.tab', function (e) {
    var hash = $(e.target).attr('href');

    if (history.pushState) {
      history.pushState(null, null, hash);
    } else {
      location.hash = hash;
    }
  });

  function set_terminal_size(height_in_pixels) {
    $(".footer").css("height", height_in_pixels+"px");
  }


  $('body').on('click', '.new-terminal-button', function() {
    $(".footer").css("height", "40%");
    terminal_server.send('new_terminal', null);
  });

  function dtable_search(table_selector, search, append) {
    var table = $(table_selector).last().DataTable();
    var current_search = $(table_selector + ' input').val();

    if (append) {
      if (current_search.length > 0) {
        table.search(current_search + " " + search).draw();
      } else { // can't append nothing; just search it
        table.search(search).draw();
      }
    } else { // not appending - just search it
      table.search(search).draw();
    }
  }

  // function that can be called to navigate by hash
  function hashNavigate() {
    var hash = window.location.hash;
    console.log("hasnav hit: " + hash);

    if ($("#navbarSupportedContent").hasClass("show")) {
      $("#navbar-toggler").click();
    }
    
    if (hash == "#tools") {
      $('.nav-link[href="#tools"]').tab('show');
      $('.nav-link[href="#tab-help"]').tab('show');

    } else if (hash == "#jobs") {
      $('.nav-link[href="#jobs"]').tab('show');
      //dtable_search('#web-application-table', "", false);

    } else if (hash == "#triggers") {
      $('.nav-link[href="#triggers"]').tab('show');
      //dtable_search('#web-application-table', "", false);

    } else if (hash == "#web-applications") {
      $('.nav-link[href="#web-applications"]').tab('show');
      //dtable_search('#web-application-table', "", false);

    } else if (hash == "#hosts") {
      $('.nav-link[href="#hosts"]').tab('show');
      //dtable_search('#host-table', "", false);

    } else if (hash == "#domains") {
      $('.nav-link[href="#domains"]').tab('show');
      //dtable_search('#domain-table', "", false);

    } else if (hash == "#dns-records") {
      $('.nav-link[href="#dns-records"]').tab('show');
      //dtable_search('#dns-record-table', "", false);

    } else if (hash == "#domains") {
      $('.nav-link[href="#domains"]').tab('show')
      $('.nav-link[href="#domain-overview"]').tab('show');
      //dtable_search('#domain-table', "", false);

    } else if (hash == "#domain-overview") {
      $('.nav-link[href="#domains"]').tab('show')
      $('.nav-link[href="#domain-overview"]').tab('show');

      table_search('#domain-table', "tld:true", false);

    } else if (hash.startsWith("#web-applications-")) {
      var split = hash.split("-");

      if (split.length > 1) {
        if (split[2] == "ss") {
          // open web app tab
          $('.nav-link[href="#web-applications"]').tab('show');
          // open "detailed view"
          $('.nav-link[href="#web-applications-ss"]').tab('show');

        } else {
          // open web app tab
          $('.nav-link[href="#web-applications"]').tab('show');       
          $('.nav-link[href="#tab-web-application-summary"]').tab('show');

          // scroll to specific 
          var web_application_id = split[2];
          console.log("scrolling to app: " + web_application_id);

          var table = $('#web-application-table').last().DataTable();

          var row = $('#web-application-heading-'+web_application_id);

          // test
          table.search('id:'+web_application_id).draw();
          $(row).parent().find(".collapse").collapse("show");
          window.scrollTo(0,0);

          // LAZY
         $(".web-application-row-"+web_application_id).find(".page-table").each(function(index, obj) {
              if (!$.fn.DataTable.isDataTable(this)) {
                $(this).DataTable({
                  "autoWidth": true,
                  "columnDefs": [
                    { "width": "80%", "targets": 0},
                    { "width": "10%", "targets": 1},
                    { "width": "10%", "targets": 2}
                  ]
                });
              }
          });

          //location.hash = hash;

        }
      }
    } else if (hash.startsWith("#domain-search|")) {
      $('.nav-link[href="#tools"]').tab('show');
      $('.nav-link[href="#tab-help"]').tab('show');
      
      var split = hash.split("|");

      if (split.length > 1) {
        // open domain tab
        $('.nav-link[href="#domains"]').tab('show');
        // scroll to specific domain
        var domain_search = split[1];

        var table = $('#domain-table').last().DataTable();
        table.search(domain_search).draw();
        $(row).parent().find(".collapse").collapse("show");
        //window.scrollTo(0,0);

        //location.hash = hash;
      }
    } else if (hash.startsWith("#dns-record-search|")) {
      var split = hash.split("|");

      if (split.length > 1) {
        // open domain tab
        $('.nav-link[href="#dns-records"]').tab('show');
        // scroll to specific domain
        var dns_record_search = split[1];

        var table = $('#dns-record-table').last().DataTable();
        table.search(dns_record_search).draw();
        $(row).parent().find(".collapse").collapse("show");
        //window.scrollTo(0,0);

        //location.hash = hash;
      }
    } else if (hash.startsWith("#host-search|")) {
      var split = hash.split("|");

      if (split.length > 1) {
        // open domain tab
        $('.nav-link[href="#hosts"]').tab('show');
        // scroll to specific domain
        var host_search = split[1];

        var table = $('#host-table').last().DataTable();
        table.search(host_search).draw();
        $(row).parent().find(".collapse").collapse("show");
        //window.scrollTo(0,0);

        //location.hash = hash;
      }
    } else { //catch-all to navigate by left-tab
      $('.nav-link[href="' + hash + '"]').tab('show');
      //if ($("#navbarSupportedContent").hasClass("show")) {
      //  $('.navbar-toggler').click();
      //}

      location.hash = hash;
    }

    $("html, body").animate({ scrollTop: 0 }, "slow");


    $($.fn.dataTable.tables(true)).DataTable()
       .columns.adjust();
  }

  $('body').on('click', '.hash-nav', function() {
    // check if expanding first
    // check if this hash nav is even an accordion
    var should_nav = true;

    if ($(this)[0].hasAttribute("aria-expanded")) {
      console.log("has expanded attr");
      should_nav = $(this).attr('aria-expanded');
    }
    
    console.log("should_nav: " + should_nav);

    if (should_nav == true) {
    // ... click event fires before href is followed, so we need to set hash ourselves...
      window.location.hash = $(this).attr("href");
      hashNavigate();
    }
  });

  // handle back button pressed
  $( window ).on( 'hashchange', function( e ) {
      hashNavigate();
  } );

  var hash = window.location.hash;

  // when the page loads, figure out what which tabs and shit should be navigated to
  if (hash) {
    hashNavigate();
  }

  function showTool(tool) {
    $('.nav-pills a[href="#tools"]').tab('show');
    $('.nav-tabs a[href="#tab-'+tool+'"]').tab('show');
    window.scrollTo(0, 0);
  }

  $('body').on('click', '.page-to-sqlmap', function() {
    showTool("sqlmap");

    // pull the app-i

    //todo... i am so sorry
    var target_protocol = $(this).parent().parent().parent().parent().parent().parent().parent().find(".application-protocol option:selected").text().trim();
    var target_domain = $(this).parent().parent().parent().parent().parent().parent().parent().find(".application-domain option:selected").text().trim();
    var page_path = $(this).parent().parent().parent().attr("page-path");

    // get parameters and build url
    // todo: support post parameters
    var params = "";
    $(this).parent().find("input[class='page-param']:checked").each(function (index) {
      params += $(this).attr("name") + "=&"
    })

    var auth_cookie = $(this).parent().parent().find("input[header-name='cookie']:checked").attr("header-value");

    var url = target_protocol + target_domain + page_path + "?" + params;
    $("#sqlmap-target").val(url);
    $("#sqlmap-cookies").val(auth_cookie);
  });

$('body').on('click', '.page-to-wfuzz', function() {
  showTool("wfuzz");

  //todo... i am so sorry
  var target_url = $(this).attr("target");

  // get parameters and build url
  // todo: support post parameters
  var params = "";
  $(this).parent().find("input[class='page-param']:checked").each(function (index) {
    params += $(this).attr("name") + "=&"
  })

  var headers = "";
  $(this).parent().find("input[class='page-header']:checked").each(function (index) {
    headers += $(this).attr("header-name") + ": " + $(this).attr("header-value")  + "\n"
  })

  var auth_cookie = $(this).parent().parent().find("input[header-name='cookie']:checked").attr("header-value");

  $("#wfuzz-target").val(target_url);

  if (headers.length == 0) {
    $("#wfuzz-toggle-headers").prop('checked', false);
  } else {
    $("#wfuzz-toggle-headers").prop('checked', true);

    $("#wfuzz-headers").val(headers);
  }
  
  if (params.length > 2) {
    $("#wfuzz-toggle-postdata").prop('checked', true);
    $("#wfuzz-method").val("POST");
    $("#wfuzz-postdata").val(params);
  } else {
    $("#wfuzz-toggle-postdata").prop('checked', false);
  }

  if (auth_cookie.length > 0) {
    $("#wfuzz-cookie").val(auth_cookie);
    $("#wfuzz-toggle-cookie").prop('checked', true);
  } else {
    $("#wfuzz-toggle-cookie").prop('checked', false);
  }
});

$(".selectable").selectable({ // make everything selectable that should be
  filter:'td',
  cancel: '.no-select'
});


  $(".selectable").selectable({ // make everything selectable that should be
    filter:'td',
    cancel: '.no-select'
  });


  $('body').on('click', '.minimize-terminals-button', function() {
    var current_height = $(".footer").css("height");

    if (current_height != "50px") {
      $(".footer").css("height",  "50px");
    } else {
      $(".footer").css("height",  "40%");
    }
  });

  $('body').on('click', '.focus-terminal-button', function() {
    $("#terminal-container").find(".hm9k-term.active")[0].ownerDocument.defaultView.focus();
  });

  $('body').on('click', '.maximize-terminals-button', function() {
    var current_height = $(".footer").css("height");

      $(".footer").css("height",  "75%");
  });

  $('body').on('click', '.parse-http-request-button', function() {
    // send fetch data to api server~

    var app_id = $(this).attr('web-app-id');
    console.log("id: " + app_id);
    var raw_http_request = $(".parse-http-request-textarea-"+app_id).val();

    parse_fetch_event_data = {app_id: app_id, raw_http_request: raw_http_request};
    api_server.send('parse-http-request', parse_fetch_event_data);
  });


  // todo: put this code elsewhere, modified from https://github.com/mslinn/jquery-deserialize
  $.fn.deserialize = function (data) {
    var inps = $(this).find(":input").get();

    // finagle the [object] data to an array that is easier to work with
    var data2 = [];

    $.each(data, function () {
      data2[this.name] = this.value
    });

    // for each input name
    $.each(inps, function () {
      if (this.name && data2[this.name]) {
        if (this.type === "checkbox" || this.type === "radio") {
          $(this).prop("checked", (data2[this.name] === $(this).val()));
        } else {
          $(this).val(data2[this.name]);
        }
      } else if (this.type === "checkbox") {

        $(this).prop("checked", false);
      }
    });
    return $(this);

  };

  $('.domain-send-to').change( function() {
    var tool_name = $(this).val();
    var domain = $(this).attr("data-domain");
    
    if (tool_name == "None")
      return false;

    $('.nav-pills a[href="#tools"]').tab('show');
    $('.nav-tabs a[href="#tab-'+tool_name+'"]').tab('show');

    $("#"+tool_name+"-target").val(domain);
  });

  $('body').on('change', '.web-application-set-risk', function() {
    var risk = $(this).val();
    var web_application_id = $(this).attr("web-application-id");

    set_web_application_risk_event_data = {
      id: web_application_id,
      risk: risk
    };

    api_server.send('set-web-application-risk', set_web_application_risk_event_data);
  });

  $('body').on('change', '.domain-set-risk', function() {
    var risk = $(this).val();
    var domain_id = $(this).attr("domain-id");

    set_domain_risk_event_data = {
      id: domain_id,
      risk: risk
    };

    api_server.send('set-domain-risk', set_domain_risk_event_data);
  });

  $('body').on('change', '.host-set-risk', function() {
    var risk = $(this).val();
    var host_id = $(this).attr("host-id");

    set_host_risk_event_data = {
      id: host_id,
      risk: risk
    };

    api_server.send('set-host-risk', set_host_risk_event_data);
  });

  $('body').on('click', '.save-tool-config', function() {
    var tool_name = $(this).attr("tool-name");
    var new_config_name = $("#"+tool_name+"-config-name").val();

    if (new_config_name.length > 0) {
      var options = $("#"+tool_name+"-options").serializeArray();

      add_scan_config_event_data = {name: new_config_name, tool_name: tool_name, options: options};
      api_server.send('add-scan-config', add_scan_config_event_data);

      $("#"+tool_name+"-config-name").val("");
    }
  });

  $(".load-saved-config").change(function() {
    var tool_name = $(this).attr("tool-name");
    var config_id = $(this).val();
    
    if (config_id == "None")
      return false;

    $.getJSON("/tool_configurations/"+config_id, function(data) {
      $("#"+tool_name+"-options").deserialize(data);
    });
  });

  //$('body').on('click', '.term-tab', function() {
  //  console.log("hit");
  //  $(".footer").css("height", "35%");
  //  //$(".terminal-box").find(".tab-pane" ).each(function() { $(this).removeClass(""); $(this).removeClass("show"); });
  //
  //});

  $('body').on('click', '.term-tab', function() {
    $(".footer").css("height", terminal_height);

    var tid = $(this).attr("tid"); // get TID from button clicked
    console.log("tid: " + tid);

    $(".tab-pane[id*=\"tab-console\"]").each(function() { $(this).removeClass("active"); $(this).removeClass("show"); });
    $(".tab-pane[id^=\"tab-console-"+tid+"\"]").addClass("active").addClass("show");




    //if ($(".footer")[0].style.height == "35%") {
    //  $(".footer").removeAttr("style");
    //} else {
    //  $(".footer").css("height", "35%");
    //}

    // delete terminals from main terminal view
    //$(".tab-pane[id^=\"tab-console-"+tid+"\"]").remove();
  });



  $('body').on('click', '.save-tool-config', function() {
    var tool_name = $(this).attr("tool-name");
    var new_config_name = $("#"+tool_name+"-config-name").val();

    if (new_config_name.length > 0) {
      var options = $("#"+tool_name+"-options").serializeArray();

      add_scan_config_event_data = {name: new_config_name, tool_name: tool_name, options: options};
      api_server.send('add-scan-config', add_scan_config_event_data);

      $("#"+tool_name+"-config-name").val("");
    }
  });

  $('.trigger-host-options').hide();
  $('.trigger-service-options').hide(); 
  $('.trigger-domain-options').hide();
  $('.trigger-nmap-script-options').hide();
  $('.trigger-web-application-options').hide();
  $('.trigger-dirsearch-options').hide();
  $('.trigger-page-options').hide();
  $('.scan-conditions-helper').hide();

  $('#trigger-on').change(function(){
      var changed_to = $('#trigger-on').val();

      $('.trigger-host-options').hide();
      $('.trigger-service-options').hide(); 
      $('.trigger-domain-options').hide();
      $('.trigger-web-application-options').hide();
      $('.trigger-nmap-script-options').hide();
      $('.trigger-dirsearch-options').hide();
      $('.trigger-page-options').hide();

      $('.scan-conditions-helper').show();

      if(changed_to == 'add-host') {
        $('.scan-conditions-helper').hide(); // none for host
        $('.trigger-host-options').show();
      } else if (changed_to == 'add-service') {
        $('.trigger-service-options').show(); 
      } else if (changed_to == 'add-domain') {
        $('.trigger-domain-options').show(); 
      } else if (changed_to == 'add-nmap-script') {
        $('.trigger-nmap-script-options').show(); 
      } else if (changed_to == 'add-page') {
        $('.trigger-page-options').show(); 
      } else if (changed_to == 'add-web-application') {
        $('.trigger-web-application-options').show();
      } else {
        $('.scan-conditions-helper').hide();
      }
  });

  //trigger_name = msg["data"]["name"]
  //trigger_cmd = msg["data"]["run_shell"]
  //trigger_on = msg["data"]["trigger_on"]

  // bind domain comment action on initial page load
  $('body').on('submit', ".domain-comment", function(event) {
    // get comment
    var comment = $(this).find("textarea").val();
    var domain_id = $(this).attr("data-domain-id");

    // submit to api server
    new_domain_comment_event_data = {id: domain_id, comment: comment};
    api_server.send('new-domain-comment', new_domain_comment_event_data);

    event.preventDefault();
  });

  $('body').on('submit', ".web-application-comment", function(event) {
    // get comment
    var comment = $(this).find("textarea").val();
    var web_application_id = $(this).attr("data-web-application-id");

    // submit to api server
    web_application_comment_event_data = {id: web_application_id, comment: comment};
    api_server.send('web-application-comment', web_application_comment_event_data);

    event.preventDefault();
  });

  // bind host comment action on initial page load
  $('body').on('submit', ".host-comment", function(event) {
    // get comment
    var comment = $(this).find("textarea").val();
    var host_id = $(this).attr("data-host-id");

    // submit to api server
    new_host_comment_event_data = {id: host_id, comment: comment};
    api_server.send('new-host-comment', new_host_comment_event_data);

    event.preventDefault();
  });

  function hideWebApplication(id) {
    // send a request to the api-server to hide this web application

  }

  $('body').on('click', ".hide-web-application", function(event) {
    // submit to api server
    hide_web_application_event_data = {id: $(this).attr('web_app_id')};
    api_server.send('hide-web-application', hide_web_application_event_data);
    event.preventDefault();
  });

  $('body').on('click', ".hide-host", function(event) {
    // submit to api server
    hide_host_event_data = {id: $(this).attr('host_id')};
    api_server.send('hide-host', hide_host_event_data);

    event.preventDefault();
  });


  $("body").on('click', ".trigger-pause", function() {
    var checked = $(this).prop('checked');
    var trigger_id = $(this).attr("data-trigger-id")

    if (checked) {
      pause_trigger_event_data = {id: trigger_id};
      api_server.send('unpause-trigger', pause_trigger_event_data);
    } else {
      unpause_trigger_event_data = {id: trigger_id};
      api_server.send('pause-trigger', unpause_trigger_event_data);
    }
  });

  $("body").on('click', ".trigger-silent", function() {
    var checked = $(this).prop('checked');
    var trigger_id = $(this).attr("data-trigger-id")

    if (checked) {
      background_trigger_event_data = {id: trigger_id};
      api_server.send('background-trigger', background_trigger_event_data);
    } else {
      foreground_trigger_event_data = {id: trigger_id};
      api_server.send('foreground-trigger', foreground_trigger_event_data);
    }

  });

  $('body').on('click', '#create-trigger', function() {
    var trigger_on = $("#trigger-on").val();
    var trigger_name = $("#trigger-name").val();
    var shell_cmd = $("#trigger-shell-cmd").val();
    var run_in_background = true; //$("#trigger-run-silent").prop('checked');

    var service_port_match = $("#service-trigger-port").val();
    var service_trigger_port_match_by = $("#service-trigger-port-match-by").val();

    var domain_name_match = $("#domain-trigger-domain-name").val();
    var domain_trigger_match_by = $("#domain-trigger-domain_name-match-by").val();

    var web_application_full_url_match = $("#web-application-trigger-full_url").val();
    var web_application_full_url_match_by = $("#web-application-trigger-full_url-match-by").val();
    var web_application_port_match = $("#web-application-trigger-port").val();
    var web_application_port_match_by = $("#web-application-trigger-port-match-by").val();
    var web_application_scheme_match = $("#web-application-trigger-scheme").val();
    var web_application_scheme_match_by = $("#web-application-trigger-scheme-match-by").val();

    var page_path_match = $("#page-trigger-path").val();
    var page_path_match_by = $("#page-trigger-path-match-by").val();
    var page_status_match = $("#page-trigger-status").val();
    var page_status_match_by = $("#page-trigger-status-match-by").val();
    var page_contentlength_match = $("#page-contentlength-path").val();
    var page_contentlength_match_by = $("#page-trigger-contentlength-match-by").val();

    var script_name_match = $("#script-trigger-scriptname").val();
    var script_name_match_by = $("#script-trigger-scriptname-match-by").val();
    var script_output_match = $("#script-trigger-scriptoutput").val();
    var script_output_match_by = $("#script-trigger-scriptoutput-match-by").val();
    var script_port_match = $("#script-trigger-port").val();
    var script_port_match_by = $("#script-trigger-port-match-by").val();

    var page_path_match = $("#trigger-page-path").val();
    var page__match_by = $("#trigger-page-path-match-by").val();
    var page_status_code_match = $("#trigger-page-status").val();
    var page_status_code_match_by = $("#trigger-page-status-match-by").val();
    var page_contentlength_match = $("#trigger-page-contentlength").val();
    var page_contentlength_match_by = $("#trigger-page-contentlength-match-by").val();

    var conditions = []

    if (trigger_on == "add-service") {
      // if there is a port match filled out we should create the trigger condition
      if (service_port_match.length > 0) {
        // default to csv match so you don't have to do the dropdown box
        if (service_trigger_match_by == "None") {
          service_trigger_match_by = "csv";
        }

        conditions = [{
          match_key: "port",
          match_value: service_port_match,
          match_type: service_trigger_port_match_by
        }]
      }
    }

    if (trigger_on == "script") {
      // if there is a port match filled out we should create the trigger condition

      if (script_name_match.length > 0) {
        // default to csv match so you don't have to do the dropdown box
        if (script_name_match_by == "None") {
          script_name_match_by = "regex";
        }

        conditions.push({
          match_key: "script-name",
          match_value: script_name_match,
          match_type: script_name_match_by
        });
      }

      if (script_output_match.length > 0) {
        // default to csv match so you don't have to do the dropdown box
        if (script_output_match_by == "None") {
          script_output_match_by = "regex";
        }

        conditions.push({
          match_key: "script-output",
          match_value: script_output_match,
          match_type: script_output_match_by
        });
      }

      if (script_port_match.length > 0) {
        if (script_port_match_by == "None") {
          script_port_match_by = "csv"
        }

        conditions.push({
          match_key: "script-port",
          match_value: script_output_match,
          match_type: script_output_match_by
        });
      }
    }

    if (trigger_on == "add-domain") {
      // if there is a domain match filled out we should create the trigger condition
      if (domain_name_match.length > 0) {
        // default to csv match so you don't have to do the dropdown box
        if (domain_trigger_match_by == "None") {
          domain_trigger_match_by = "regex";
        }

        conditions.push({
          match_key: "domain",
          match_value: domain_name_match,
          match_type: domain_trigger_match_by
        });
      }
    }


    if (trigger_on == "add-web-application") {
      // if there is a domain match filled out we should create the trigger condition
      if (web_application_full_url_match.length > 0) {
        // default to csv match so you don't have to do the dropdown box
        if (web_application_full_url_match_by == "None") {
          domain_trigger_match_by = "csv";
        }

        conditions.push({
          match_key: "full_url",
          match_value: web_application_full_url_match,
          match_type: web_application_full_url_match_by
        });
      }

      if (web_application_port_match.length > 0) {
        conditions.push({
          match_key: "port",
          match_value: web_application_full_url_match,
          match_type: web_application_full_url_match_by
        });
      }

      if (web_application_port_match.length > 0) {
        conditions.push({
          match_key: "port",
          match_value: web_application_full_url_match,
          match_type: web_application_full_url_match_by
        });
      }
    }

    if (trigger_on == "add-page") {
      // if there is a domain match filled out we should create the trigger condition
      if (page_path_match.length > 0) {
        conditions.push({
          match_key: "path",
          match_value: page_path_match,
          match_type: page_path_match_by
        });
      }

      if (page_status_match.length > 0) {
        conditions.push({
          match_key: "status",
          match_value: page_status_match,
          match_type: page_status_match_by
        });
      }

      if (page_contentlength_match.length > 0) {
        conditions.push({
          match_key: "contentlength",
          match_value: page_contentlength_match,
          match_type: page_contentlength_match_by
        });
      }
    }

    if (trigger_on != "None" && shell_cmd.length > 0) {
      add_trigger_event_data = {
        name: trigger_name,
        trigger_on: trigger_on,
        run_shell: shell_cmd,
        run_in_background: run_in_background,
        conditions: conditions
       };

      api_server.send('add-trigger', add_trigger_event_data);

      //var trigger_on = $("#trigger-on").val("None");
      //trigger_name = $("#trigger-name").val("");
      //var shell_cmd = $("#trigger-shell-cmd").val("");
    }

  });

  $("body").on('click', ".start-tour-button", function() {
    $.getScript('/tour.js', function(data, textStatus, jqxhr)
    {
      console.log("loaded: " + data);
    });
  });

  $('body').on('click', ".gitgot-prev", function(event) {
    send_to_active_terminal("b\n");
  });

  $('body').on('click', ".gitgot-next", function(event) {
    send_to_active_terminal("n\n");
  });

  $('body').on('click', ".gitgot-print", function(event) {
    send_to_active_terminal("p\n");
  });

  $('body').on('click', ".gitgot-save", function(event) {
    send_to_active_terminal("s\n");
  });

  $('body').on('click', ".gitgot-add-result", function(event) {
    send_to_active_terminal("a\n");
  });

  $('body').on('click', ".gitgot-ignore-contents", function(event) {
    send_to_active_terminal("c\n");
  });

  $('body').on('click', ".gitgot-ignore-user", function(event) {
    send_to_active_terminal("u\n");
  });

  $('body').on('click', ".gitgot-ignore-repo", function(event) {
    send_to_active_terminal("r\n");
  });

  $('body').on('click', ".gitgot-ignore-filename", function(event) {
    send_to_active_terminal("f\n");
  });

  $('body').on('click', ".gitgot-search", function(event) {
    var gitgot_search = $(".gitgot-search-value");
    send_to_active_terminal("/("+$(".gitgot-search-value").val()+")\n");
  });

  function current_page_no_hash() {
    return location.protocol+'//'+location.host+location.pathname
  }

  $('body').on('click', '.refresh-toggle-button', function(event) {
    is_refreshing = !is_refreshing;
    console.log("refresh is: " + is_refreshing);

    if (!is_refreshing) {
      $('.refresh-toggle-button').removeClass("btn-success");
      $('.refresh-toggle-button').addClass('btn-danger');
      $('.refresh-toggle-button').html("Not Refreshing Tables");
    } else {
      web_application_dtable.ajax.reload(null, false);
      domain_dtable.ajax.reload(null, false);
      host_dtable.ajax.reload(null, false);
      dns_record_dtable.ajax.reload(null, false);

      $('.refresh-toggle-button').removeClass("btn-danger");
      $('.refresh-toggle-button').addClass('btn-success');
      $('.refresh-toggle-button').html("Auto Refreshing Tables")

    }
  });

});
