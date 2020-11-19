package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties("topics.orders")
public class OrdersTopicConfig extends TopicConfig {

}
