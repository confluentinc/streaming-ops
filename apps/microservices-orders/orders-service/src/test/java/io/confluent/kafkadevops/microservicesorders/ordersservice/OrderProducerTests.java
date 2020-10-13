package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.apache.kafka.clients.consumer.Consumer;
import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.awaitility.Awaitility;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.context.junit4.SpringRunner;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.*;

@RunWith(SpringRunner.class)
@SpringBootTest
@EmbeddedKafka
public class OrderProducerTests {

  private Logger logger = LoggerFactory.getLogger(OrderProducerTests.class);

  @Autowired
  private KafkaProperties properties;

  @Autowired
  private OrderProducer producer;

  @Test
  public void testSend() throws InterruptedException {
    Order o1 = new Order("123", 123L, OrderState.CREATED, Product.UNDERPANTS, 1, 8.34);
    Order o2 = new Order("123", 123L, OrderState.CREATED, Product.UNDERPANTS, 1, 8.34);

    List<Order> producedOrders = List.of(o1, o2);
    producedOrders.forEach(producer::produceOrder);

    Consumer<String, Order> consumer = new DefaultKafkaConsumerFactory<String, Order>(
      properties.buildConsumerProperties()).createConsumer();
    consumer.subscribe(Collections.singleton("orders"));

    List<Order> actual = new CopyOnWriteArrayList<>();
    ExecutorService service = Executors.newSingleThreadExecutor();
    Future<?> consumingTask = service.submit(() -> {
      while (!Thread.currentThread().isInterrupted()) {
        ConsumerRecords<String, Order> records = KafkaTestUtils.getRecords(consumer, 100);
        for (ConsumerRecord<String, Order> rec : records) {
          actual.add(rec.value());
        }
      }
    });

    try {
      Awaitility.await().atMost(5, TimeUnit.MINUTES)
        .until(() -> actual.equals(producedOrders));
    } finally {
      consumingTask.cancel(true);
      service.awaitTermination(100, TimeUnit.MILLISECONDS);
    }
  }
}
