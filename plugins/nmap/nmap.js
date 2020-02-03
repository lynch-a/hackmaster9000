
// this function looks at every tool option in _nmap.erb and returns a complete working nmap command
function generate_nmap_command(filename_override) {
  var cmd = "nmap -v";

  if (filename_override !== undefined) {
    cmd += " -oA nmap-"+filename_override;
  } else {
    cmd += " -oA nmap-"+Math.random().toString(36).substring(7);
  }

  if ($("#nmap-toggle-top-ports").prop("checked")) {
    var top_ports = $("#nmap-top-ports").val();
    if (top_ports != "") {
        cmd += " --top-ports " + top_ports;
    }
  }

  if ($("#nmap-toggle-port-range").prop("checked")) {
    var port_range = $("#nmap-port-range").val();
    if (port_range != "") {
        cmd += " -p " + port_range;
    }
  }

  var timing = $("#nmap-timing").val();
  if (timing != "") {
      cmd += " -T" + timing;
  }

  if ($("#nmap-toggle-scripts").prop("checked")) {
    var scripts = $("#nmap-scripts").val();
    if (scripts != "") {
        cmd += " --script " + scripts;
    }

    var script_args = $("#nmap-script-args").val();
    if (script_args != "") {
        cmd += " --script-args '" + scripts + "'";
    }
  }

  var os_detection = $("#nmap-os-detection:checked").length > 0
  if (os_detection) {
      cmd += " -O";
  }

  var dns_resolution = $("#nmap-no-dns-resolution:checked").prop("checked");
  if (dns_resolution) {
      cmd += " -n";
  }

  var os_detection = $("#nmap-os-detection:checked").length > 0
  if (os_detection) {
      cmd += " -O";
  }

  var version_detection = $("#nmap-version-detection:checked").length > 0
  if (version_detection) {
      cmd += " -sV";
  }

  var open_ports_only = $("#nmap-open-ports-only:checked").length > 0
  if (open_ports_only) {
      cmd += " --open";
  }

  var ping_unresponsive = $("#nmap-ping-unresponsive:checked").length > 0
  if (ping_unresponsive) {
      cmd += " -Pn";
  }

  var common_scripts = $("#nmap-common-scripts:checked").length > 0
  if (common_scripts) {
      cmd += " --sC";
  }

  var no_ports = $("#nmap-no-ports:checked").prop("checked");
  if (no_ports) {
      cmd += " -sn";
  }

  var target = $("#nmap-target").val();
  if (target != "") {
      cmd += " " + target;
  }

  return cmd;
}

// when the run button is clicked, we do a little extra processing to check if the command should run in the background or on a schedule
$("#nmap-run").click(function() {
    var cmd = generate_nmap_command();
    console.log(cmd);
    schedule_or_run("nmap", cmd);
});
