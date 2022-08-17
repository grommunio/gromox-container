# Setting up Gromox k8s Cluster

  The instructions for setting up Gromox on a k8s cluster. 
  **Note: this is not secure nor highly available and should not be used in production environments. It is for testing purposes**

* Set up a k8s cluster. You can install [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) or [Minikube](https://minikube.sigs.k8s.io/docs/start/)
  * This setup was tested using [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

* Create the config map for the database on the cluster using:
  ```
  kubectl apply -f db-config.yaml
  ```
  You can edit this file to specify your database parameters. 

* Create the config map containing the ssl certificates. 
  ```
  kubectl apply -f ssl-config.yaml
  ```
  
* Create the config map containing the redis configuration. 
  ```
  kubectl apply -f redis-config.yaml
  ```

* Create the config map containing the password for the Grommunio Admin API. 
  ```
  kubectl apply -f admin-config.yaml
  ```

* Create the config map containing the redis plugin configuration for the Grommunio Admin API. 
  ```
  kubectl apply -f admin-plugins-config.yaml
  ```

* Create the config map containing the links configuration for the Grommunio Admin API. 
  ```
  kubectl apply -f admin-links-config.yaml
  ```

* Set up Redis.
  ```
  kubectl apply -f redis.yaml
  ```

* Set up the database. You can also bring your database, just configure it in the `db-config.yaml`
  ```
  kubectl apply -f db.yaml
  ```

* Initialize the database. Ensure the database is available and running first before this step.
  ```
  kubectl apply -f init-db.yaml
  ```

* Set up gromox. Gromox bundles all the necessary services into a single pod. You can scale up or down to as many pods as necessary in `gromox.yaml`
  ```
  kubectl apply -f gromox.yaml
  ```

* Grommunio web is available by running the following command (for now, it will be resolved in the soon):
  ```
  kubectl port-forward service/gromox-service 5050:443
  ```
  Then access the GUI with `https://<your ip>:5050/web/`

* Grommunio admin is available by running the following command (for now, it will be resolved in the soon):
  ```
  kubectl port-forward service/gromox-service 5000:8443
  ```
  Then access the GUI with `https://<your ip>:5000/web/`

