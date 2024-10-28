## Windplay Operation System(WOPS)
WINDPLAY OPERATION SYSTEM
```
/IamUsername/.virtualenvs/os_flask/bin/gunicorn -c /data/operationsystem/config/gunicorn.ini manage:app
```
```
# .env
SECRET_KEY="OS0NOs7LGrnanZt5KndH"
FLASK_CONFIG="default"
SSH_KEY_FILE="/IamUsername/.ssh/id_rsa"
```