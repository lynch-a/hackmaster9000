
function generate_spiderfoot_command(filename_override) {
  var cmd = "sf.py ";

  if ($("#spiderfoot-target").val().length > 0) {
    var target = $("#spiderfoot-target").val();
    if (target != "") {
        cmd += " -s " + target;
    }
  }

  cmd = cmd + " -o csv -q -D \"|||\"";

  if ($("#spiderfoot-modules").val().length > 0) {
    var module_list = $("#spiderfoot-modules").val();
    if (module_list != "") {
        cmd += " -m " + module_list
    }
  }

  cmd = cmd + " > sf-"+ Math.random().toString(36).substring(7) + ".csv"

  return cmd;
}

$("#spiderfoot-run").click(function() {
    var cmd = generate_spiderfoot_command();
    console.log(cmd);
    schedule_or_run("spiderfoot", cmd);
});
