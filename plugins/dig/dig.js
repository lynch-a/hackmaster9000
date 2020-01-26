
function generate_dig_command() {
  var cmd = "dig";

  if ($("#dig-toggle-lookup-type").prop("checked")) {
    var lookup_type = $("#dig-lookup-type").val();
    if (lookup_type != "") {
        cmd += " -t " + lookup_type;
    }
  }

  if ($("#dig-toggle-dns-server").prop("checked")) {
    var dns_server = $("#dig-dns-server").val();
    if (dns_server != "") {
        cmd += " @" + dns_server;
    }
  }

  cmd += " " + $("#dig-target").val();

  return cmd + " > dig-"+Math.random().toString(36).substring(7)+".txt"
    + " \n"
    + cmd;
}

$("#dig-run").click(function() {
  
  var target = $("#dig-target").val().trim();

  var targets = target.split(" ");
  if (targets.length > 1) {
    for(var i = 0; i < targets.length; i++) {
      $("#dig-target").val(targets[i]);
      if ($("#dig-target").val().length > 1) { // ignore empty target problems
        var cmd = generate_dig_command();
        schedule_or_run("dig", cmd);
      }
    }
    
    $("#dig-target").val(target)
  } else {
    var cmd = generate_dig_command();
    schedule_or_run("dirsearch", cmd);
  }
});