#!/bin/sh

docker run --rm \
    --env-file .env \
    -p 5000:5000 \
    kroger/flask-oauth-azure
