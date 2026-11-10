import json
import logging
from datetime import datetime, timezone


class FormatoJson(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        evento = {
            "ts": datetime.fromtimestamp(record.created, timezone.utc).isoformat(),
            "nivel": record.levelname,
            "modulo": record.name,
            "mensaje": record.getMessage(),
        }
        from denticita.contexto import origen, request_id

        if request_id.get():
            evento["request_id"] = request_id.get()
            evento["origen"] = origen.get()
        if record.exc_info:
            evento["error"] = self.formatException(record.exc_info)
        return json.dumps(evento, ensure_ascii=False)
