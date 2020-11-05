package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import io.confluent.examples.streams.avro.microservices.Product;
import org.junit.Test;
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
import org.springframework.test.context.event.annotation.BeforeTestClass;
import org.springframework.test.context.junit4.SpringRunner;

import java.util.UUID;

import static org.junit.Assert.assertEquals;
import static org.assertj.core.api.Assertions.assertThat;

@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@EmbeddedKafka
@EnableKafka
@EnableKafkaStreams
public class OrdersServiceRESTTests {
  @LocalServerPort
  private int port;

  @Autowired
  private TestRestTemplate restTemplate;

  @Autowired
  private EmbeddedKafkaBroker testBroker;

  @BeforeTestClass
  public void before() {
    System.out.println("Adding orders topic");
    testBroker.addTopics("orders");
  }

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
      "http://localhost:" + port + "/orders/" + missingOrderId,
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
