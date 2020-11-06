package io.confluent.kafkadevops.microservicesorders.ordersservice;

import fj.data.Either;
import io.confluent.examples.streams.avro.microservices.Order;
import org.apache.kafka.common.serialization.StringSerializer;
import org.apache.kafka.streams.KeyQueryMetadata;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.errors.InvalidStateStoreException;
import org.apache.kafka.streams.state.HostInfo;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

@Component
public class DistributedOrderStore {

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

  /**
   * Will lookup the order for a given ID or produce an exception.
   *
   * Note: This function blocks forever looking for a requested key and should be
   * timed out by the caller
   * @param id
   * @return
   */
  private Either<Exception, Order> getOrder(String id) {
    KeyQueryMetadata keyMeta = KeyQueryMetadata.NOT_AVAILABLE;
    while (keyMeta.equals(KeyQueryMetadata.NOT_AVAILABLE)) {
      keyMeta = getKeyMeta(id);
    }

    if (keyMeta.getActiveHost().equals(localInstanceHostInfo))
      return getLocalOrder(id);
    else
      // TODO: Implement standby replicas and other host lookup
      return Either.left(new Exception("Order ID not found"));
  }

  private KeyQueryMetadata getKeyMeta(String id) throws IllegalStateException {
    return streamsFactory.getKafkaStreams()
      .queryMetadataForKey(OrdersProcessor.STATE_STORE, id, keySerializer);
  }

  public Either<Exception, Order> getLocalOrder(String id) {
    try {
      Order rv = streamsFactory.getKafkaStreams().store(stateStoreQuery).get(id);
      return Either.right(rv);
    } catch (InvalidStateStoreException isse) {
      return Either.left(isse);
    }
  }

  /**
   * Retrieves the order for a given ID asyncronously.  *The function will continue to
   * look for an order at the given ID until timeout has expired.*
   * @param id the Order ID (topic key) to search for
   * @return A CompletableFuture with an Either (right biased) containing the success or the failure
   */
  public CompletableFuture<Either<Exception, Order>> getAsync(String id) {
    return new CompletableFuture<>().supplyAsync(() -> getOrder(id));
  }

}
