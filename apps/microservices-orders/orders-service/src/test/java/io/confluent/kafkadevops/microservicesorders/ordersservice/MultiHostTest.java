package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.junit4.SpringRunner;

@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
@EmbeddedKafka(topics = "orders")
@EnableKafka
@EnableKafkaStreams
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@ActiveProfiles("test")
public class MultiHostTest {

  @Test
  public void shouldSupportQueriesAcrossPartitionsAcrossNodes() throws Exception {

    //Thread.sleep(1000*5);

    //RestTemplate restClient = new RestTemplate();
    //String response = restClient.getForObject("http://localhost:9000/actuator/health", String.class);
    //assertNotNull(response);
    //Thread.sleep(1000*50);
  }
}
