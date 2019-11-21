import os
import io
import json
import logging
from flask import Flask, redirect, url_for, make_response, jsonify
from flask.logging import default_handler
from oauth import authorize, AuthError


app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET")

formatter = logging.Formatter(
    " %(asctime)s | %(pathname)s:%(lineno)d | %(funcName)s | %(levelname)s | %(message)s ")
default_handler.setFormatter(formatter)
default_handler.setLevel(logging.INFO)

auth_enabled = os.getenv("AUTHENABLED") in ["True", "1", "Yes", None]

if auth_enabled:
    do_auth = authorize
else:
    do_auth = lambda log: log.info("Authorization is disabled")    


@app.errorhandler(AuthError)
def handle_auth_error(ex):
    app.logger.exception("authorization error")
    response = jsonify(ex.error)
    response.status_code = ex.status_code
    return response


@app.route("/data")
def data():

    do_auth(app.logger)

    json_data = [
        {
            'id': 1,
            'name': 'Josh',
            'age': 47
        },
        {
            'id': 2,
            'name': 'Adam',
            'age': 45
        },
        {
            'id': 3,
            'name': 'Fred',
            'age': 33
        }
    ]

    si = io.StringIO()
    json.dump(json_data, si)
    resp = make_response(si.getvalue())
    resp.headers['Content-Type'] = 'application/json'
    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True, port=5000)
