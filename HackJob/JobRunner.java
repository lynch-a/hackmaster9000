import java.io.InputStream;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

public class JobRunner extends Thread {

	private Job job;
	
	JobRunner(Job job) {
		this.job = job;
	}
	@Override
	public void run() {
		if (job.getJobType().equals("SCANLOADER")) {
			System.out.println("Firing scanloader job: " + job.getJobData());

	        JsonObject jobData = new JsonParser().parse(job.getJobData()).getAsJsonObject();

	        String project_uuid = jobData.get("project").getAsString();
	        System.out.println(project_uuid);
	        
	        String cmd = "ruby ScanLoader.rb "+ project_uuid;
	        try {
	        	Process run_scanloader = Runtime.getRuntime().exec(cmd);
	        	run_scanloader.waitFor();
	        	run_scanloader.destroy();
	        } catch (Exception e) {
	    		System.out.println("Firing job failed!");
	    		e.printStackTrace();

	        }
	        
		} else if (job.getJobType().equals("TOOL")) {
			System.out.println("Firing tool job: " + job.getJobData());

			JobManager.sendTerminalRequest("run-tool", job);
		}
	}
}
