"""Panel de la plataforma: crear y controlar cada negocio (sitio, app, opciones y servicio)."""
from __future__ import annotations

from datetime import timedelta
from functools import wraps

from django.contrib import messages
from django.contrib.auth import login, logout
from django.contrib.auth.forms import AuthenticationForm
from django.db import transaction
from django.db.models import Count, Q
from django.http import Http404, HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_POST

from agenda.models import HorarioSemanal
from citas.models import Cita, Estado
from consultorios.models import Consultorio, Usuario
from consultorios.rubros import RUBROS
from panel import formularios as f
from panel import negocios
from panel.models import EventoPanel
from sitio.cache import purgar_sitio
from sitio.metricas import kpis, resumen

PESTANAS = [
    ("resumen", "Resumen"),
    ("sitio", "Sitio web"),
    ("servicios", "Servicios"),
    ("horario", "Horario"),
    ("equipo", "Profesionales y cuentas"),
    ("opciones", "Opciones"),
    ("servicio", "Servicio y datos"),
]


def solo_plataforma(vista):
    """Solo el personal de la plataforma y solo en su dominio (nunca en el subdominio de un negocio)."""

    @wraps(vista)
    def envoltura(request, *args, **kwargs):
        if getattr(request, "consultorio", None) is not None:
            raise Http404()
        if not (request.user.is_authenticated and request.user.is_staff and request.user.activo):
            return redirect(f"{reverse('panel:entrar')}?siguiente={request.path}")
        return vista(request, *args, **kwargs)

    return envoltura


def entrar(request):
    if getattr(request, "consultorio", None) is not None:
        raise Http404()
    formulario = AuthenticationForm(request, data=request.POST or None)
    if request.method == "POST" and formulario.is_valid():
        usuario = formulario.get_user()
        if usuario.is_staff:
            login(request, usuario)
            siguiente = request.GET.get("siguiente", "")
            return redirect(siguiente if siguiente.startswith("/panel/") else reverse("panel:lista"))
        formulario.add_error(None, "Esta cuenta no tiene acceso al panel.")
    return render(request, "panel/entrar.html", {"form": formulario})


@require_POST
def salir(request):
    logout(request)
    return redirect("panel:entrar")


@solo_plataforma
def lista(request):
    q = request.GET.get("q", "").strip()
    filtro = request.GET.get("estado", "")
    negocios_qs = Consultorio.objects.annotate(
        citas_30=Count("citas", filter=Q(citas__creado_en__gte=timezone.now() - timedelta(days=30))),
        cuentas=Count("usuarios", distinct=True),
    ).order_by("nombre")
    if q:
        negocios_qs = negocios_qs.filter(Q(nombre__icontains=q) | Q(slug__icontains=q))
    filas = []
    for c in negocios_qs:
        estado = negocios.estado_de(c)
        if filtro and estado != filtro:
            continue
        vence = negocios.dias_para_vencer(c)
        filas.append({"c": c, "estado": estado, "vence": vence, "por_vencer": vence is not None and 0 <= vence <= 7,
                      "vencido": -vence if vence is not None and vence < 0 else None, "tipo": c.tipo["nombre"]})
    return render(request, "panel/lista.html", {"filas": filas, "q": q, "filtro": filtro,
                                                "por_vencer": sum(1 for x in filas if x["por_vencer"])})


