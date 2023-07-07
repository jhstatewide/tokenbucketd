import java.io.*;
import java.net.Socket;
import java.util.concurrent.TimeUnit;

public class TokenBucketClient {
    private String hostname;
    private int port;

    public TokenBucketClient(String hostname, int port) {
        this.hostname = hostname;
        this.port = port;
    }

    public void consume(String bucketName, Runnable callback) throws IOException, InterruptedException {
        try (Socket socket = new Socket(hostname, port);
             PrintWriter out = new PrintWriter(socket.getOutputStream(), true);
             BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()))) {

            while (true) {
                out.println("CONSUME " + bucketName);
                String response = in.readLine();
                String[] parts = response.split(" ");

                switch (parts[0]) {
                    case "OK":
                        callback.run();
                        return;
                    case "WAIT":
                        long sleepTime = (long) (Double.parseDouble(parts[1]) * 1000);
                        Thread.sleep(sleepTime);
                        break;
                    default:
                        throw new RuntimeException("Unknown response from server: " + response);
                }
            }
        }
    }

    // Example usage:
    // TokenBucketClient client = new TokenBucketClient("localhost", 2000);
    // client.consume("foo", () -> { /* do something */ });
}
