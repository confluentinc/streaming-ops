package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.junit.Test;
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
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.junit4.SpringRunner;

import java.util.UUID;

import static org.junit.Assert.assertEquals;
import static org.assertj.core.api.Assertions.assertThat;

@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
@EmbeddedKafka(topics = "orders")
@EnableKafka
@EnableKafkaStreams
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@ActiveProfiles("test")
public class OrdersServiceRESTTests {

  private final Logger logger = LoggerFactory.getLogger(OrdersServiceRESTTests.class);

  @LocalServerPort
  private int port;

  @Autowired
  private TestRestTemplate restTemplate;

  @Autowired
  private EmbeddedKafkaBroker testBroker;

  @Test
  public void shouldBeHealthy() throws Exception {
    var result = this.restTemplate.getForObject(
      "http://localhost:" + port + "/actuator/health",
      String.class);
    assertThat(result).contains("UP");
  }
  @Test
  public void shouldNotReturnOrder() throws Exception {
    var missingOrderId = UUID.randomUUID().toString();
    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/v1/orders/" + missingOrderId,
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(404, response.getStatusCodeValue());
  }
  @Test
  public void shouldNotReturnValidatedOrder() throws Exception {
    var missingOrderId = UUID.randomUUID().toString();
    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/v1/orders/" + missingOrderId + "/validated",
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(404, response.getStatusCodeValue());
  }
  @Test
  public void postOrderShouldReturn_201() throws Exception {

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

}
