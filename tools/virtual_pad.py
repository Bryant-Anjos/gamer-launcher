"""Cria um controle virtual via /dev/uinput e executa botões combinados.
Uso: virtual_pad.py <segundos_antes> BOTAO[:ms] ...   (ex.: MODE DPAD_DOWN)
"""
import fcntl, os, struct, sys, time

UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT = 0x40045564, 0x40045565, 0x40045567
UI_ABS_SETUP = 0x401C5504
EV_ABS = 3
AXES = {"ABS_X": 0, "ABS_Y": 1, "ABS_Z": 2, "ABS_RX": 3, "ABS_RY": 4, "ABS_RZ": 5,
        "ABS_HAT0X": 0x10, "ABS_HAT0Y": 0x11}
RANGE = {"ABS_Z": (0, 255), "ABS_RZ": (0, 255), "ABS_HAT0X": (-1, 1), "ABS_HAT0Y": (-1, 1)}
UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x5501, 0x5502
EV_SYN, EV_KEY = 0, 1
# Mesmo conjunto de um Xbox 360 (xpad): o gilrs só aplica o mapeamento SDL se bater.
BUTTONS = {"SOUTH": 0x130, "EAST": 0x131, "NORTH": 0x133, "WEST": 0x134,
           "TL": 0x136, "TR": 0x137, "SELECT": 0x13A, "START": 0x13B,
           "MODE": 0x13C, "THUMBL": 0x13D, "THUMBR": 0x13E}
HAT = {"DPAD_UP": ("ABS_HAT0Y", -1), "DPAD_DOWN": ("ABS_HAT0Y", 1),
       "DPAD_LEFT": ("ABS_HAT0X", -1), "DPAD_RIGHT": ("ABS_HAT0X", 1)}

fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
for code in BUTTONS.values():
    fcntl.ioctl(fd, UI_SET_KEYBIT, code)
setup = struct.pack("HHHH80sI", 0x03, 0x045E, 0x028E, 0x0114, b"Xbox 360 Controller", 0)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_ABS)
for name, code in AXES.items():
    fcntl.ioctl(fd, UI_SET_ABSBIT, code)
    fcntl.ioctl(fd, UI_ABS_SETUP, struct.pack("Hxx6i", code, 0, *RANGE.get(name, (-32768, 32767)), *((0, 0) if name in RANGE else (16, 128)), 0))
fcntl.ioctl(fd, UI_DEV_SETUP, setup)
fcntl.ioctl(fd, UI_DEV_CREATE)

def emit(kind, code, value):
    os.write(fd, struct.pack("llHHi", 0, 0, kind, code, value))

def tap(name, hold_ms=60):
    emit(EV_KEY, BUTTONS[name], 1); emit(EV_SYN, 0, 0)
    time.sleep(hold_ms / 1000)
    emit(EV_KEY, BUTTONS[name], 0); emit(EV_SYN, 0, 0)

try:
    time.sleep(float(sys.argv[1]))  # dá tempo de o udev anunciar o controle
    for step in sys.argv[2:]:
        if step.startswith("ABS_"):  # ABS_X=32767
            name, _, value = step.partition("=")
            emit(EV_ABS, AXES[name], int(value)); emit(EV_SYN, 0, 0)
        elif step.split(":")[0] in HAT:
            name, _, ms = step.partition(":")
            axis, value = HAT[name]
            emit(EV_ABS, AXES[axis], value); emit(EV_SYN, 0, 0)
            time.sleep((int(ms) if ms else 60) / 1000)
            emit(EV_ABS, AXES[axis], 0); emit(EV_SYN, 0, 0)
        else:
            name, _, ms = step.partition(":")
            tap(name, int(ms) if ms else 60)
        time.sleep(0.4)
finally:
    time.sleep(0.3)
    fcntl.ioctl(fd, UI_DEV_DESTROY)
    os.close(fd)