@solo_plataforma
def nuevo(request):
    clave = request.GET.get("tipo") or request.POST.get("rubro")
    if clave not in RUBROS:
        return render(request, "panel/nuevo_tipo.html", {"rubros": RUBROS})
    tipo = RUBROS[clave]
    if request.method == "POST":
        datos = f.DatosNegocioForm(request.POST, prefix="datos")
        servicios = f.ServiciosFormSet(request.POST, prefix="serv")
        horario = f.HorarioForm(request.POST, prefix="hor")
        opciones = f.OpcionesForm.para(rubro=clave, data=request.POST)
        cuenta_correo = request.POST.get("cuenta_correo", "").strip().lower()
        validos = all([datos.is_valid(), servicios.is_valid(), horario.is_valid(), opciones.is_valid()])
        if cuenta_correo and Usuario.objects.filter(correo=cuenta_correo).exists():
            validos = False
            messages.error(request, "Ya existe una cuenta con ese correo.")
        if validos:
            lista_serv = [s for s in servicios.cleaned_data if s.get("incluir") and s.get("nombre")]
            with transaction.atomic():
                consultorio = negocios.crear_negocio(
                    autor=request.user,
                    rubro=clave,
                    nombre=datos.cleaned_data["nombre"],
                    slug=datos.cleaned_data["slug"],
                    whatsapp=datos.cleaned_data["whatsapp"],
                    direccion=datos.cleaned_data["direccion"],
                    mapa_url=datos.cleaned_data["mapa_url"],
                    profesionales=datos.lista_profesionales(),
                    servicios=lista_serv,
                    horario=horario.tramos(),
                    opciones=opciones.opciones(),
                )
                consultorio.reglas = opciones.reglas()
                consultorio.save(update_fields=["reglas"])
                if cuenta_correo:
                    usuario, clave_app = negocios.crear_cuenta(request.user, consultorio, cuenta_correo,
                                                                datos.lista_profesionales()[0])
                    messages.success(request, f"Cuenta de la app: {usuario.correo} · contraseña: {clave_app} "
                                              "(anótala: no se vuelve a mostrar).")
            messages.success(request, f"«{consultorio.nombre}» quedó creado como borrador. Revisa la vista previa y publícalo.")
            return redirect("panel:ficha", consultorio.pk)
    else:
        datos = f.DatosNegocioForm(prefix="datos")
        servicios = f.ServiciosFormSet(prefix="serv", initial=[{**s, "incluir": True} for s in negocios.servicios_sugeridos(clave)])
        horario = f.HorarioForm(prefix="hor", tramos=negocios.horario_sugerido(clave))
        opciones = f.OpcionesForm.para(rubro=clave)
    return render(request, "panel/nuevo.html", {
        "clave": clave, "tipo": tipo, "datos": datos, "servicios": servicios, "horario": horario, "opciones": opciones,
        "cuenta_correo": request.POST.get("cuenta_correo", ""),
    })


def _url_sitio(request, consultorio: Consultorio) -> str:
    from citas.presentacion import base_url_consultorio

    return base_url_consultorio(consultorio, request)


@solo_plataforma
def ficha(request, pk: int):
    consultorio = get_object_or_404(Consultorio, pk=pk)
    pestana = request.GET.get("p", "resumen")
    if pestana not in dict(PESTANAS):
        pestana = "resumen"
    contexto = {"c": consultorio, "pestanas": PESTANAS, "pestana": pestana, "estado": negocios.estado_de(consultorio),
                "url_sitio": _url_sitio(request, consultorio), "voc": consultorio.vocabulario,
                "vence": negocios.dias_para_vencer(consultorio)}
    manejador = {
        "resumen": _resumen, "sitio": _sitio, "servicios": _servicios, "horario": _horario, "equipo": _equipo,
        "opciones": _opciones, "servicio": _servicio,
    }[pestana]
    respuesta = manejador(request, consultorio, contexto)
    if respuesta is not None:
        return respuesta
    return render(request, "panel/ficha.html", contexto)


def _volver(consultorio: Consultorio, pestana: str):
    return redirect(f"{reverse('panel:ficha', args=[consultorio.pk])}?p={pestana}")


