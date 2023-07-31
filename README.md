# TokenBucket Server

This is a Ruby project implementing a TCP server that uses the Token Bucket algorithm. The Token Bucket algorithm is a network traffic shaping algorithm that provides a way to control the amount of incoming data. The server can accept multiple connections, track different "buckets" and manage token rate and capacity on a per-bucket basis.

## CI Status
![GitHub CI](https://github.com/jhstatewide/tokenbucketd/actions/workflows/ruby.yml/badge.svg)

## Use Cases

- Rate limiting
- Throttling
- Traffic shaping
- Request limiting

## Rationale

I was working on a project with distributed workers that would access APIs from many different domains. 
This way I can have each worker create a bucket for each domain and limit the number of requests per second to each domain.
This prevents the workers from getting banned by the APIs for sending too many requests, and is 
easy to configure and manage.

## Features

- Token bucket algorithm implementation
- Multithreaded TCP Server to handle multiple clients
- Automatic garbage collection for inactive buckets
- Configuration of bucket rate and capacity
- Bucket status reporting

## Installation

Make sure you have Ruby installed on your system. You can then clone this repository using the following command:

```bash
$ git clone https://github.com/jhstatewide/tokenbucketd.git
```

## Usage

To start the server, you need to initialize it with the following parameters:

- `port`: The port on which the server will be listening.
- `rate`: The token refill rate.
- `capacity`: The maximum capacity of the token bucket.
- `gc_interval`: The time in seconds between each automatic garbage collection cycle.
- `gc_threshold`: The idle time in seconds after which a bucket gets garbage collected.
- `max_buckets`: The maximum number of buckets that can be created.

An example of starting the server could look like this:

```bash
$ ruby ./bin/tokenbucketd --port 2000 --rate 10 --capacity 100 --gc-interval 60 --gc-threshold 300 --max-buckets 100
```

## Docker

You can also run the server using Docker. To do so, you need to build the Docker image first:

```bash
$ docker build -t tokenbucketd .
```

Then you can run the server using the following command:

```bash
$ docker run -p 2000:2000 tokenbucketd --port 2000 --rate 10 --capacity 100 --gc-interval 60 --gc-threshold 300 --max-buckets 100
```

## Protocol

The protocol is a line based protocol, which should be easy to integrate.
You can find an example client in ./lib/client.rb, and examples for other languages in ./example_clients.

Clients can send commands to the server via TCP:

- `CONSUME bucket_name`: consumes a token from the specified bucket. If the bucket does not exist, it is created. If no tokens are available, the server responds with a `WAIT` message, along with how many seconds the client should wait before trying again.
- `RATE bucket_name new_rate`: sets the token refill rate for the specified bucket.
- `CAPACITY bucket_name new_capacity`: sets the maximum capacity for the specified bucket.
- `STATS bucket_name`: fetches the current statistics of the specified bucket.
- `STATUS`: fetches the status of all the buckets and connected clients.
- `LOCK bucket_name`: locks the specified bucket. This prevents other clients from consuming tokens from the bucket. If the bucket is already locked, the server responds with a `WAIT` message, along with how many seconds the client should wait before trying again.
- `RELEASE bucket_name`: releases the specified bucket. This allows other clients to consume tokens from the bucket.

If an error occurs, the server will return a message starting with `ERROR`. 

### Notes on concurrency

The server is multithreaded, so it can handle multiple clients at the same time. However, the server is not thread-safe, so it is not possible to send multiple commands from the same client at the same time. If you need to do this, you can create multiple connections to the server.

If more than one client tries to consume a token from the same bucket at the same time, the server will respond with a `WAIT` message to all but one of the clients. The client that had gotten the server mutex first will be able to consume a token, while the other clients will have to wait.s

## Contributing

Feel free to open an issue or submit a pull request if you want to improve this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

