from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers="kafka.kafka.svc.cluster.local:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

counter = 0

while True:
    msg = {
        "counter": counter,
        "message": "hello from producer"
    }

    producer.send("test-topic", msg)
    producer.flush()

    print("sent", msg)

    counter += 1
    time.sleep(2)
