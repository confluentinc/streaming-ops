## Orders Service

This is a re-write of the OrdersService found in the Confluent [Microservices Demos examples](https://github.com/confluentinc/kafka-streams-examples/tree/6.0.0-post/src/main/java/io/confluent/examples/streams/microservices)
using the Spring Framework.

## Building

The project contains a `Makefile` for managing build and package.

|            |                                           |
|------------|-------------------------------------------|
| `make clean` |will clean build artifacts|
| `make test`  |will run provide unit and integration tests|
| `make build` |will build a single shadow jar for running the application|
| `make package` |will build a Docker image|
| `make publish` |will build and publish the Docker image to the cnfldemos Confluent Docker Hub repository|

## Configuring

This application builds on the Spring Framework and uses [Spring Application Property Files](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-external-config-application-property-files).
Configuration can be overridden using many methods [(docs)](https://docs.spring.io/spring-boot/docs/1.5.6.RELEASE/reference/html/boot-features-external-config.html).