def _resumen(request, consultorio, contexto):
    ahora = timezone.now()
    contexto["metricas"] = resumen(consultorio, ahora - timedelta(days=30), ahora)
    # El mes completo, no solo hasta hoy: las citas ya agendadas para los próximos días del mes también cuentan.
    primero = timezone.localdate().replace(day=1)
    siguiente = (primero + timedelta(days=32)).replace(day=1)
    contexto["kpis"] = kpis(consultorio, primero, siguiente)
    contexto["proximas"] = Cita.objects.filter(
        consultorio=consultorio, estado__in=[Estado.PROGRAMADA, Estado.POR_APROBAR], inicio__gte=ahora
    ).count()
    contexto["por_confirmar"] = Cita.objects.filter(consultorio=consultorio, estado=Estado.POR_APROBAR).count()
    contexto["eventos"] = EventoPanel.objects.filter(consultorio=consultorio).select_related("usuario")[:15]


def _sitio(request, consultorio, contexto):
    form = f.SitioForm(request.POST or None, request.FILES or None, instance=consultorio)
    if request.method == "POST" and form.is_valid():
        form.save()
        purgar_sitio(consultorio.slug)
        negocios.registrar(request.user, consultorio, "sitio")
        messages.success(request, "Sitio actualizado.")
        return _volver(consultorio, "sitio")
    contexto["form"] = form


def _servicios(request, consultorio, contexto):
    formset = f.TratamientosFormSet(request.POST or None, instance=consultorio, prefix="t")
    if request.method == "POST" and formset.is_valid():
        formset.save()
        purgar_sitio(consultorio.slug)
        negocios.registrar(request.user, consultorio, "servicios")
        messages.success(request, "Servicios guardados.")
        return _volver(consultorio, "servicios")
    contexto["formset"] = formset


def _horario(request, consultorio, contexto):
    actuales = [(h.dia_semana, h.hora_inicio, h.hora_fin)
                for h in HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=True)]
    form = f.HorarioForm(request.POST or None, prefix="hor", tramos=actuales)
    if request.method == "POST" and form.is_valid():
        with transaction.atomic():
            HorarioSemanal.objects.filter(consultorio=consultorio, profesional__isnull=True).delete()
            HorarioSemanal.objects.bulk_create(
                HorarioSemanal(consultorio=consultorio, dia_semana=d, hora_inicio=i, hora_fin=fin)
                for d, i, fin in form.tramos()
            )
        purgar_sitio(consultorio.slug)
        negocios.registrar(request.user, consultorio, "horario")
        messages.success(request, "Horario guardado. Las reservas web ya lo usan.")
        return _volver(consultorio, "horario")
    contexto["form"] = form


def _equipo(request, consultorio, contexto):
    formset = f.ProfesionalesFormSet(request.POST or None, instance=consultorio, prefix="p")
    cuenta = f.CuentaForm(consultorio=consultorio, prefix="cuenta")
    if request.method == "POST" and request.POST.get("accion") == "profesionales":
        if formset.is_valid():
            formset.save()
            purgar_sitio(consultorio.slug)
            negocios.registrar(request.user, consultorio, "profesionales")
            messages.success(request, "Profesionales guardados.")
            return _volver(consultorio, "equipo")
    elif request.method == "POST" and request.POST.get("accion") == "cuenta":
        formset = f.ProfesionalesFormSet(instance=consultorio, prefix="p")
        cuenta = f.CuentaForm(request.POST, consultorio=consultorio, prefix="cuenta")
        if cuenta.is_valid():
            usuario, clave = negocios.crear_cuenta(
                request.user, consultorio, cuenta.cleaned_data["correo"], cuenta.cleaned_data["nombre"],
                cuenta.cleaned_data["profesional"],
            )
            messages.success(request, f"Cuenta creada: {usuario.correo} · contraseña: {clave} (anótala: no se vuelve a mostrar).")
            return _volver(consultorio, "equipo")
    contexto["formset"] = formset
    contexto["cuenta"] = cuenta
    contexto["cuentas"] = consultorio.usuarios.select_related("profesional").order_by("correo")


