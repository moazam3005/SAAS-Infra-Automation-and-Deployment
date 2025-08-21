def test_health():
    from app import app
    with app.test_client() as c:
        resp = c.get("/staging/health")
        assert resp.status_code == 200
