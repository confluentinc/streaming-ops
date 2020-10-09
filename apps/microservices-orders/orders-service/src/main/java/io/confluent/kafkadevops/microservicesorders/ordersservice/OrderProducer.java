package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class OrderProducer {

  private static final Logger logger = LoggerFactory.getLogger(OrderProducer.class);

  @Value("${orders-topic.name}")
  private String topic;

  @Autowired
  private KafkaTemplate<String, Order> kafkaTemplate;

  public void produceOrder(Order order) {
    logger.info("producing {} to {}", order, topic);
    kafkaTemplate.send(this.topic, order.getId(), order);
  }

}
