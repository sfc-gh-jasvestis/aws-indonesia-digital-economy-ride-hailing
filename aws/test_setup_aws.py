import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_trips import make_event
from setup_aws import firehose_request, ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('id-ride', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'id-ride-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'ID_RIDE_S3_INT')
        self.assertEqual(n['firehose_stream'], 'id-ride-trips')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_firehose_request_matches_aws_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('id-ride', '123456789012', 'us-west-2')
        req = firehose_request(n, n['bucket'], 'arn:aws:iam::123456789012:role/id-ride-firehose-s3')
        model = botocore.session.get_session().get_service_model('firehose')
        validate_parameters(req, model.operation_model('CreateDeliveryStream').input_shape)
        dest = req['ExtendedS3DestinationConfiguration']
        self.assertEqual(dest['Prefix'], 'trips/')
        self.assertFalse(dest['ErrorOutputPrefix'].startswith('trips/'))

    def test_trip_event_matches_pipe_columns(self):
        import random
        event = make_event(random.Random(7))
        self.assertEqual(set(event), {'zone_id', 'event_ts', 'fare_idr', 'wait_seconds', 'status', 'sent_ms'})
        self.assertRegex(event['zone_id'], r'^ZON-00[0-3]\d$')
        self.assertIn(event['status'], ('UNFULFILLED', 'MATCHED'))


if __name__ == '__main__':
    unittest.main()
