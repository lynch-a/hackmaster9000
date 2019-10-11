import com.j256.ormlite.logger.LocalLog;

public class HackJob {
	private static JobManager jobManager;

	public static void main(String[] args) {
		// try to turn off shitty ormlite messages... this doesn't even work
		System.setProperty("com.j256.ormlite.logger.type", "LOCAL");
		System.setProperty(LocalLog.LOCAL_LOG_LEVEL_PROPERTY, "ERROR");

		jobManager = new JobManager();
		jobManager.run();
	}

	public static int nowInSeconds() {
		return (int)(System.currentTimeMillis()/1000);
	}
}
