import boto3
import json
import time

STREAM_NAME = 'user-events-stream'


class KinesisConsumer:
    def __init__(self, stream_name):
        self.stream_name = stream_name
        self.kinesis = boto3.client('kinesis', region_name='us-east-1')
        self.shard_iterators = {}
        self.event_counts = {}
        self.last_event_time = time.time()
        self.initialize_shards()

    def initialize_shards(self):
        response = self.kinesis.describe_stream(StreamName=self.stream_name)
        shards = response['StreamDescription']['Shards']
        print(f"Found {len(shards)} shards:")
        for shard in shards:
            shard_id = shard['ShardId']
            iterator_response = self.kinesis.get_shard_iterator(
                StreamName=self.stream_name,
                ShardId=shard_id,
                ShardIteratorType='LATEST',
            )
            self.shard_iterators[shard_id] = iterator_response['ShardIterator']
            self.event_counts[shard_id] = 0
            print(f"  - {shard_id}")
        print()

    def process_event(self, event_data):
        try:
            event = json.loads(event_data)
            user_id = event.get('user_id', 'unknown')
            self.event_counts.setdefault(user_id, 0)
            self.event_counts[user_id] += 1
            return event
        except json.JSONDecodeError:
            return None

    def consume(self):
        print(f"Starting consumer... Reading from: {self.stream_name}")
        print("Press Ctrl+C to stop\n")

        total_events = 0
        try:
            while True:
                for shard_id, iterator in self.shard_iterators.items():
                    if not iterator:
                        continue
                    try:
                        response = self.kinesis.get_records(
                            ShardIterator=iterator,
                            Limit=100,
                        )
                        self.shard_iterators[shard_id] = response['NextShardIterator']
                        for record in response['Records']:
                            event = self.process_event(record['Data'])
                            if event:
                                total_events += 1
                                if total_events % 20 == 0:
                                    print(f"\n[{total_events}] Events Processed")
                                    print(f"Event type: {event['event_type']}")
                                    print(f"User: {event['user_id']}")
                                    print(f"Content: {event['content']}")
                                    print(f"Device: {event['device']}")
                                    print("-" * 50)
                    except Exception as e:
                        print(f"Error reading from {shard_id}: {e}")
                time.sleep(1)
        except KeyboardInterrupt:
            print(f"\n\nStopped. Total events processed: {total_events}")
            print("\nEvents by user:")
            for user_id, count in self.event_counts.items():
                if count > 0:
                    print(f"  {user_id}: {count} events")


def main():
    consumer = KinesisConsumer(STREAM_NAME)
    consumer.consume()


if __name__ == '__main__':
    main()