def _opciones(request, consultorio, contexto):
    form = f.OpcionesForm.para(consultorio=consultorio, data=request.POST or None)
    if request.method == "POST" and form.is_valid():
        consultorio.opciones = {**(consultorio.opciones or {}), **form.opciones()}
        consultorio.reglas = {**(consultorio.reglas or {}), **form.reglas()}
        consultorio.save(update_fields=["opciones", "reglas"])
        purgar_sitio(consultorio.slug)
        negocios.registrar(request.user, consultorio, "opciones", ", ".join(f"{k}={v}" for k, v in form.opciones().items()))
        messages.success(request, "Opciones guardadas.")
        return _volver(consultorio, "opciones")
    contexto["form"] = form


def _servicio(request, consultorio, contexto):
    form = f.ServicioPagadoForm(request.POST or None, initial={"servicio_hasta": consultorio.servicio_hasta})
    if request.method == "POST" and form.is_valid():
        consultorio.servicio_hasta = form.cleaned_data["servicio_hasta"]
        consultorio.save(update_fields=["servicio_hasta"])
        negocios.registrar(request.user, consultorio, "servicio_hasta", str(consultorio.servicio_hasta or ""))
        messages.success(request, "Fecha de servicio guardada.")
        return _volver(consultorio, "servicio")
    contexto["form"] = form


@solo_plataforma
@require_POST
def accion(request, pk: int, nombre: str):
    consultorio = get_object_or_404(Consultorio, pk=pk)
    if nombre == "publicar":
        negocios.publicar(request.user, consultorio, True)
        messages.success(request, "Publicado: el sitio ya acepta reservas.")
    elif nombre == "despublicar":
        negocios.publicar(request.user, consultorio, False)
        messages.success(request, "El sitio volvió a «en preparación».")
    elif nombre == "suspender":
        negocios.suspender(request.user, consultorio, True, request.POST.get("motivo", ""))
        messages.success(request, "Suspendido: el sitio no acepta reservas. Las citas y la app siguen intactas.")
    elif nombre == "reactivar":
        negocios.suspender(request.user, consultorio, False)
        messages.success(request, "Reactivado: el sitio vuelve a aceptar reservas.")
    else:
        raise Http404()
    volver = request.POST.get("volver", "")
    return redirect(reverse("panel:ficha", args=[pk]) + (volver if volver.startswith("?p=") else ""))


@solo_plataforma
@require_POST
def accion_cuenta(request, pk: int, usuario_id: int, nombre: str):
    consultorio = get_object_or_404(Consultorio, pk=pk)
    usuario = get_object_or_404(Usuario, pk=usuario_id, consultorio=consultorio)
    if nombre == "contrasena":
        clave = negocios.restablecer_contrasena(request.user, usuario)
        messages.success(request, f"Nueva contraseña de {usuario.correo}: {clave} (anótala: no se vuelve a mostrar).")
    elif nombre == "cerrar-sesiones":
        n = negocios.cerrar_sesiones(usuario)
        negocios.registrar(request.user, consultorio, "cerrar_sesiones", usuario.correo)
        messages.success(request, f"Se cerraron {n} sesión(es) de {usuario.correo}.")
    elif nombre == "desactivar":
        negocios.cambiar_activo(request.user, usuario, False)
        messages.success(request, f"{usuario.correo} ya no puede entrar a la app.")
    elif nombre == "activar":
        negocios.cambiar_activo(request.user, usuario, True)
        messages.success(request, f"{usuario.correo} puede volver a entrar.")
    else:
        raise Http404()
    return _volver(consultorio, "equipo")


@solo_plataforma
def exportar(request, pk: int, que: str):
    consultorio = get_object_or_404(Consultorio, pk=pk)
    if que == "citas":
        contenido = negocios.exportar_citas(consultorio)
    elif que == "clientes":
        contenido = negocios.exportar_clientes(consultorio)
    else:
        raise Http404()
    negocios.registrar(request.user, consultorio, "exportar", que)
    respuesta = HttpResponse("﻿" + contenido, content_type="text/csv; charset=utf-8")
    respuesta["Content-Disposition"] = f'attachment; filename="{consultorio.slug}-{que}.csv"'
    return respuesta
