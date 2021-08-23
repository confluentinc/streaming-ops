package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.apache.kafka.streams.KafkaStreams;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.request.async.DeferredResult;

import java.util.Optional;

@Component
@RestController
@RequestMapping(value = "/v1")
public class HealthCheckService {
  final private StreamsBuilderFactoryBean kafkaStreamsFactory;
  final private static long DEFAULT_TIMEOUT_MILLIS=5000L;

  @Autowired
  public HealthCheckService(final StreamsBuilderFactoryBean kafkaStreamsFactory) {
    this.kafkaStreamsFactory = kafkaStreamsFactory;
  }

  @GetMapping(value = "/healthcheck", produces = "application/json")
  public DeferredResult<ResponseEntity> getTopologyState(@RequestParam Optional<Long> timeout) {
    final KafkaStreams kafkaStreams = this.kafkaStreamsFactory.getKafkaStreams();
    final DeferredResult<ResponseEntity> httpResult = new DeferredResult<>(timeout.orElse(DEFAULT_TIMEOUT_MILLIS));

    switch (kafkaStreams.state()) {
      case RUNNING:
        httpResult.setResult(ResponseEntity.status(HttpStatus.OK).build());
        break;
      case REBALANCING:
      case CREATED:
      case NOT_RUNNING:
      case PENDING_SHUTDOWN:
        httpResult.setResult(ResponseEntity.status(HttpStatus.NOT_FOUND).build());
        break;
      case ERROR:
        httpResult.setResult(ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build());
        break;
    }

    return httpResult;
  }
}
