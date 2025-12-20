### 💡 How it works

- Radicale will call OCISAuth.check_password() whenever a client tries to log in.
- OCISAuth reads the oCIS IDM JSON file and validates the password using bcrypt.
- Users are authenticated without needing a separate htpasswd file

Radicale Config (config):

```
[auth]
type = radicale.auth.AuthPlugin
plugin = ocis_auth.OCISAuth
```
