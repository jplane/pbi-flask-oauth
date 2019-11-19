import os
import io
import json
from flask import Flask, redirect, url_for, make_response, request
from flask_dance.contrib.azure import make_azure_blueprint, azure

app = Flask(__name__)

app.secret_key = os.getenv("FLASK_SECRET")  # for user sessions

blueprint = make_azure_blueprint(
    client_id=os.getenv("AAD_CLIENT_ID"),
    client_secret=os.getenv("AAD_CLIENT_SECRET"),
    tenant=os.getenv("AAD_TENANT_NAME")
)

app.register_blueprint(blueprint, url_prefix="/login")

@app.route("/data")
def data():

    if not azure.authorized:
        return redirect(url_for("azure.login"))

    si = io.StringIO()

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

    json.dump(json_data, si)

    resp = make_response(si.getvalue())

    resp.headers['Content-Type'] = 'application/json'

    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True, port=5000)
