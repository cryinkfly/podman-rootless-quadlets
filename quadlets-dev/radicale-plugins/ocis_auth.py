"""
OCISAuth Plugin for Radicale

This is a custom authentication plugin for Radicale (a CalDAV/CardDAV server)
that allows Radicale to authenticate users directly against ownCloud Infinite Scale (oCIS) IDM users
stored in a JSON file.

How it works:

1. Initialization (__init__):
   - Reads the path to the oCIS IDM JSON file from the environment variable OCIS_JSON_PATH.
   - Opens and parses the JSON file containing user information.
   - Creates a dictionary mapping username → user object for fast lookups.
   - Each user object typically contains:
       - username
       - hash (bcrypt password hash)
       - status (active or inactive)
       - roles and other metadata

2. Password Check (check_password):
   - Accepts a username and password provided by the client.
   - Looks up the user in the loaded JSON.
   - If the user does not exist or is inactive, authentication fails.
   - If the user exists and is active, the provided password is verified against the stored bcrypt hash.
   - Returns True if the password matches, False otherwise.
"""

import os
import json
import bcrypt

class OCISAuth:
    def __init__(self):
        json_path = os.environ.get("OCIS_JSON_PATH", "/data/ocis-accounts.json")
        with open(json_path) as f:
            self.users = {u["username"]: u for u in json.load(f)}

    def check_password(self, username, password):
        user = self.users.get(username)
        if not user or user["status"] != "active":
            return False
        return bcrypt.checkpw(password.encode(), user["hash"].encode())
