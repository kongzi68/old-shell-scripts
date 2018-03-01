from flask import Blueprint

cfm = Blueprint('cfm', __name__)

from . import views