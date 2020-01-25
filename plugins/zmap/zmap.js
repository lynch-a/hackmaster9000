function generate_zmap_command() {
  var cmd = "sudo zmap";

  cmd += " -B " + $("#zmap-bandwidth").val();
  cmd += " -p " + $("#zmap-port").val();
  cmd += " -N " + $("#zmap-max-results").val();
  cmd += " -n " + $("#zmap-max-targets").val();

  var output_name = "zmap-"+Math.random().toString(36).substring(7)+".csv"
  cmd += " -o " + output_name;

  cmd += " -f \"" + $("#zmap-output-format").val() + "\"";

  return cmd;
}

$("#zmap-run").click(function() {
  var cmd = generate_zmap_command();
  schedule_or_run("zmap", cmd);
});