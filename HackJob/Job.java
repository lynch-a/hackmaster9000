import com.j256.ormlite.field.DatabaseField;
import com.j256.ormlite.table.DatabaseTable;

@DatabaseTable(tableName = "jobs")
public class Job {
    
    @DatabaseField(generatedId=true)
    private int id;
    
    @DatabaseField
    private int user_id;
    
    @DatabaseField
    private int project_id;
    
    @DatabaseField
    private String tid;
    
    @DatabaseField
    private String job_type;
    
    @DatabaseField
    private String job_data;
    
    @DatabaseField
    private int run_every;
    
    @DatabaseField
    private int last_run; // last time run (in seconds since epoch)
    
    @DatabaseField
    private int max_runtimes;
    
    @DatabaseField
    private int run_times;
    
    @DatabaseField
    private String status;
    
    @DatabaseField
    private boolean paused;
    
    @DatabaseField
    private String run_in_background;
    
    public Job() {
        // ORMLite needs a no-arg constructor 
    }
    
    public Job(int userId, int projectId, String tid, String jobType, String jobData, int runEvery, int lastRun, int maxRunTimes, int runTimes, boolean paused, String runInBackground) {
    	//this.id = id;
    	this.user_id = userId;
    	this.project_id = projectId;
    	this.tid = tid;
    	this.job_type = jobType;
    	this.job_data = jobData;
    	this.run_every = runEvery;
    	this.last_run = lastRun;
    	this.max_runtimes = maxRunTimes;
    	this.run_times = runTimes;
    	this.paused = paused;
    	this.run_in_background = runInBackground;
    }
    
    public int getJobId() {
    	return id;
    }
    
    public String getJobType() {
    	return job_type;
    }
    
    public int getUserId() {
        return user_id;
    }
    
    public int getProjectId() {
        return project_id;
    }
    
    public String getJobData() {
        return job_data;
    }
    
    public int getRunTimes() {
        return run_times;
    }
    
    public void setRunTimes(int runTimes) {
    	this.run_times = runTimes;
    }
    
    public int getMaxRunTimes() {
        return max_runtimes;
    }
    
    public int getRunEvery() {
        return run_every;
    }
    
    public boolean getPaused() {
    	return paused;
    }
    
    // what the fuck is going on here with ormlite? boolean values were being set to false automatically, and the string comes back as "t" or "f" instead of full boolean string
    public String getRunInBackground() {
    	return Boolean.toString(run_in_background.equals("t"));
    }
    
    public void setStatus(String status) {
    	this.status = status;
    }
    
    public int getLastRun() {
    	return last_run;
    }
    
    public void setLastRun(int lastRun) {
    	this.last_run = lastRun;
    }

	public String getStatus() {
		return this.status;
	}
}