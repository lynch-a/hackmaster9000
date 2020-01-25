
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
    var cmd = generate_dig_command();
    console.log(cmd);
    schedule_or_run("dig", cmd);
});
