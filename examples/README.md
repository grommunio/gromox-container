# Run Grommunio in a Docker container

Starting and running the Grommunio container is a simple process. This is a quick installation guide for installing Gromununio in a Docker container


## Environment Set Up and Requirements

* Use the [official Docker](https://docs.docker.com/get-docker/) guide to ensure that docker is installed on your local machine.

## Installation Guide
* Create the required docker network
```
docker network create proxynet
```

* Create the required volume needed for persistent data to run the Grommunio container.
```
sudo docker volume create certificates
sudo docker volume create gromox-services
sudo docker volume create admin-plugins
sudo docker volume create admin-links
sudo docker volume create nginx
```

* Create the required certificates. An example command would be
```
openssl req -x509 -nodes -newkey rsa:4096 -keyout cert.key -out cert.pem -sha256 -days 365
```

* The docker volume needs to be populated before starting the contianer. Via the init container or using docker mount, populate each of the volume/mount using the `data-setup.sh` script.

    ```
    ./data-setup.sh
    ```


* Start all of the containers using the Docker compose command. The following services are required to run the grommunio container effectively.
  * Grommunio Container
  * MySQL Container (MariaDB)
```
sudo docker compose up
```


* You can log into the container to verify that thees files are properly linked in the **/home** directory.
  * Check for running containers and note the <container ID>;
    ```
    sudo docker container ls
    ```

  * The grommunio, redis, and MySQL containers should all already be running.


* Run and test the admin web interface url on your browser:

    ```
    https://localhost:8443/
    ```

**Default login details**

- Username - admin
- Password - admin
