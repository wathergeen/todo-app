from flask import Flask, render_template

from config import Config, TestConfig
from models import bcrypt, db, jwt
from routes.auth import auth_bp
from routes.tasks import ensure_default_columns, tasks_bp


def create_app(testing=False):
    app = Flask(__name__)
    app.config.from_object(TestConfig if testing else Config)

    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)

    app.register_blueprint(auth_bp, url_prefix="/api")
    app.register_blueprint(tasks_bp, url_prefix="/api")

    @app.get("/")
    def index():
        return render_template("index.html")

    return app


app = create_app()


if __name__ == "__main__":
    with app.app_context():
        db.create_all()
        ensure_default_columns()
    app.run(host="0.0.0.0", port=5000, debug=app.config["DEBUG"])
