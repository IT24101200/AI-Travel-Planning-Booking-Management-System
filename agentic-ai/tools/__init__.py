"""Shared agent tools package configuration.

Load the tools-local, git-ignored environment file before individual tool
modules are imported. This makes credentials available to the existing agent
modules without placing secrets in source control.
"""

from pathlib import Path

from dotenv import load_dotenv


load_dotenv(Path(__file__).with_name(".env"))

