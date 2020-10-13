package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.util.concurrent.ListenableFuture;

import java.util.concurrent.CompletableFuture;

@Service
public class OrderProducer {

  private static final Logger logger = LoggerFactory.getLogger(OrderProducer.class);

  @Value("${orders-topic.name}")
  private String topic;

  @Autowired
  private KafkaTemplate<String, Order> kafkaTemplate;

  @Async
  public ListenableFuture<SendResult<String, Order>> produceOrder(Order order) {
    logger.info("producing {} to {}", order, topic);
    return kafkaTemplate.send(this.topic, order.getId(), order);
  }

}
