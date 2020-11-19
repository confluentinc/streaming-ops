package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;
import org.junit.jupiter.api.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;
import org.springframework.http.*;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.junit4.SpringRunner;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.Assert.*;

/**
 * Used the DEFINED_PORT because I had issues designing and organizing the tests and the app code in such
 * a way that I could pull in the configured, or dynamically allocated, port and have it read at config
 * time for OrderServiceConfig to cache the port for InteractiveQueries usage.
 */
@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
@EmbeddedKafka(topics = "orders")
@EnableKafka
@EnableKafkaStreams
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@ActiveProfiles("test")
class OrdersServiceApplicationTests {

  private final Logger logger = LoggerFactory.getLogger(OrdersServiceApplicationTests.class);

  @LocalServerPort
  private int port;

  @Autowired
  private TestRestTemplate restTemplate;

  @Autowired
  private EmbeddedKafkaBroker testBroker;

  @Test
  void shouldBeHealthy() throws Exception {
    var result = this.restTemplate.getForObject(
      "http://localhost:" + port + "/actuator/health",
      String.class);
    assertThat(result).contains("UP");
  }

  @Test
  public void shouldGetValidatedOrderOnRequest() throws Exception {

    String ordId = UUID.randomUUID().toString();
    Order testOrder = new Order(ordId, 123L,
      OrderState.CREATED, Product.JUMPERS, 1, 10D);

    HttpHeaders headers = new HttpHeaders();
    headers.add("Content-Type", MediaType.APPLICATION_JSON_VALUE);
    HttpEntity<String> request = new HttpEntity<String>(testOrder.toString(), headers);

    ResponseEntity<String> postResponse = this.restTemplate.postForEntity(
      "http://localhost:" + port + "/v1/orders",
      request,
      String.class);

    assertEquals(HttpStatus.CREATED, postResponse.getStatusCode());

    Thread.sleep(2000);

    //Simulate the order being validated
    Map<String, Object> configs = new HashMap<>(
      KafkaTestUtils.consumerProps("test-group", "false", testBroker));

    configs.put("schema.registry.url", "mock://orders-service");
    configs.put("key.serializer", StringSerializer.class.getName());
    configs.put("value.serializer", KafkaAvroSerializer.class.getName());

    Producer<String, Order> producer = new DefaultKafkaProducerFactory<String, Order>(configs).createProducer();

    Order validatedOrder = Order
      .newBuilder(testOrder)
      .setState(OrderState.VALIDATED).build();

    RecordMetadata produceResult = producer
      .send(new ProducerRecord<>("orders", validatedOrder.getId(), validatedOrder)).get();

    Thread.sleep(2000);

    Optional<Order> responseOrder = Optional.empty();
    int maxRetry = 10, tries = 0;
    while(responseOrder.isEmpty() && tries <= maxRetry) {
      tries = tries + 1;
      ResponseEntity<Order> getResponse = restTemplate.getForEntity(
        "http://localhost:" + port + "/v1/orders/" + ordId + "/validated",
        Order.class);
      if (getResponse.getStatusCode() == HttpStatus.OK) {
        responseOrder = Optional.of(getResponse.getBody());
      }
      else {
        Thread.sleep(1000);
      }
    }

    assertFalse(responseOrder.isEmpty());
    assertEquals(validatedOrder, responseOrder.get());
  }

}
