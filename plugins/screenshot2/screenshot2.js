function generate_screenshot2_command(filename_override) { // this dumps random files anyway so no need for override
  var cmd = "screenshot2";
  //var cmd = "web-screenshot";
  
  var target = $("#screenshot2-target").val();
  if (target != "") {
      cmd += " "+target;
  }

  return cmd;
}

$("#screenshot2-run").click(function() {
  var cmd = generate_screenshot2_command();
  schedule_or_run("screenshot2", cmd);
});