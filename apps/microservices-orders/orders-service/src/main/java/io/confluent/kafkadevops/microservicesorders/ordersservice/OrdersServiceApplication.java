package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.state.HostInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.config.KafkaStreamsConfiguration;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.HashMap;
import java.util.Map;

import static java.lang.Integer.parseInt;

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
