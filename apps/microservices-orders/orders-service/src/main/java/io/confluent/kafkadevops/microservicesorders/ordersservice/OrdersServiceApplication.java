package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;

/*
  TODO:
   * https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#boot-features-application-availability
 */
@SpringBootApplication
@EnableKafka
@EnableKafkaStreams
public class OrdersServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(OrdersServiceApplication.class, args);
  }
}
