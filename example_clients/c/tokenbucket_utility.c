#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <getopt.h>

#define BUFFER_SIZE 1024

void consume(char* hostname, int port, char* bucket_name) {
    struct sockaddr_in server_address;
    char buffer[BUFFER_SIZE];
    int socket_fd = socket(AF_INET, SOCK_STREAM, 0);

    if(socket_fd < 0) {
        perror("Cannot create socket");
        exit(EXIT_FAILURE);
    }

    memset(&server_address, 0, sizeof(server_address));
    server_address.sin_family = AF_INET;
    server_address.sin_port = htons(port);

    if(inet_pton(AF_INET, hostname, &server_address.sin_addr) <= 0) {
        perror("Invalid address");
        exit(EXIT_FAILURE);
    }

    if(connect(socket_fd, (struct sockaddr*)&server_address, sizeof(server_address)) < 0) {
        perror("Connection failed");
        exit(EXIT_FAILURE);
    }

    while (1) {
        sprintf(buffer, "CONSUME %s\n", bucket_name);
        send(socket_fd, buffer, strlen(buffer), 0);

        memset(buffer, 0, BUFFER_SIZE);
        read(socket_fd, buffer, BUFFER_SIZE);

        char* status = strtok(buffer, " ");
        if(strcmp(status, "OK") == 0) {
            printf("OK! Token received!\n");
            break;
        } else if(strcmp(status, "WAIT") == 0) {
            float sleep_time;
            sscanf(strtok(NULL, " "), "%f", &sleep_time);
            usleep(sleep_time * 1000000);
        } else {
            fprintf(stderr, "Unknown response from server: %s\n", buffer);
            break;
        }
    }

    close(socket_fd);
}

int main(int argc, char* argv[]) {
    char* hostname = NULL;
    int port;
    char* bucket_name = NULL;

    int opt;
    while ((opt = getopt(argc, argv, "h:p:b:")) != -1) {
        switch (opt) {
            case 'h':
                hostname = optarg;
                break;
            case 'p':
                port = atoi(optarg);
                break;
            case 'b':
                bucket_name = optarg;
                break;
            default:
                fprintf(stderr, "Usage: %s -h hostname -p port -b bucket_name\n", argv[0]);
                exit(EXIT_FAILURE);
        }
    }

    if (hostname == NULL || bucket_name == NULL) {
        fprintf(stderr, "Hostname and bucket name must be specified\n");
        exit(EXIT_FAILURE);
    }

    consume(hostname, port, bucket_name);

    return 0;
}
