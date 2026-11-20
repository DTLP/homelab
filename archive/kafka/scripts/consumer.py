from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    "test-topic",
    bootstrap_servers="kafka.kafka.svc.cluster.local:9092",
    auto_offset_reset="earliest",
    group_id="test-group",
    value_deserializer=lambda m: json.loads(m.decode("utf-8"))
)

for msg in consumer:
    print(msg.value)
