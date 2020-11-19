package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.kafka.streams.serdes.avro.SpecificAvroSerde;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class OrdersProcessor {
  public static final String STATE_STORE = "orders-table";
  private static final Logger logger = LoggerFactory.getLogger(OrdersProcessor.class);

  private final SchemaRegistryConfig srConfig;
  private final String topic;

  @Autowired
  public OrdersProcessor(final SchemaRegistryConfig schemaRegistryConfig,
                         @Value("${orders-topic.name}") final String ordersTopic) {
    logger.info("Constructing OrdersProcessor: {} {}", ordersTopic, schemaRegistryConfig.url);
    this.srConfig = schemaRegistryConfig;
    this.topic = ordersTopic;
  }

  private Serde<Order> orderValueSerde() {
    SpecificAvroSerde<Order> rv = new SpecificAvroSerde<>();
    rv.configure(srConfig.buildPropertiesMap(), false);
    return rv;
  }

  @Autowired
  public void orderTable(final StreamsBuilder builder) {
    logger.info("Building orderTable");
    builder
      .table(
        this.topic,
        Consumed.with(Serdes.String(), orderValueSerde()),
        Materialized.as(STATE_STORE))
      .toStream()
      .peek((k,v) -> logger.info("Table Peek: {}", v));
  }
}
