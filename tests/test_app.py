import pytest
from app import app, evaluate


@pytest.fixture
def client():
    return app.test_client()


@pytest.mark.parametrize("expression,expected", [
    ("2+3", "5"),
    ("5−3", "2"),
    ("4×3", "12"),
    ("9÷3", "3"),
    ("2+3×4", "14"),          # operator precedence
    ("−5+2", "-3"),           # negative numbers
    ("0.1+0.2", "0.3"),
    ("10÷4", "2.5"),
])
def test_evaluate(expression, expected):
    assert evaluate(expression) == expected


def test_divide_by_zero():
    with pytest.raises(ZeroDivisionError):
        evaluate("1÷0")


@pytest.mark.parametrize("bad", ["", "2+", "abc", "__import__('os')", "2**9999", "1+(2"])
def test_rejects_invalid_or_unsafe(bad):
    with pytest.raises(ValueError):
        evaluate(bad)


def test_home_page(client):
    res = client.get("/")
    assert res.status_code == 200
    assert b"Calculator" in res.data


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_calculate_api(client):
    res = client.post("/calculate", json={"expression": "6×7"})
    assert res.get_json() == {"result": "42"}


def test_calculate_api_error(client):
    res = client.post("/calculate", json={"expression": "1÷0"})
    assert res.status_code == 400
    assert "zero" in res.get_json()["error"]