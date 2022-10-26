# Notes

* ~~Set up FQDN for GROMOX~~
* ~~Use that FQDN for chat~~
* ~~Set up chat admin and password (read earlier setup script)~~
  * ~~set up admin-plugins-config to pull FQDN from an env var~~
* ~~Sort out line 439 - 441~~

* Make DB data persistent after creation so even if deployment restarts, data stays

* ~~Create custom docker images using gramm theme~~
  * ~~change helm chart to pull from grommunio repos~~

* Use s6-overlay and build the docker containers better

* Figure out how to mount multiple files in same config map to diff paths

* Test new docker container


## Practices to incorporate
* Use namespacees
* Use Autoscaling
* Use readiness and liveness probes
* Implement resource constraints
* Implement monitoring
* Use immutable images
* Automate certificate generation

