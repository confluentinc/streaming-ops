package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.test.utils.KafkaTestUtils;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

public class KafkaTestUtilities {
  // public static Consumer<String, Order> configureConsumer(String bootstrapServers, String outputTopicName) {
  //   Map<String, Object> consumerProps = KafkaTestUtils.consumerProps(
  //     String.join(",", bootstrapServers), "testGroup", "true");
  //   consumerProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
  //   Consumer<String, Order> consumer = new DefaultKafkaConsumerFactory<>(consumerProps,
  //     new StringDeserializer(), new KafkaAvroDeserializer())
  //     .createConsumer();
  //   consumer.subscribe(Collections.singleton(outputTopicName));
  //   return consumer;
  // }

  //public static Producer<String, String> configureProducer(String bootstrapServers) {
  //  Map<String, Object> producerProps = new HashMap<>(KafkaTestUtils.producerProps(
  //    String.join(",", bootstrapServers)));
  //  return new DefaultKafkaProducerFactory<>(producerProps,
  //    new StringSerializer(), new StringSerializer()).createProducer();
  //}
}
