# IaC demo
## Project description

This project consists of three elements, namely:

1. Terraform is leveraged in order to create two PostgreSQL instances (a master and a read-only replica) using AWS Relational Database Service.
2. A Java application is created which connects to the PostgreSQL master instance created above and exposes two endpoints.
3. The application is deployed in Kubernetes, using a YAML manifest file. 

## Terraform Database Creation

The Terraform files are located in the `{project_root}/terraform/` directory.

Applying the configuration requires `aws` CLI tool to be available in the `$PATH` and configured with `aws_access_key_id` and `aws_secret_access_key`. 

The AWS database instance type was chosen to be `db.t2.micro` because it was the type provided in the AWS free tier. The PostgreSQL version allowed in this type is <13, so version 12.8 was chosen.

There is a master database and a read-only replica created. The master database's credentials are loaded from environment variables into two Terraform variables.
The environment variables names should be:
* `$TF_VAR_dbuser` for the username, and
* `$TF_VAR_dbpass` for the password.

In order to apply the configuration, we `cd` into the directory containing the Terraform files and we issue the following commands:
```shell
terraform init
terraform apply
```

Terraform _outputs_ the `address` which was assigned to the database. The address is used in order to connect the Java application to the database. The port is `5432`.


## Java Application

A Java application was created using the Quarkus framework.

It listens on port 8080, exposing two endpoints which are defined in the `WebResource` class:
* GET `/health`, which always returns an `HTTP 200` response when the app is running, and
* GET `/ready`, which attempts to establish a connection to the database, and if the connection was successful it returns an `HTTP 200`, otherwise it returns `HTTP 503`. 

In order to connect to the database, the application requires the following environment variables:
* `$POSTGRES_JDBC`, which is the database connection string as described below,
* `$POSTGRES_USER`, which is the database username that was also passed into Terraform,
* `$POSTGRES_PASS`, which is the database password that was also passed into Terraform.

Part of the database connection string is the address that was _output_ after applying Terraform configuration. The string itself should be a JDBC connection string, as follows:

```
jdbc:postgresql://<terraform_output_value>:5432/postgres
```

Packaging the application requires JDK 11 and Apache Maven to be installed and available in the `$PATH`.

The application can be packaged using `./mvnw clean package` in the project's root directory.

When packaging, it is also configured to automatically build a docker image with the properties defined in `src/main/resources/application.properties` (`group=kkokkino` and `name=iacdemo`). The image is registered in the local docker instance.

We can also push it to dockerhub in one step by running

```shell
./mvnw clean package -Dquarkus.container-image.push=true
```

## Kubernetes Deployment

The application can be deployed using the `kubernetes/minikube-manifest.yml` manifest file. It uses the `default` namespace.

The manifest file requires that the docker image have already been pushed to dockerhub, as it will try to pull it if it is not already in the local registry.
It creates a single-replica deployment exposed as a NodePort service on node port 31382.

The JDBC string should be entered in the manifest file, whereas the username and the password are retrieved from the `iacdemo` Kubernetes Secret which has the `username` and `password` keys.

Deploying locally using kubernetes requires installing Minikube and kubectl according to the official documentation.
Afterwards, the manifest is applied by issuing
```shell
kubectl apply -f <path-to-manifest.yml>
```

The manifest was tested on a local minikube instance, with the endpoint provided after running
```shell
minikube service iacdemo
```