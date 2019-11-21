import os
import json
import logging
from flask import request, _request_ctx_stack
from six.moves.urllib.request import urlopen
from functools import wraps
from jose import jwt


AUDIENCES = os.getenv("AUDIENCES")
TENANT_ID = os.getenv("AAD_TENANT_NAME")
SCOPES = os.getenv("SCOPES")

rsa_key = None


class AuthError(Exception):
    def __init__(self, error, status_code):
        self.error = error
        self.status_code = status_code


def authorize(logger):
    """Determines if the Access Token is valid
    """
    token = get_token_auth_header(logger)
    decoded_token = process_headers(token, logger)
    process_scopes(decoded_token, logger)


def get_token_auth_header(logger):
    """Obtains the Access Token from the Authorization Header
    """
    auth = request.headers.get("Authorization", None)

    if not auth:
        raise AuthError({
                "code": "authorization_header_missing",
                "description": "Authorization header is expected"
            }, 401)

    parts = auth.split()

    if parts[0].lower() != "bearer":
        raise AuthError({
                "code": "invalid_header",
                "description": "Authorization header must start with Bearer"
            }, 401)

    elif len(parts) == 1:
        raise AuthError({
                "code": "invalid_header",
                "description": "Token not found"
            }, 401)

    elif len(parts) > 2:
        raise AuthError({
                "code": "invalid_header",
                "description": "Authorization header must be Bearer token"
            }, 401)

    token = parts[1]

    return token


def process_scopes(decoded_token, logger):
    incoming_scopes = decoded_token["scp"].split()
    for scope in [s.strip() for s in SCOPES.split("|")]:
        if scope in incoming_scopes:
            continue
        else:
            raise AuthError({
                    "code": "missing_scope",
                    "description": f"scope {scope} is missing from token"
                }, 401)


def process_headers(token, logger):
    rsa_key = get_rsa_key(token, logger)
    decoded_token = decode_token_from_audiences(token, rsa_key, logger)
    _request_ctx_stack.top.current_user = decoded_token
    return decoded_token


def decode_token_from_audiences(token, rsa_key, logger):

    err = None
    decoded_token = None

    for audience in [aud.strip() for aud in AUDIENCES.split("|")]:
        try:
            decoded_token = decode_token(token, audience, rsa_key, logger)
            break
        except Exception as ex:
            err = ex

    if decoded_token:
        return decoded_token

    raise err


def decode_token(token, audience, rsa_key, logger):

    logger.info(f"Attempting to decode token using '{audience}' audience.")

    try:
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=["RS256"],
            audience=audience,
            issuer=f"https://sts.windows.net/{TENANT_ID}/",
            options={
                "verify_signature": False
            })

        logger.info(payload)

        return payload

    except jwt.ExpiredSignatureError:
        raise AuthError({
                "code": "token_expired",
                "description": "token is expired"
            }, 401)

    except jwt.JWTClaimsError:
        raise AuthError({
                "code": "invalid_claims",
                "description": "incorrect claims, please check the audience and issuer"
            }, 401)

    except Exception:
        raise AuthError({
                "code": "invalid_header",
                "description": "Unable to parse authentication token."
            }, 401)


def get_rsa_key(token, logger):

    global rsa_key

    if rsa_key is None:
        
        try:
            unverified_header = jwt.get_unverified_header(token)

        except Exception:
            raise AuthError({
                    "code": "invalid_header",
                    "description": "Unable to parse authentication token."
                }, 401)

        jsonurl = urlopen(
            f"https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys")

        jwks = json.loads(jsonurl.read())
        
        for key in jwks["keys"]:
            if key["kid"] == unverified_header["kid"]:
                rsa_key = {
                    "kty": key["kty"],
                    "kid": key["kid"],
                    "use": key["use"],
                    "n": key["n"],
                    "e": key["e"]
                }

        if rsa_key is None:
            raise AuthError({
                    "code": "invalid_header",
                    "description": "Unable to find appropriate key"
                }, 401)

        logger.info(rsa_key)

    return rsa_key
