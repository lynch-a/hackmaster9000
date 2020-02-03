function generate_testssl_command(filename_override) {
  var cmd = "testssl";

  if (filename_override !== undefined) {
    cmd = cmd + " -oA testssl-" + filename_override;
  } else {
    cmd = cmd + " -oA testssl-" + Math.random().toString(36).substring(7);
  }
  
  if ($("#testssl-ids-friendly").prop("checked")) {
    cmd += " --ids-friendly";
  }

  if ($("#testssl-sneaky").prop("checked")) {
    cmd += " --sneaky";
  }

  if ($("#testssl-parallel").prop("checked")) {
    cmd += " --parallel";
  }

  if ($("#testssl-target").val().length > 0) {
    var target = $("#testssl-target").val();
    if (target != "") {
        cmd += " " + target;
    }
  }

  return cmd; 
}

$("#testssl-run").click(function() {
  
  var target = $("#testssl-target").val().trim();

  var targets = target.split(" ");
  if (targets.length > 1) {
    for(var i = 0; i < targets.length; i++) {
      $("#testssl-target").val(targets[i]);
      if ($("#testssl-target").val().length > 1) { // ignore empty target problems
        var cmd = generate_testssl_command();
        console.log("generated testssl cmd: " + cmd);
        schedule_or_run("testssl", cmd);
      }
    }
    
    $("#testssl-target").val(target)
  } else {
    var cmd = generate_testssl_command();
    schedule_or_run("testssl", cmd);
  }
});