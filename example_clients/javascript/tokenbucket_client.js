const net = require('net');

class TokenBucketClient {
    constructor(hostname, port) {
        this.server = net.createConnection({ host: hostname, port: port });
        this.server.setEncoding('utf8');
    }

    async consume(bucketName, callback) {
        this.server.write(`CONSUME ${bucketName}\n`);
        for await (const data of this.server) {
            const [status, ...rest] = data.split(' ');

            switch (status) {
                case 'OK':
                    this.server.end();
                    return callback();
                case 'WAIT':
                    const [sleepTime, ..._] = rest;
                    await new Promise(resolve => setTimeout(resolve, sleepTime * 1000));
                    this.server.write(`CONSUME ${bucketName}\n`);
                    break;
                default:
                    this.server.end();
                    throw new Error(`Unknown response from server: ${data}`);
            }
        }
    }
}

// Example usage:
/*
const client = new TokenBucketClient('localhost', 2000);
client.consume('foo', () => {
  // do something
});
*/
