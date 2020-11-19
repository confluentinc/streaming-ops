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

@Service
public class OrderProducer {

  private static final Logger logger = LoggerFactory.getLogger(OrderProducer.class);

  private final String topic;

  private final KafkaTemplate<String, Order> kafka;

  @Autowired
  public OrderProducer(final KafkaTemplate<String, Order> kafkaTemplate,
                       @Value("${orders-topic.name}") final String kafkaTopic) {
    this.topic = kafkaTopic;
    this.kafka = kafkaTemplate;
  }

  @Async
  public ListenableFuture<SendResult<String, Order>> produceOrder(Order order) {
    logger.info("producing {} to {}", order, topic);
    return kafka.send(this.topic, order.getId(), order);
  }

}
