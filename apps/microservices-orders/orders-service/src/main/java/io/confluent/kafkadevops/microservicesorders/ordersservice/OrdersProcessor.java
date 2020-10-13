package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.kafka.schemaregistry.client.SchemaRegistryClient;
import io.confluent.kafka.streams.serdes.avro.SpecificAvroSerde;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.utils.Bytes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.apache.kafka.streams.state.KeyValueStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.stream.annotation.Input;
import org.springframework.cloud.stream.annotation.Output;
import org.springframework.cloud.stream.annotation.StreamListener;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.messaging.handler.annotation.SendTo;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.function.Function;

@SpringBootApplication
@EnableKafkaStreams
public class OrdersProcessor {
  public static final String STATE_STORE = "orders";
  private static final Logger logger = LoggerFactory.getLogger(OrdersProcessor.class);

  @Value("${spring.kafka.properties.schema.registry.url}")
  private String schemaRegistryUrl;

  @Bean
  public Serde<Order> orderValueSerde() {
    final Properties config = new Properties();
    config.put("schema.registry.url", schemaRegistryUrl);
    Map<String, Object> map = new HashMap<>();
    for (final String name: config.stringPropertyNames())
      map.put(name, config.getProperty(name));
    SpecificAvroSerde<Order> rv = new SpecificAvroSerde<>();
    rv.configure(map, false);
    return rv;
  }

  @Bean
  KTable<String, Order> ordersTable(final StreamsBuilder builder) {
    logger.info("ordersTable called");
    return builder.table("orders",
      Consumed.with(Serdes.String(), orderValueSerde()),
      Materialized.as("orders-table"));
  }

}
