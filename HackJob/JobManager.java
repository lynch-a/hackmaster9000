import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import javax.sql.DataSource;

import org.apache.commons.dbcp2.ConnectionFactory;
import org.apache.commons.dbcp2.DriverManagerConnectionFactory;
import org.apache.commons.dbcp2.PoolableConnectionFactory;
import org.apache.commons.dbcp2.PoolingDataSource;
import org.apache.commons.pool2.impl.GenericObjectPool;

import com.google.gson.FieldNamingPolicy;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.j256.ormlite.dao.Dao;
import com.j256.ormlite.dao.DaoManager;
import com.j256.ormlite.jdbc.DataSourceConnectionSource;
import com.j256.ormlite.table.TableUtils;


public class JobManager implements Runnable {
	private DataSourceConnectionSource dbConnection = null;
	private Dao<Job, Integer> jobDao;
	private List<Job> cachedJobs;
	private static TerminalServer ts;
	String url;

	JobManager() {	
		url = "jdbc:postgresql://localhost/hm9k";

		try {
			ts = new TerminalServer(new URI( "ws://localhost:8081"));
			ts.connect();
		} catch (Exception e) {
			System.out.println("Failed to connect to Terminal Server");
			e.printStackTrace();
		}

		try {
			dbConnection = new DataSourceConnectionSource(createDataSource(), url);
			jobDao = DaoManager.createDao(dbConnection, Job.class);
			TableUtils.createTableIfNotExists(dbConnection, Job.class);
		} catch (Exception e) {
			System.out.println("Failed: " + e.getCause());
			e.printStackTrace();
		}

		cachedJobs = Collections.synchronizedList(new ArrayList<Job>());

		//try {
		//int userId, String jobData, int runEvery, int lastRun, int runTimes
		//	Job testJob = new Job(1, "SCANLOADER", "{project: 'fb227206394745419199b9aa212723f5'}", 10, 0, 1);
		//	jobDao.create(testJob);

		//} catch (SQLException e) {
		//System.out.println("Failed: " + e.getCause());
		//}
	}

	public DataSource createDataSource () {
		// read the pw
        String db_password = "";
        try {
	        db_password = new String(Files.readAllBytes(Paths.get("db_password.txt")));
        } catch (Exception e) {
        	System.out.println("Couldn't read database password for scheduler service (does db_password.txt exist?), exiting");
        	System.exit(1);
        }
        
		// ConnectionFactory can handle null username and password (for local host-based authentication)
		ConnectionFactory connectionFactory = new DriverManagerConnectionFactory(url, "hm9k", db_password.toCharArray());
		PoolableConnectionFactory poolableConnectionFactory = new PoolableConnectionFactory(connectionFactory, null);
		GenericObjectPool connectionPool = new GenericObjectPool(poolableConnectionFactory);
		poolableConnectionFactory.setPool(connectionPool);
		// Disabling auto-commit on the connection factory confuses ORMLite, so we leave it on.
		// In any case ORMLite will create transactions for batch operations.
		return (DataSource) new PoolingDataSource(connectionPool);
	}

	@Override
	public void run() {
		while (true) {
			try {
				List<Job> allJobs = jobDao.queryForAll();

				// load all jobs into cache
				for(int i = 0; i < allJobs.size(); i++) {
					cachedJobs.add(allJobs.get(i));
					//System.out.println("found job: " + allJobs.get(i).getJobData() + " | background? " + allJobs.get(i).getRunInBackground() + " | status: " + allJobs.get(i).getStatus());
				}

				if (cachedJobs.size() == 0) {
					System.out.println("No job to run!");
				}


				// count how many jobs are currently running (trash, todo)
				int jobs_running = 0;
				for (int i = 0; i < cachedJobs.size(); i++) {
					Job job = cachedJobs.get(i);

					if (job.getStatus().equals("running") && !job.getJobType().contentEquals("SCANLOADER")) { // don't count scanloadey jobs for now
						jobs_running++;
					}
				}
				System.out.println("Running " + jobs_running + " jobs.");


				for (int i = 0; i < cachedJobs.size(); i++) {
					Job job = cachedJobs.get(i);

					boolean should_run = false;
					if (job.getStatus().equals("queued") || (job.getJobType().contentEquals("SCANLOADER"))) {
						if (jobs_running < 3 || (job.getJobType().contentEquals("SCANLOADER"))) {
							System.out.println("should_run: yes" + job.getJobData());

							should_run = true;
						}
					}
					
					// has this job run before? if it's never run before, we want to run it
					// has enough time passed for this job to run? if so, we want to run it
					if (should_run) {
						if (job.getLastRun() == 0 || HackJob.nowInSeconds() - job.getLastRun() >= job.getRunEvery()) {		
							if ( job.getMaxRunTimes() == 0 || job.getRunTimes() < job.getMaxRunTimes()) { // has this job run the max number of times yet?
								if (job.getPaused() == false ) {
									new JobRunner(job).start();

									// update last_run to current seconds since epoch
									job.setStatus("running");
									jobs_running++;
									//job.setRunTimes(job.getRunTimes()+1);
									job.setLastRun(HackJob.nowInSeconds());
									System.out.println("just ran::::::" + job.getJobData());

									try {
										jobDao.update(job);
									} catch (SQLException e) {
										System.out.println("Error updating record" + e.getMessage());
									}
								} else {
									// job is paused
								}
							} else {
								// job has run max number of times (probably delete job here?)
							}
						} else {
							// not enough time has passed for job to run yet
						}
					} // end: if (should_run)
				}

				cachedJobs.clear();
				try { Thread.sleep(1000); } catch(Exception e) {}
			} catch (Exception e) {
				e.printStackTrace();
				try {Thread.sleep(1000); } catch(Exception e2) {}
			}

		}
	}


	public static boolean sendTerminalRequest(String jobName, Job job) {
		System.out.println("sending run-tool job to terminal server");
		JsonObject new_terminal_request = new JsonObject();
		new_terminal_request.addProperty("event", "run-tool");

		JsonObject data_object = new JsonObject();
		data_object.addProperty("user_id", job.getUserId());
		data_object.addProperty("project_id", job.getProjectId());
		data_object.addProperty("job_id", job.getJobId());

		new_terminal_request.add("data", data_object);

		Gson gson = new GsonBuilder().setPrettyPrinting().serializeNulls().setFieldNamingPolicy(FieldNamingPolicy.UPPER_CAMEL_CASE).create();
		System.out.println("sending to TS: " + gson.toJson(new_terminal_request));

		ts.send(gson.toJson(new_terminal_request));

		return true;
	}
}
