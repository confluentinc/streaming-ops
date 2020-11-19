package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

import lombok.Data;

@Configuration
@PropertySource(value = "classpath:topics-defaults.properties")
@Data
public abstract class TopicConfig {
  private String name;
  private boolean compacted;
  private int partitions;
  private short replicationFactor;
}
