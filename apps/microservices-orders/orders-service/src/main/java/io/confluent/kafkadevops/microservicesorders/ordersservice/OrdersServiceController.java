package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping(value = "/v1")
public class OrdersServiceController {

  private final OrderProducer producer;
  private final Logger logger = LoggerFactory.getLogger(OrdersServiceController.class);

  @Autowired
  OrdersServiceController(OrderProducer orderProducer) {
    this.producer = orderProducer;
  }

  @GetMapping(value = "/orders/{id}",
    produces = "application/json")
  public Order getOrder(@PathVariable String id,
                         @RequestParam Optional<Long> timeout) {
    // TODO: Read from appropriate state store, or delegate to proper colleague
    logger.info("getOrder: id:{}\ttimeout:{}", id, timeout);
    return null;
  }

  @GetMapping(value = "/orders/{id}/validated",
    produces = "application/json")
  public Order getValidatedOrder(@PathVariable String id,
                                 @RequestParam Optional<Long> timeout) {
    logger.info("getValidatedOrder: id:{}\ttimeout:{}", id, timeout);
    return null;
  }

  @PostMapping(value = "/orders")
  @ResponseStatus(HttpStatus.CREATED)
  public void postOrder(@RequestBody Order order) {
    //TODO: Catch exceptions when producing and throw a ResponseStatusException
    logger.info("postOrder: order:{}", order);
    producer.produceOrder(order);
  }

}
