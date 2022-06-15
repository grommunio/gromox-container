# gromox_container

This is the project prototype for running Grommunio using docker-compose

## Getting started

* Run with the following commands:
  ```
  docker compose build
  docker compose up -d
  ```

* Access containers using `docker exec`

## Caveats

* This project is still in the prototype stage which means a lot of things will be automated in the future e.g., configuration.
* Containers can speak to one another. However, getting the whole system to work seamlessly is still a work in progress.

