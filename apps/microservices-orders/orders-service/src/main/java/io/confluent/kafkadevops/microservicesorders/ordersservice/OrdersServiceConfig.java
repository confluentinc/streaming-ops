package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.state.HostInfo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import org.springframework.kafka.config.KafkaStreamsConfiguration;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.Map;

import static java.lang.Integer.parseInt;

@Lazy
@Configuration
public class OrdersServiceConfig {

  private final String httpServerPort;
  private final KafkaProperties configuredKafkaProperties;

  @Autowired
  public OrdersServiceConfig(KafkaProperties props, @Value("${server.port}") String port) {
    configuredKafkaProperties = props;
    httpServerPort = port;
  }

  @Bean
  KafkaStreamsConfiguration defaultKafkaStreamsConfig() throws UnknownHostException {
    Map<String, Object> newConfig = configuredKafkaProperties.buildStreamsProperties();
    newConfig.put(
      StreamsConfig.APPLICATION_SERVER_CONFIG,
      InetAddress.getLocalHost().getHostName() + ":" + httpServerPort);
    return new KafkaStreamsConfiguration(newConfig);
  }
  @Bean
  public HostInfo thisInstanceHostInfo() throws UnknownHostException {
    return new HostInfo(InetAddress.getLocalHost().getHostName(), parseInt(httpServerPort));
  }

}
