function generate_dirsearch_command() {
  var cmd = "dirsearch";

  var target = $("#dirsearch-target").val();
  if (target != "") {
    cmd += " -u '" + target + "'";
  }
  var target_extensions = $("#dirsearch-target-extensions").val();
  if (target_extensions != "") {
    cmd += " -e '" + target_extensions + "'";
  } else {
    cmd += " -e ''";
  }

  if ($("#dirsearch-toggle-thread-count").prop("checked")) {
    cmd += " -t" + $("#dirsearch-thread-count").val();
  }

  if ($("#dirsearch-toggle-delay").prop("checked")) {
    var delay = $("#dirsearch-delay").val();
    if (delay != "") {
        cmd += " -s " + delay;
    }
  }

  var by_hostname = $("#dirsearch-by-hostname:checked").length > 0
  if (by_hostname) {
    cmd += " -b";
  }

  if ($("#dirsearch-recursive").prop("checked")) {
    cmd += " -r";
  }

  if ($("#dirsearch-follow-redirects").prop("checked")) {
    cmd += " --follow-redirects";
  }

  if ($("#dirsearch-random-agents").prop("checked")) {
    cmd += " --random-agents";
  }

  var output_name = Math.random().toString(36).substring(7);
  if (output_name != "") {
    cmd += " --simple-report=dirsearch-"+output_name+".html";
    cmd += " --json-report=dirsearch-"+output_name+".json";
    cmd += " --plain-text-report=dirsearch-"+output_name+".txt";
  }

  var wordlist = $("#dirsearch-toggle-wordlist").prop('checked');
  if (wordlist) {
    cmd += " -w " + $("#dirsearch-wordlist").val();
  }

  return cmd;
}

$("#dirsearch-run").click(function() {
  
  var target = $("#dirsearch-target").val().trim();

  var targets = target.split(" ");
  if (targets.length > 1) {
    for(var i = 0; i < targets.length; i++) {
      $("#dirsearch-target").val(targets[i]);
      if ($("#dirsearch-target").val().length > 1) { // ignore empty target problems
        var cmd = generate_dirsearch_command();
        schedule_or_run("dirsearch", cmd);
      }
    }
    
    $("#dirsearch-target").val(target)
  } else {
    var cmd = generate_dirsearch_command();
    schedule_or_run("dirsearch", cmd);
  }
});