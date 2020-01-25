function generate_dnscan_command() {
  var cmd = "dnscan";

  cmd += " -o dnscan-"+Math.random().toString(36).substring(7)+".txt";
  

  var target = $("#dnscan-target").val();
  if (target != "") {
      cmd += " -d "+target;
  }

  if ($("#dnscan-toggle-wordlist").prop("checked")) {
    cmd += " -w " + $("#dnscan-wordlist").val();
  }

  if ($("#dnscan-toggle-threads").prop("checked")) {
    cmd += " -t" + $("#dnscan-threads").val();
  }

  if ($("#dnscan-recursive").prop("checked")) {
    cmd += " -r";
  }

  return cmd;
}

$("#dnscan-run").click(function() {
  var target = $("#dnscan-target").val().trim();

  var targets = target.split(" ")
  if (targets.length > 1) {
    // definitely run as BG job. EDIT: maybe no
    //$("#dirsearch-run-in-background").prop('checked', true);

    for(var i = 0; i < targets.length; i++) {
      $("#dnscan-target").val(targets[i]);
      if ($("#dnscan-target").val().length > 1) { // ignore empty target problems
        var cmd = generate_dnscan_command();
        schedule_or_run("dnscan", cmd);
      }
    }
  } else {
    var cmd = generate_dnscan_command();
    //send_to_active_terminal(cmd + "\n");
    schedule_or_run("dnscan", cmd);
  }
});