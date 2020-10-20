package io.confluent.kafkadevops.microservicesorders.ordersservice;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.PropertySource;
import org.springframework.context.annotation.Scope;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

@Component
@Scope("singleton")
public class SchemaRegistryConfig {

  @Value("${spring.kafka.properties.schema.registry.url}")
  public String url;

  public Properties buildProperties() {
    return buildProperties(this);
  }
  public static Properties buildProperties(SchemaRegistryConfig config) {
    final Properties rv = new Properties();
    rv.put("schema.registry.url", config.url);
    return rv;
  }

  public Map<String, Object> buildPropertiesMap() {
    return buildPropertiesMap(this);
  }
  public static Map<String, Object> buildPropertiesMap(SchemaRegistryConfig config) {
    Map<String, Object> rv = new HashMap<>();
    Properties props = buildProperties(config);
    for (final String name : props.stringPropertyNames())
      rv.put(name, props.getProperty(name));
    return rv;
  }
}
