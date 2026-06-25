from app import create_app
from models import db
from routes.tasks import ensure_default_columns


def main():
    app = create_app(testing=True)
    with app.app_context():
        db.create_all()
        ensure_default_columns()

    client = app.test_client()
    register = client.post(
        "/api/register",
        json={"username": "joao", "password": "senha123"},
    )
    login = client.post(
        "/api/login",
        json={"username": "joao", "password": "senha123"},
    )
    token = login.get_json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    board = client.get("/api/board", headers=headers)
    column_id = board.get_json()["columns"][0]["id"]
    task = client.post(
        "/api/tasks",
        headers=headers,
        json={"title": "Smoke", "column_id": column_id},
    )
    delete = client.delete(f"/api/tasks/{task.get_json()['id']}", headers=headers)

    assert register.status_code == 201
    assert login.status_code == 200
    assert board.status_code == 200
    assert task.status_code == 201
    assert delete.status_code == 200
    print("backend smoke ok")


if __name__ == "__main__":
    main()
