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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.config.StreamsBuilderFactoryBean;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Optional;
import java.util.concurrent.CompletableFuture;

@Component
public class DistributedOrderStore {

  class StateStoreNotRunning extends Exception { }

  private static final Logger logger = LoggerFactory.getLogger(DistributedOrderStore.class);

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
      KafkaStreams ks = streamsFactory.getKafkaStreams();
      logger.info("getKeyMeta for id: {} Kafka Streams State: {}", id, ks.state());
      return Either.right(ks.queryMetadataForKey(OrdersProcessor.STATE_STORE, id, keySerializer));
    } catch (IllegalStateException ex) {
      return Either.left(ex);
    }
  }

  private Boolean ketMetaIsInValid(KeyQueryMetadata kqm) {
    return kqm == null || kqm.getActiveHost() == null || kqm.getActiveHost().host() == "unavailable";
  }
  /**
   * This function will attempt to get the key meta for an ID, but it will continue to try
   * until the kafka stream state is RUNNING.  As written now, this function could run infinitely and it blocks while
   * sleeping to allow the KS state to mutate.
   *
   * Attention could be applied to this to make it nicer; non-blocking, interruptable, max-retries, etc...
   *
   * @param id The ID to query Kafka streams for the metdata
   * @return The Key metadata which will include it's location
   */
  private Either<Exception, KeyQueryMetadata> getKeyMetaPersistentantly(String id) throws InterruptedException {
    KafkaStreams ks = streamsFactory.getKafkaStreams();
    KeyQueryMetadata rv = null;
    while (ketMetaIsInValid(rv)) {
      if (ks.state() == KafkaStreams.State.RUNNING) {
        rv = getKeyMeta(id).getOrElse(() -> null);
      } else {
        logger.info("getKeyMetaPersistentantly: Kafka Streams not running, retrying");
      }
      if (ketMetaIsInValid(rv)) {
        // TODO: Remove this blocking sleep if possible
        Thread.sleep(1000);
      }
    }
    return Either.right(rv);
  }
  private Mono<Order> getOrderFromRemote(String id, HostInfo hostInfo) {
    return WebClient
      .create(String.format("http://%s:%s", hostInfo.host(), hostInfo.port()))
      .get()
      .uri("/v1/orders/" + id)
      .retrieve()
      .bodyToMono(Order.class);
  }
  private Either<Exception, Optional<Order>> getOrderGlobally(String id, KeyQueryMetadata keyMeta) {
    if (keyMeta.getActiveHost().equals(localInstanceHostInfo))
      return getLocalOrder(id);
    else {
      logger.info("Retrieving order by id: {} from {}", id, keyMeta.getActiveHost().toString());
      try {
        // TODO: Right now this uses a blocking function on the REST call to find
        //    the remote order.  Rework this so that non-blocking code can be used throughout.
        return Either.right(
          Optional.ofNullable(
            getOrderFromRemote(id, keyMeta.getActiveHost()).block()));
        // TODO: Implement standby host retrieval
        //    Psudeo code...
        //      for (HostInfo hi : keyMeta.getStandbyHosts()) {
        //        try {
        //          rv = Either.right(getOrderFromRemote(id, hi).block());
        //          break;
        //        } catch (Exception ex) {
        //          rv = Either.left(ex);
        //        }
        //      }
      } catch (Exception ex) {
        return Either.left(ex);
      }
    }
  }
  private Either<Exception, Optional<Order>> getOrderGlobally(String id) throws InterruptedException {
    return getKeyMetaPersistentantly(id)
      .flatMap((keyMeta) -> getOrderGlobally(id, keyMeta));
  }
  private Either<Exception, Order> getRemoteOrder(String id, HostInfo hostInfo) {
    return Either.left(new Exception("Not implemented"));
  }

  public Either<Exception, Optional<Order>> getLocalOrder(String id) {
    try {
      var streams = streamsFactory.getKafkaStreams();
      if (streams.state() == KafkaStreams.State.RUNNING) {
        var store = streams.store(stateStoreQuery);
        return Either.right(Optional.ofNullable(store.get(id)));
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
  public CompletableFuture<Either<Exception, Optional<Order>>> getAsync(String id) {
    return new CompletableFuture<>().supplyAsync(() -> {
      try {
        return getOrderGlobally(id);
      } catch (InterruptedException ex) {
        return Either.left(ex);
      }
    });
  }

}
