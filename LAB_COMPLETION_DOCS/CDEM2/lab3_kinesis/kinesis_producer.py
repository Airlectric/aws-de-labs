import boto3
import json
import time
from datetime import datetime
import random

kinesis = boto3.client('kinesis', region_name='us-east-1')

STREAM_NAME = 'user-events-stream'

USER_IDS = ['user_001', 'user_002', 'user_003', 'user_004', 'user_005']

EVENTS = [
    'play',
    'pause',
    'resume',
    'seek_forward',
    'seek_backward',
    'stop',
    'like',
    'dislike',
    'share',
]

CONTENT = [
    'Stranger Things',
    'The Crown',
    'Bridgerton',
    'The Witcher',
    'Black Mirror',
]


def generate_event():
    return {
        'timestamp': datetime.now().isoformat(),
        'user_id': random.choice(USER_IDS),
        'event_type': random.choice(EVENTS),
        'content': random.choice(CONTENT),
        'duration_seconds': random.randint(1, 3600),
        'device': random.choice(['web', 'mobile', 'tv']),
        'region': random.choice(['us-east', 'us-west', 'eu-west', 'ap-southeast']),
    }


def send_to_kinesis(event):
    try:
        kinesis.put_record(
            StreamName=STREAM_NAME,
            Data=json.dumps(event),
            PartitionKey=event['user_id'],
        )
        return True
    except Exception as e:
        print(f"Error sending to Kinesis: {e}")
        return False


def main():
    print(f"Starting producer... Sending to stream: {STREAM_NAME}")
    print("Press Ctrl+C to stop\n")

    event_count = 0
    start_time = time.time()

    try:
        while True:
            event = generate_event()
            if send_to_kinesis(event):
                event_count += 1
                if event_count % 10 == 0:
                    elapsed = time.time() - start_time
                    rate = event_count / elapsed
                    print(
                        f"[{event_count}] Sent: {event['event_type']} "
                        f"by {event['user_id']} "
                        f"({rate:.1f} events/sec)"
                    )
            time.sleep(0.2)
    except KeyboardInterrupt:
        elapsed = time.time() - start_time
        print(f"\n\nStopped. Total events sent: {event_count}")
        print(f"Total time: {elapsed:.1f} seconds")
        print(f"Average rate: {event_count / elapsed:.1f} events/second")


if __name__ == '__main__':
    main()
