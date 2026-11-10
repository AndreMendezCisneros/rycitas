"""Las dos APIs versionadas del monolito (RNF-18): pública para el sitio y privada para la app."""
from django.conf import settings
from ninja import NinjaAPI

from agenda.api import router as router_agenda
from citas.api_adelantos import router as router_adelantos
from citas.api_doctor import router as router_citas
from citas.api_publica import router as router_publico
from clientes.api import router as router_cliente
from clientes.api import router_sesion as router_sesion_cliente
from clientes.api_negocio import router as router_fidelidad
from clientes.autenticacion import TokenCliente
from consultorios.api import router as router_auth
from consultorios.api import router_dispositivos
from consultorios.autenticacion import TokenDoctor
from denticita.errores import registrar_errores

_docs = {"docs_url": "/docs"} if settings.DEBUG else {"docs_url": None, "openapi_url": None}

api_publica = NinjaAPI(title="RyCitas pública", version="1.0", urls_namespace="publica", **_docs)
api_publica.add_router("", router_publico)
registrar_errores(api_publica)

api_doctor = NinjaAPI(title="RyCitas app", version="1.0", urls_namespace="doctor", **_docs)
api_doctor.add_router("/auth", router_auth)
api_doctor.add_router("", router_dispositivos, auth=TokenDoctor())
api_doctor.add_router("", router_agenda, auth=TokenDoctor())
api_doctor.add_router("", router_citas, auth=TokenDoctor())
api_doctor.add_router("", router_adelantos, auth=TokenDoctor())
api_doctor.add_router("", router_fidelidad, auth=TokenDoctor())
registrar_errores(api_doctor)

# App del cliente («Quiero reservar»): sus tokens no sirven en /api/v1 ni los del negocio aquí.
api_cliente = NinjaAPI(title="RyCitas clientes", version="1.0", urls_namespace="cliente", **_docs)
api_cliente.add_router("/auth", router_sesion_cliente)
api_cliente.add_router("", router_cliente, auth=TokenCliente())
registrar_errores(api_cliente)
