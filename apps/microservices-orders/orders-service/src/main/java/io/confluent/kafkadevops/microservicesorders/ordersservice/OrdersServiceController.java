package io.confluent.kafkadevops.microservicesorders.ordersservice;

import com.fasterxml.jackson.databind.MapperFeature;
import fj.data.Either;
import io.confluent.examples.streams.avro.microservices.Order;
import io.confluent.examples.streams.avro.microservices.OrderState;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.state.HostInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.json.Jackson2ObjectMapperBuilder;
import org.springframework.kafka.config.KafkaStreamsConfiguration;
import org.springframework.kafka.support.SendResult;
import org.springframework.scheduling.annotation.Async;
import org.springframework.util.concurrent.ListenableFutureCallback;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.context.request.async.DeferredResult;
import org.springframework.web.server.ResponseStatusException;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Duration;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import static java.lang.Integer.parseInt;

@RestController
@RequestMapping(value = "/v1")
public class OrdersServiceController {

  private final Logger logger = LoggerFactory.getLogger(OrdersServiceController.class);

  private final OrderProducer producer;
  private final DistributedOrderStore ordersStore;

  /**
   * Configuring this Bean allows Avro objects to be serialized by
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
                          final DistributedOrderStore store) {
    Objects.requireNonNull(orderProducer);
    Objects.requireNonNull(store);
    this.producer = orderProducer;
    this.ordersStore = store;
  }

  @GetMapping(value = "/orders/{id}",
    produces = "application/json")
  public DeferredResult<ResponseEntity<Order>> getOrder(@PathVariable String id,
                         @RequestParam Optional<Long> timeout) {

    final DeferredResult<ResponseEntity<Order>> httpResult = new DeferredResult<>(timeout.orElse(5000L));

    logger.info("getOrder: id:{}\ttimeout:{}", id, timeout);

    ordersStore
      .getAsync(id)
      .thenAcceptAsync((orderResult) -> {
        if (orderResult.isLeft()) {
          logger.error(String.format("Error retrieving order for id: {}",id), orderResult.left().value());
          httpResult.setResult(ResponseEntity.notFound().build());
        }
        else {
          httpResult.setResult(ResponseEntity.ok(orderResult.right().value()));
        }
      });

    return httpResult;
  }

  @GetMapping(value = "/orders/{id}/validated",
    produces = "application/json")
  public DeferredResult<ResponseEntity<Order>> getValidatedOrder(@PathVariable String id,
                                                 @RequestParam Optional<Long> timeout) {

    final DeferredResult<ResponseEntity<Order>> httpResult = new DeferredResult<>(timeout.orElse(5000L));

    logger.info("getValidatedOrder: id:{}\ttimeout:{}", id, timeout);

    ordersStore
      .getAsync(id)
      .thenAcceptAsync((orderResult) -> {
        if (orderResult.isLeft()) {
          logger.error(String.format("Error retrieving order for id: {}",id), orderResult.left().value());
          httpResult.setResult(ResponseEntity.notFound().build());
        }
        else {
          Order foundOrder = orderResult.right().value();
          if (foundOrder.getState() == OrderState.VALIDATED || foundOrder.getState() == OrderState.FAILED) {
            httpResult.setResult(ResponseEntity.ok(foundOrder));
          }
          else {
            httpResult.setResult(ResponseEntity.notFound().build());
          }
        } })
      .orTimeout(timeout.orElse(5000L*3L), TimeUnit.MILLISECONDS);

    return httpResult;
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
