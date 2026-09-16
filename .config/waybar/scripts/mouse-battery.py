#!/usr/bin/env python3
"""Waybar custom/mouse: nivel de batería del Razer Viper V3 Pro SE.

OpenRazer no cubre este ratón (su PID, 0x00df, no está ni en master: la lista
llega hasta 0x00d7), así que en vez de un módulo DKMS que no lo detectaría
hablamos su protocolo HID directamente contra el nodo hidraw de la interfaz de
control. El acceso al nodo lo concede /etc/udev/rules.d/99-razer-hidraw.rules.

El informe de Razer son 90 bytes: estado, id de transacción, paquetes
restantes, tipo de protocolo, tamaño, clase, comando, 80 de argumentos, CRC y
un reservado. El CRC es el XOR de los bytes 2..87. La batería es la clase 0x07
comando 0x80 y devuelve 0-255 en el argumento 1; el comando 0x84 dice si está
cargando. Referencia: driver/razerchromacommon.c de OpenRazer.
"""

import fcntl
import glob
import json
import os
import time

VENDOR = "1532"
PRODUCT = "00DF"
TRANSACTION_ID = 0x1F  # el que OpenRazer usa para la familia Viper V3 Pro
STATUS_OK = 0x02

WARNING_AT = 30
CRITICAL_AT = 15

ATTEMPTS = 3
RETRY_DELAY = 0.15

# Waybar dibuja una barra por monitor y cada barra ejecuta su propia copia de
# este script, las dos a la vez. Dos procesos hablando con el mismo nodo hidraw
# se pisan: uno escribe su petición encima de la del otro y al leer recoge una
# respuesta que no es la suya, con estado correcto pero la batería a cero. El
# resultado era un 0% rojo en una pantalla y el valor real en la otra.
#
# El cerrojo serializa las consultas y la caché hace que la segunda barra
# reutilice la lectura de la primera en vez de volver a despertar al ratón. El
# TTL es algo menor que el intervalo del módulo (60 s) para que cada ciclo
# siga trayendo un dato fresco.
CACHE_TTL = 45
_RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
LOCK_PATH = os.path.join(_RUNTIME_DIR, "waybar-mouse-battery.lock")
CACHE_PATH = os.path.join(_RUNTIME_DIR, "waybar-mouse-battery.json")


def _ioctl_feature(direction: int, length: int) -> int:
    return 0xC0000000 | (length << 16) | (ord("H") << 8) | direction


HIDIOCSFEATURE = lambda n: _ioctl_feature(0x06, n)
HIDIOCGFEATURE = lambda n: _ioctl_feature(0x07, n)


def build_report(command_class: int, command_id: int, data_size: int) -> bytes:
    report = bytearray(90)
    report[1] = TRANSACTION_ID
    report[5] = data_size
    report[6] = command_class
    report[7] = command_id
    crc = 0
    for byte in report[2:88]:
        crc ^= byte
    report[88] = crc
    return bytes(report)


def query(path: str, command_class: int, command_id: int, data_size: int):
    """Devuelve los argumentos de la respuesta, o None si el ratón no contesta."""
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError:
        return None
    try:
        out = bytearray(b"\x00" + build_report(command_class, command_id, data_size))
        fcntl.ioctl(fd, HIDIOCSFEATURE(len(out)), bytes(out))
        # El ratón necesita un instante para dejar lista la respuesta.
        time.sleep(0.06)
        response = bytearray(91)
        fcntl.ioctl(fd, HIDIOCGFEATURE(len(response)), response)
    except OSError:
        return None
    finally:
        os.close(fd)

    report = bytes(response[1:])
    if report[0] != STATUS_OK:
        return None
    return report[8:88]


def razer_nodes():
    """Nodos hidraw del ratón. El número de hidraw cambia entre arranques, así
    que se localizan por VID:PID en sysfs en lugar de fijar /dev/hidrawN."""
    # sysfs escribe el identificador como HID_ID=0003:00001532:000000DF.
    needle = f"{VENDOR}:{PRODUCT.rjust(8, '0')}".upper()
    for path in sorted(glob.glob("/dev/hidraw*")):
        name = os.path.basename(path)
        try:
            with open(f"/sys/class/hidraw/{name}/device/uevent") as handle:
                uevent = handle.read().upper()
        except OSError:
            continue
        if needle in uevent:
            yield path


def emit(payload):
    print(json.dumps(payload), flush=True)


def read_battery():
    """Primera interfaz que conteste, con reintentos.

    La primera consulta tras un rato de inactividad suele fallar porque la
    radio del ratón está dormida: contesta con un estado que no es 0x02 y el
    módulo saldría vacío. Como la barra se reinicia cada vez que se oculta y se
    muestra, ese fallo sería visible en cada toggle, así que se insiste un par
    de veces antes de darlo por desconectado.
    """
    for attempt in range(ATTEMPTS):
        if attempt:
            time.sleep(RETRY_DELAY)
        for node in razer_nodes():
            level = query(node, 0x07, 0x80, 0x02)
            # Un cero exacto se descarta igual que una respuesta ausente: un
            # ratón sin batería está apagado y no contesta, así que el cero
            # sólo aparece cuando la respuesta se ha perdido por el camino.
            if level is not None and level[1]:
                return node, level
    return None, None


def read_cache():
    try:
        with open(CACHE_PATH) as handle:
            stamp, payload = json.load(handle)
    except (OSError, ValueError, TypeError):
        return None
    if time.time() - stamp > CACHE_TTL:
        return None
    return payload


def write_cache(payload):
    try:
        with open(CACHE_PATH, "w") as handle:
            json.dump([time.time(), payload], handle)
    except OSError:
        pass


def build_payload():
    node, level = read_battery()
    if level is not None:
        percent = round(level[1] / 255 * 100)
        charge = query(node, 0x07, 0x84, 0x02)
        charging = bool(charge[1]) if charge is not None else False

        if charging:
            state = "charging"
        elif percent <= CRITICAL_AT:
            state = "critical"
        elif percent <= WARNING_AT:
            state = "warning"
        else:
            state = "normal"

        text = f"{percent}%"
        if charging:
            text += " 󱐋"

        tooltip = "Razer Viper V3 Pro SE\n"
        tooltip += f"Batería {percent}%\n"
        tooltip += "Cargando" if charging else "Con batería"

        return {"text": text, "alt": state, "class": state, "tooltip": tooltip}

    # Ratón apagado o desconectado: el módulo desaparece de la barra.
    return {"text": "", "alt": "none", "class": "none"}


def main():
    # El cerrojo se toma siempre, aunque la respuesta acabe saliendo de la
    # caché: si dos barras arrancan a la vez y ninguna la ha escrito todavía,
    # es esperando aquí como la segunda deja de consultar por su cuenta.
    try:
        lock = open(LOCK_PATH, "w")
    except OSError:
        lock = None
    if lock is not None:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX)
        except OSError:
            pass

    try:
        payload = read_cache()
        if payload is None:
            payload = build_payload()
            write_cache(payload)
        emit(payload)
    finally:
        if lock is not None:
            lock.close()


if __name__ == "__main__":
    main()
