var tour = {
      id: "hello-hm9k-2",
      nextOnTargetClick: true,
      steps: [
        {
          title: "<i>hm9k: it's pentesting, but better</i>",
          content: "hm9k is workflow-agnostic scanning and visualization tool. Many common tools are supported out of the box, but it's simple to add new plugins to interface with any tool.",
          target: $(".start-tour-button")[0],
          placement: "bottom"
        },
        {
          title: "Tool Page",
          content: "This is the tool page. Each tool listed here is a plugin that provides an interface and parser. You can write plugins to support any terminal based tool that can output data in a parsabale file format. </br></br> Let's run nmap.",
          target: $("a[href='#tab-nmap']").last()[0],
          placement: "top",
          onNext: function() {
            $('.nav-pills a[href="#tools"]').tab('show');
            $('.nav-tabs a[href="#tab-nmap"]').tab('show');
          },
          nextOnTargetClick: true 
        },
        {
          title: "Nmap",
          content: "Short guides can be found at the top of each plugin tool page.",
          target: $("#nmap-help-heading").last()[0],
          placement: "right"
        },
        {
          title: "Terminal",
          content: "This button opens a serverside terminal in which nmap will run.",
          target: $(".new-terminal-button").last()[0],
          placement: "top",
          nextOnTargetClick: true,
          showNextButton: false
        },
	      {
          title: "Terminal",
          content: "Yes this is a full PTY terminal supported by screen sessions on the backend. Go nuts.",
          target: $(".new-terminal-button").last()[0],
          placement: "top"
        },
        {
          title: "Nmap Scan",
          content: "Fill out the target and configure the tool to run with the options you want",
          target: $("#nmap-target")[0],
          placement: "top"
        },
        {
          title: "Auto Scan",
          content: "This sends the current tool configuration to Auto Scan, which can automatically launch the current scan configuration against newly discovered data points.",
          target: $(".send-to-autoscan").first()[0],
          placement: "right"
        },
        {
          title: "Nmap Scan",
          content: "Just just hit run to launch the tool in the currently open terminal.",
          target: $("#nmap-run")[0],
          placement: "top"
        },
        {
          title: "Hosts",
          content: "Once the nmap scan finishes and the parser finished parsing it, the data from the scan should show up in the hosts tab.",
          target: $("a[href='#hosts']")[0],
          placement: "right",
          onNext: function() {
              $('.nav-link[href="#hosts"]').tab('show');
          },
          nextOnTargetClick: true 
          
	      },
	      {
          title: "Overview",
          content: "Pretty much just click through stuff to see all the data that has been parsed and ingested into the database.",
          target: $("a[href='#hosts']")[0],
					placement: "right",
          nextOnTargetClick: true 

	      },
	      {
          title: "Selecting and sending",
          content: "Data from tables can be selected either by dragging the narrow white strip on the left side across multiple elements, or by clicking 'Select All' here. Note: Only the items currently visible in the table will be selected. If you want to select specific targets at a larger scale, use the search box to filter and then use 'Select All'", 
          target: $("#host-table_wrapper").find(".dt-buttons").first()[0],
          placement: "bottom",
          nextOnTargetClick: true 
	      },
        {
          title: "Selecting and Sending",
          content: "Use the 'Send to' dropdown to send all selected targets to the chosen tool", 
          target: $("#host-table_wrapper").find(".dt-buttons").first()[0],
          placement: "bottom",
          nextOnTargetClick: true 
	      },
	      {
          title: "GL;HF",
          content: "Check out Auto Scan. Go find bugs.", 
          target: $("#host-table_wrapper").find(".dt-buttons").first()[0],
          placement: "bottom",
          nextOnTargetClick: true 
	     }
      ]
    };

// Start the tour!
hopscotch.startTour(tour);
