package io.confluent.kafkadevops.microservicesorders.ordersservice;

import com.fasterxml.jackson.databind.MapperFeature;
import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.kafka.support.SendResult;
import org.springframework.scheduling.annotation.Async;
import org.springframework.util.concurrent.ListenableFutureCallback;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import org.springframework.web.server.ResponseStatusException;

import java.util.Objects;
import java.util.Optional;

@RestController
@RequestMapping(value = "/v1")
public class OrdersServiceController {

  private final OrderProducer producer;

  private final Logger logger = LoggerFactory.getLogger(OrdersServiceController.class);

  private final StoreQueryParameters<ReadOnlyKeyValueStore<String, Order>> stateStoreQuery =
    StoreQueryParameters.fromNameAndType(OrdersProcessor.STATE_STORE, QueryableStoreTypes.keyValueStore());
  private final StreamsBuilderFactoryBean streamsFactory;

  /**
   * Configuring this Bean allows Avro objects to be seraizlied by
   * Jackson, otherwise, it attempts to serialize non-data values
   * @return
   */
  @Bean
  public Jackson2ObjectMapperBuilder objectMapperBuilder() {
    Jackson2ObjectMapperBuilder builder = new Jackson2ObjectMapperBuilder();
    builder.featuresToEnable(MapperFeature.REQUIRE_SETTERS_FOR_GETTERS);
    return builder;
  }

  @Autowired
  OrdersServiceController(final OrderProducer orderProducer,
                          final StreamsBuilderFactoryBean kafkaStreamsFactory) {
    Objects.requireNonNull(kafkaStreamsFactory);
    Objects.requireNonNull(orderProducer);
    this.producer = orderProducer;
    this.streamsFactory = kafkaStreamsFactory;
  }

  @GetMapping(value = "/orders/{id}",
    produces = "application/json")
  public ResponseEntity<Order> getOrder(@PathVariable String id,
                         @RequestParam Optional<Long> timeout) {

    // TODO: Or delegate to proper colleague
    logger.info("getOrder: id:{}\ttimeout:{}", id, timeout);
    Order rv = streamsFactory.getKafkaStreams().store(stateStoreQuery).get(id);
    logger.info("Retrieved: {}", rv);

    return ResponseEntity.ok(rv);
  }

  @GetMapping(value = "/orders/{id}/validated",
    produces = "application/json")
  public ResponseEntity<Order> getValidatedOrder(@PathVariable String id,
                                                 @RequestParam Optional<Long> timeout) {
    logger.info("getValidatedOrder: id:{}\ttimeout:{}", id, timeout);
    Order rv = streamsFactory.getKafkaStreams().store(stateStoreQuery).get(id);
    logger.info(rv.toString());

    if (rv == null || rv.getState() == OrderState.VALIDATED || rv.getState() == OrderState.FAILED)
      return ResponseEntity.ok(rv);
    else
      return ResponseEntity.notFound().build();
  }

  @PostMapping(value = "/orders")
  @Async
  public DeferredResult<ResponseEntity<?>> postOrder(@RequestBody Order order) {
    final DeferredResult<ResponseEntity<?>> httpResult = new DeferredResult<>();
    logger.info("postOrder: order:{}", order);
    producer.produceOrder(order).addCallback(new ListenableFutureCallback<SendResult<String, Order>>() {
      @Override
      public void onFailure(final Throwable ex) {
        throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, ex.getMessage(), ex);
      }
      @Override
      public void onSuccess(final SendResult<String, Order> result) {
        logger.info("Produce success: orderId = {}", result.getProducerRecord().value().getId());
        httpResult.setResult(new ResponseEntity(HttpStatus.CREATED));
      }
    });
    return httpResult;
  }

}
