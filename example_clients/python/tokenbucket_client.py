import socket
import time

class TokenBucketClient:
    def __init__(self, hostname, port):
        self.hostname = hostname
        self.port = port

    def consume(self, bucket_name, callback):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.connect((self.hostname, self.port))

            while True:
                s.sendall(f"CONSUME {bucket_name}\n".encode())
                response = s.recv(1024).decode().strip()
                status, *rest = response.split(' ')

                if status == 'OK':
                    return callback()
                elif status == 'WAIT':
                    sleep_time = float(rest[0])
                    time.sleep(sleep_time)
                else:
                    raise Exception(f"Unknown response from server: {response}")

# Example usage:
# client = TokenBucketClient('localhost', 2000)
# client.consume('foo', lambda: print("Running some operation..."))
