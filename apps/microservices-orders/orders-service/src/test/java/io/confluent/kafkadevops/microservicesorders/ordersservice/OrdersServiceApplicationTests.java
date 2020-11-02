package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.awaitility.Awaitility;
import org.junit.Assert;
import org.junit.jupiter.api.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;
import org.springframework.http.*;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.context.junit4.SpringRunner;
import scala.concurrent.Await;

import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.Assert.*;

@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@EmbeddedKafka
@EnableKafka
@EnableKafkaStreams
class OrdersServiceApplicationTests {

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
  void shouldNotReturnOrder() throws Exception {
    var missingOrderId = UUID.randomUUID().toString();
    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/orders/" + missingOrderId,
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(404, response.getStatusCodeValue());
  }
  @Test
  void postOrderShouldReturn_201() throws Exception {

    Order testOrder = new Order("123", 123L,
      OrderState.CREATED, Product.JUMPERS, 1, 10D);

    HttpHeaders headers = new HttpHeaders();
    headers.add("Content-Type", MediaType.APPLICATION_JSON_VALUE);
    HttpEntity<String> request = new HttpEntity<String>(testOrder.toString(), headers);

    ResponseEntity<String> response = this.restTemplate.postForEntity(
      "http://localhost:" + port + "/v1/orders",
      request,
      String.class);

    assertEquals(HttpStatus.CREATED, response.getStatusCode());
  }
  @Test
  void postOrderThenGetOrderShouldWork() throws Exception {

    testBroker.addTopics("orders");

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

    Optional<Order> responseOrder = Optional.empty();
    int maxRetry = 10, tries = 0;
    while(responseOrder.isEmpty() && tries <= maxRetry) {
      tries = tries + 1;
      ResponseEntity<Order> getResponse = restTemplate.getForEntity(
        "http://localhost:" + port + "/v1/orders/" + ordId,
        Order.class);
      if (getResponse.getStatusCode() == HttpStatus.OK) {
        responseOrder = Optional.of(getResponse.getBody());
      }
      else {
        Thread.sleep(1000);
      }
    }

    assertFalse(responseOrder.isEmpty());
    assertEquals(testOrder, responseOrder.get());
  }
}
