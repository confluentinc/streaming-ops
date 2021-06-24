package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import org.apache.kafka.clients.consumer.Consumer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.streams.KafkaStreams;
import org.awaitility.Awaitility;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.kafka.config.KafkaStreamsCustomizer;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.kafka.config.StreamsBuilderFactoryBeanCustomizer;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.test.EmbeddedKafkaBroker;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.kafka.test.utils.KafkaTestUtils;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.junit4.SpringRunner;

import java.time.Duration;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;


@Configuration
class HealthCheckConfiguration {
  private final Logger logger = LoggerFactory.getLogger(HealthCheckConfiguration.class);

  @Bean
  public StreamsBuilderFactoryBeanCustomizer streamsBuilderFactoryBeanCustomizer() {
    return factoryBean -> {
      factoryBean.setKafkaStreamsCustomizer(new KafkaStreamsCustomizer() {
        @Override
        public void customize(KafkaStreams kafkaStreams) {
          kafkaStreams.setUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(Thread thread, Throwable throwable) {
              logger.debug("NOOP Exception Handler %s", throwable.getMessage());
            }
          });
        }
      });
    };
  }
}

@RunWith(SpringRunner.class)
@SpringBootTest(
  webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
@EmbeddedKafka(topics = "orders")
@EnableKafka
@EnableKafkaStreams
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
@ActiveProfiles("test")
@Import({HealthCheckConfiguration.class})
public class HealthCheckServiceTest {
  private final static long STATE_CHANGE_TIMEOUT_SECONDS = 10L;
  private final static long STATE_CHANGE_POLL_INTERVAL_MILLIS = 10L;
  private final Logger logger = LoggerFactory.getLogger(HealthCheckServiceTest.class);
  @LocalServerPort
  private int port;

  @Autowired
  private TestRestTemplate restTemplate;

  @Autowired
  private EmbeddedKafkaBroker testBroker;

  @Autowired
  private StreamsBuilderFactoryBean kstreamsBuilderFactory;

  @Test
  public void shouldReturnOKWhenRunning() throws Exception {
    Awaitility.await()
      .timeout(Duration.ofSeconds(STATE_CHANGE_TIMEOUT_SECONDS))
      .until(() -> this.kstreamsBuilderFactory.getKafkaStreams().state() == KafkaStreams.State.RUNNING);

    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/v1/healthcheck",
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(HttpStatus.OK, response.getStatusCode());
  }

  @Test
  public void shouldReturnNotFoundWhenRebalancing() throws Exception {
    Map<String, Object> configs = new HashMap<>(
      KafkaTestUtils.consumerProps("OrdersService", "false", testBroker));
    Consumer<String, Order> consumer = new DefaultKafkaConsumerFactory<String, Order>(configs).createConsumer();
    consumer.subscribe(Collections.singleton("orders"));

    Awaitility.await()
      .timeout(Duration.ofSeconds(STATE_CHANGE_TIMEOUT_SECONDS))
      .pollInterval(Duration.ofMillis(STATE_CHANGE_POLL_INTERVAL_MILLIS))
      .until(() -> this.kstreamsBuilderFactory.getKafkaStreams().state() == KafkaStreams.State.REBALANCING);

    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/v1/healthcheck",
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
  }

  @Test
  public void testShouldReturnInternalErrorWhenError() throws Exception {
    Map<String, Object> producerProps =
      KafkaTestUtils.producerProps(testBroker);
    Producer<Integer, String> pf =
      new DefaultKafkaProducerFactory<Integer, String>(producerProps).createProducer();
    pf.send(new ProducerRecord<Integer, String>("orders", 10, "test"));
    pf.flush();

    Awaitility.await()
      .timeout(Duration.ofSeconds(STATE_CHANGE_TIMEOUT_SECONDS))
      .pollInterval(Duration.ofMillis(STATE_CHANGE_POLL_INTERVAL_MILLIS))
      .until(() -> this.kstreamsBuilderFactory.getKafkaStreams().state() == KafkaStreams.State.ERROR);

    var response = this.restTemplate.exchange(
      "http://localhost:" + port + "/v1/healthcheck",
      HttpMethod.GET, HttpEntity.EMPTY, String.class);
    assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
  }
}
