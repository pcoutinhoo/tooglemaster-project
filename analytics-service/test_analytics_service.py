import os
import json
from unittest.mock import patch, MagicMock

os.environ["AWS_REGION"] = "us-east-1"
os.environ["AWS_SQS_URL"] = "https://sqs.us-east-1.amazonaws.com/123456789/test-queue"
os.environ["AWS_DYNAMODB_TABLE"] = "TestTable"

with patch("boto3.client") as mock_boto_client:
    mock_boto_client.return_value = MagicMock()
    import app as analytics_app


def test_health_endpoint_returns_ok():
    client = analytics_app.app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_process_message_builds_correct_dynamodb_item():
    analytics_app.dynamodb_client = MagicMock()
    analytics_app.sqs_client = MagicMock()

    fake_message = {
        "MessageId": "msg-1",
        "ReceiptHandle": "receipt-1",
        "Body": json.dumps({
            "user_id": "user_42",
            "flag_name": "nova_ui",
            "result": True,
            "timestamp": "2026-01-01T00:00:00Z",
        }),
    }

    analytics_app.process_message(fake_message)

    assert analytics_app.dynamodb_client.put_item.called
    call_kwargs = analytics_app.dynamodb_client.put_item.call_args.kwargs
    item = call_kwargs["Item"]

    assert item["user_id"]["S"] == "user_42"
    assert item["flag_name"]["S"] == "nova_ui"
    assert item["result"]["BOOL"] is True
    assert "event_id" in item


def test_process_message_handles_invalid_json_gracefully():
    analytics_app.dynamodb_client = MagicMock()
    analytics_app.sqs_client = MagicMock()

    broken_message = {
        "MessageId": "msg-broken",
        "ReceiptHandle": "receipt-broken",
        "Body": "{isso nao e json valido",
    }

    analytics_app.process_message(broken_message)
    assert not analytics_app.dynamodb_client.put_item.called
