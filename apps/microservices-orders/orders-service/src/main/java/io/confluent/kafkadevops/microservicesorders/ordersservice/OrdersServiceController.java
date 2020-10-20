package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.stream.binder.kafka.streams.InteractiveQueryService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
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
  public Order getValidatedOrder(@PathVariable String id,
                                 @RequestParam Optional<Long> timeout) {
    logger.info("getValidatedOrder: id:{}\ttimeout:{}", id, timeout);
    return null;
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
