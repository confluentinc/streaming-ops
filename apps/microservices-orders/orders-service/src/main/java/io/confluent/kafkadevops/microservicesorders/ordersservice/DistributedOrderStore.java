package io.confluent.kafkadevops.microservicesorders.ordersservice;

import io.confluent.examples.streams.avro.microservices.Order;
import io.vavr.control.Either;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyQueryMetadata;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.errors.InvalidStateStoreException;
import org.apache.kafka.streams.state.HostInfo;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.concurrent.CompletableFuture;

@Component
public class DistributedOrderStore {

  class StateStoreNotRunning extends Exception { }

  private final StoreQueryParameters<ReadOnlyKeyValueStore<String, Order>> stateStoreQuery =
    StoreQueryParameters.fromNameAndType(OrdersProcessor.STATE_STORE, QueryableStoreTypes.keyValueStore());
  private final StringSerializer keySerializer = new StringSerializer();

  private final StreamsBuilderFactoryBean streamsFactory;
  private final HostInfo localInstanceHostInfo;

  @Autowired
  public DistributedOrderStore(
    final StreamsBuilderFactoryBean kafkaStreamsFactory,
    final HostInfo thisInstanceHostInfo) {
    streamsFactory = kafkaStreamsFactory;
    localInstanceHostInfo = thisInstanceHostInfo;
  }

  private Either<Exception, KeyQueryMetadata> getKeyMeta(String id) {
    try {
      return Either.right(streamsFactory.getKafkaStreams()
        .queryMetadataForKey(OrdersProcessor.STATE_STORE, id, keySerializer));
    } catch (IllegalStateException ex) {
      return Either.left(ex);
    }
  }
  private Mono<Order> getOrderFromRemote(String id, HostInfo hostInfo) {
    return WebClient
      .create(String.format("http://%s:%s", hostInfo.host(), hostInfo.port()))
      .get()
      .uri("/v1/orders/" + id)
      .retrieve()
      .bodyToMono(Order.class);
  }
  private Either<Exception, Order> getOrderGlobally(String id, KeyQueryMetadata keyMeta) {
    if (keyMeta.getActiveHost().equals(localInstanceHostInfo))
      return getLocalOrder(id);
    else {
      try {
        return Either.right(getOrderFromRemote(id, keyMeta.getActiveHost()).block());
        //// TODO: Implement standby host retrieval
        //Either<Exception, Order> rv = Either.left(new Exception(String.format("Order %s not found", id)));
        //for (HostInfo hi : keyMeta.getStandbyHosts()) {
        //  try {
        //    rv = Either.right(getOrderFromRemote(id, hi).block());
        //    break;
        //  } catch (Exception ex) {
        //    rv = Either.left(ex);
        //  }
        //}
      } catch (Exception ex) {
        return Either.left(ex);
      }
    }
  }
  private Either<Exception, Order> getOrderGlobally(String id) {
    return getKeyMeta(id)
      .flatMap((keyMeta) -> getOrderGlobally(id, keyMeta));
  }
  private Either<Exception, Order> getRemoteOrder(String id, HostInfo hostInfo) {
    return Either.left(new Exception("Not implemented"));
  }

  public Either<Exception, Order> getLocalOrder(String id) {
    try {
      var streams = streamsFactory.getKafkaStreams();
      if (streams.state() == KafkaStreams.State.RUNNING) {
        var store = streams.store(stateStoreQuery);
        Order rv = store.get(id);
        return Either.right(rv);
      } else {
        return Either.left(new StateStoreNotRunning());
      }
    } catch (InvalidStateStoreException isse) {
      return Either.left(isse);
    }
  }

  /**
   * Retrieves the order for a given ID asyncronously by searching globally.
   * @param id the Order ID (topic key) to search for
   * @return A CompletableFuture with an Either (right biased) containing the success or the failure
   */
  @Async
  public CompletableFuture<Either<Exception, Order>> getAsync(String id) {
    return new CompletableFuture<>().supplyAsync(() -> getOrderGlobally(id));
  }

}
