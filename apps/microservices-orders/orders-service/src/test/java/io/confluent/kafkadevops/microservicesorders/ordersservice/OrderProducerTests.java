package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.kafka.serializers.KafkaAvroDeserializer;
import org.apache.kafka.clients.consumer.Consumer;
import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.awaitility.Awaitility;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.junit4.SpringRunner;

import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.*;

@RunWith(SpringRunner.class)
@SpringBootTest
@EmbeddedKafka
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
public class OrderProducerTests {

  private final Logger logger = LoggerFactory.getLogger(OrderProducerTests.class);

  @Autowired
  private OrderProducer producer;

  @Autowired
  private EmbeddedKafkaBroker testBroker;

  @Test
  public void testSend() throws Exception {
    Order o1 = new Order("123", 123L, OrderState.CREATED, Product.UNDERPANTS, 1, 8.34);
    Order o2 = new Order("987", 987L, OrderState.CREATED, Product.JUMPERS, 2, 5.12);

    List<Order> producedOrders = List.of(o1, o2);
    producedOrders.forEach(producer::produceOrder);

    Map<String, Object> configs = new HashMap<>(
      KafkaTestUtils.consumerProps("test-group", "false", testBroker));

    configs.put("schema.registry.url", "mock://orders-service");
    configs.put("key.deserializer",StringDeserializer.class.getName());
    configs.put("value.deserializer",KafkaAvroDeserializer.class.getName());
    configs.put("specific.avro.reader", "true");

    Consumer<String, Order> consumer = new DefaultKafkaConsumerFactory<String, Order>(configs).createConsumer();
    consumer.subscribe(Collections.singleton("orders"));

    ExecutorService service = Executors.newSingleThreadExecutor();
    Future<List<Order>> consumingTask = service.submit(() -> {
      List<Order> actual = new CopyOnWriteArrayList<>();
      while (actual.size() < producedOrders.size() && !Thread.currentThread().isInterrupted()) {
        ConsumerRecords<String, Order> records = KafkaTestUtils.getRecords(consumer, 100);
        for (ConsumerRecord<String, Order> rec : records) {
          actual.add(rec.value());
        }
      }
      return actual;
    });

    try {

      Awaitility
        .await()
        .atMost(5, TimeUnit.MINUTES)
        .pollInterval(10, TimeUnit.MILLISECONDS)
        .until(() -> consumingTask.isDone());

      assertEquals(producedOrders, consumingTask.get());

    } catch (ExecutionException ex) {
      fail(ex.getMessage());
    }
    finally {
      if ( ! consumingTask.isDone() )
        consumingTask.cancel(true);
      service.awaitTermination(100, TimeUnit.MILLISECONDS);
    }
  }
}
