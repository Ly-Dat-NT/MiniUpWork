"""Small psycopg 3 connection factory shared by every entry point."""

from contextlib import contextmanager
from dataclasses import dataclass
import logging
from typing import Iterator

import certifi
import psycopg
from psycopg.conninfo import conninfo_to_dict
from psycopg.rows import dict_row

from .config import Settings

logger = logging.getLogger("uvicorn.error")

@dataclass(frozen=True)
class Database:
    conninfo: str
    password: str | None = None

    @classmethod
    def from_env(cls) -> "Database":
        settings = Settings.from_env()
        return cls(settings.database_url, settings.database_password)

    @contextmanager
    def connection(self) -> Iterator[psycopg.Connection]:
        options = {
            "row_factory": dict_row,
            "connect_timeout": 5,
            "application_name": "miniupwork_lab2",
        }
        if self.password is not None:
            options["password"] = self.password
        if conninfo_to_dict(self.conninfo).get("sslrootcert") == "system":
            options.update(sslrootcert=certifi.where(), connect_timeout=15)
        try:
            connection = psycopg.connect(self.conninfo, **options)
        except psycopg.OperationalError as error:
            message = str(error).lower()
            if "certificate" in message or "ssl" in message:
                reason = "TLS verification"
            elif "authentication" in message or "password" in message:
                reason = "authentication"
            elif "timeout" in message or "timed out" in message:
                reason = "connection timeout"
            else:
                reason = "connection or server availability"
            logger.warning("PostgreSQL unavailable (%s).", reason)
            raise
        # Normal exit commits; errors roll back. Both paths close the connection,
        # including commit errors raised by a deferred database constraint.
        with connection:
            yield connection
