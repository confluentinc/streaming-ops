package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.junit.ClassRule;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.test.rule.EmbeddedKafkaRule;
import org.springframework.test.context.junit4.SpringRunner;

import static org.assertj.core.api.Assertions.assertThat;

@RunWith(SpringRunner.class)
@SpringBootTest
public class OrderProducerTests {

  @Value("${orders-topic.name}")
  private static String topic;

  @Autowired
  private OrderProducer producer;

  @ClassRule
  public static EmbeddedKafkaRule kafka = new EmbeddedKafkaRule(
    1, true, "orders-test");

  @Test
  public void testSend() {
    producer.produceOrder(
      new Order("123", 123L, OrderState.CREATED,
        Product.UNDERPANTS, 1, 8.34));
    assertThat(true);
  }

}
