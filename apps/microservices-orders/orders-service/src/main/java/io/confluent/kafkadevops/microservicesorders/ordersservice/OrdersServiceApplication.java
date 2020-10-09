package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/*
  TODO:
   * https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/#boot-features-application-availability
 */
@SpringBootApplication
public class OrdersServiceApplication {

	public static void main(String[] args) {
		SpringApplication.run(OrdersServiceApplication.class, args);
	}

}
