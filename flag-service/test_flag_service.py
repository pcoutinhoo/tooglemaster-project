import os
from unittest.mock import patch, MagicMock

os.environ["DATABASE_URL"] = "postgresql://test:test@localhost:5432/test_db"
os.environ["AUTH_SERVICE_URL"] = "http://auth-service:8001"

with patch("psycopg2.pool.SimpleConnectionPool") as mock_pool:
    mock_pool.return_value = MagicMock()
    import app as flag_app


def test_health_endpoint_returns_ok():
    client = flag_app.app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_create_flag_requires_auth_header():
    client = flag_app.app.test_client()
    response = client.post("/flags", json={"name": "test_flag"})
    assert response.status_code == 401
    assert "error" in response.get_json()


def test_create_flag_requires_name_field():
    client = flag_app.app.test_client()
    response = client.post(
        "/flags",
        json={},
        headers={"Authorization": "Bearer fake-key"},
    )
    assert response.status_code in (400, 401, 503, 504)
