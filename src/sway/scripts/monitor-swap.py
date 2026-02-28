#!/bin/env python3

import sys
import subprocess
import os
import re
from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QPushButton,
    QHBoxLayout,
    QMessageBox,
)
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QKeyEvent
from enum import Enum
from dataclasses import dataclass
import time


os.environ["QT_QPA_PLATFORM"] = "wayland"


@dataclass
class MonitoresSway:
    interno: str
    externo: str


class DisplaySwitchType(Enum):
    PC_ONLY = 0
    MONITOR_ONLY = 1
    EXTEND = 2
    DUPLICATE = 3


class ISwitcherUI(QWidget):
    def __init__(self) -> None:
        super().__init__()

    def confirmar_ou_reverter(self):
        raise NotImplementedError("Precisar ser impletado pela classe filha")


class SwayService:
    @classmethod
    def get_monitores(cls) -> list[str]:
        cmd = 'swaymsg -t get_outputs | grep "\\"name\\":"'
        processo = subprocess.run(cmd, shell=True, text=True, capture_output=True)
        monitores = re.findall(r'"name":\s*"([^"]+)"', processo.stdout)

        return monitores

    @classmethod
    def validar_monitores(cls):
        if len(cls.get_monitores()) < 2:
            raise ValueError("Apenas um monitor encontrado!")

    @classmethod
    def recarregar(cls):
        subprocess.run(["swaymsg", "reload"])


class DisplaySwitcherController:
    def __init__(
        self, widget: ISwitcherUI, windowTitle: str, timeout: int = 15
    ) -> None:
        self.widget = widget
        self.windowTitle = windowTitle
        self.timeout = timeout

    def get_monitors(self) -> MonitoresSway:
        SwayService.validar_monitores()
        monitores = SwayService.get_monitores()

        if monitores[1].startswith("eDP") or monitores[0].endswith("2"):
            return MonitoresSway(interno=monitores[1], externo=monitores[0])

        return MonitoresSway(interno=monitores[0], externo=monitores[1])

    def apply_config(self, mode: DisplaySwitchType):
        try:
            monitor = self.get_monitors()
            cmd = ""

            if DisplaySwitchType.PC_ONLY == mode:
                cmd = f"swaymsg output {monitor.interno} enable, output {monitor.externo} disable"
            elif DisplaySwitchType.MONITOR_ONLY == mode:
                cmd = f"swaymsg output {monitor.interno} disable, output {monitor.externo} enable"
            elif DisplaySwitchType.EXTEND == mode:
                cmd = f"swaymsg output {monitor.interno} enable, output {monitor.externo} enable"
            elif DisplaySwitchType.DUPLICATE == mode:
                self.widget.close()
                cmd = f"swaymsg output {monitor.interno} enable, output {monitor.externo} enable; pkill wl-mirror; wl-mirror {monitor.interno}"
                subprocess.run(cmd, shell=True, check=True)
                return

            subprocess.run(cmd, shell=True, check=True)
            print(f"Modo aplicado {mode.value}")

            self.widget.close()
            self.widget.confirmar_ou_reverter()
        except Exception as e:
            self.widget.close()
            msg = QMessageBox()
            msg.setIcon(QMessageBox.Icon.Information)
            msg.setWindowTitle(self.windowTitle)
            msg.setText(e.__str__())
            msg.setStandardButtons(QMessageBox.StandardButton.Ok)
            msg.exec()

            self.widget.close()
            raise Exception("Erro: apenas um monitor econtrado!")

    def recarregar_sway(self):
        SwayService.recarregar()

    def atualizar_timer(self, msg_box: QMessageBox, timer: QTimer):
        self.timeout -= 1
        msg_box.setText(
            f"A configuração foi aplicada.\nVoltando ao normal em {self.timeout} segundos..."
        )

        if self.timeout <= 0:
            timer.stop()
            msg_box.reject()


class DisplayCmd:
    def __init__(self) -> None:
        args = sys.argv

        if args[-1].lower() == "-d":
            self.monitorar_monitor()

    def monitorar_monitor(self):
        monitores_anterior = SwayService.get_monitores()

        while True:
            monitores_atual = SwayService.get_monitores()
            if len(monitores_anterior) != len(monitores_atual):
                monitores_anterior = monitores_atual
                SwayService.recarregar()

            time.sleep(2)


class DisplaySwitcher(ISwitcherUI):
    def __init__(self):
        super().__init__()
        self.winTitle = "SwayDisplaySwitcher"
        self.controller = DisplaySwitcherController(self, self.winTitle)

        self.setWindowTitle(self.winTitle)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setStyleSheet(
            """
            QWidget {
                background-color: rgba(40, 44, 52, 0.95);
                color: white;
                border-radius: 8px;
            }
            QPushButton {
                background-color: transparent;
                border: 1px solid transparent;
                border-radius: 5px;
                padding: 20px;
                font-size: 14px;
                font-weight: bold;
                min-width: 120px;
            }
            QPushButton:hover {
                background-color: rgba(255, 255, 255, 0.1);
                border: 1px solid #5294e2;
            }
            """
        )

        self.initUI()

    def initUI(self):
        layout = QHBoxLayout()

        monitores = self.controller.get_monitors()
        btn_pc = QPushButton(f"🖥️\n{monitores.interno}")
        btn_swap = QPushButton(f"🖥️\n{monitores.externo}")
        btn_extend = QPushButton("🖥️+🖥️\nEstender")
        btn_duplicate = QPushButton("🖥️=🖥️\nDuplicar")

        btn_pc.clicked.connect(
            lambda: self.controller.apply_config(DisplaySwitchType.PC_ONLY)
        )
        btn_swap.clicked.connect(
            lambda: self.controller.apply_config(DisplaySwitchType.MONITOR_ONLY)
        )
        btn_extend.clicked.connect(
            lambda: self.controller.apply_config(DisplaySwitchType.EXTEND)
        )
        btn_duplicate.clicked.connect(
            lambda: self.controller.apply_config(DisplaySwitchType.DUPLICATE)
        )

        layout.addWidget(btn_pc)
        layout.addWidget(btn_swap)
        layout.addWidget(btn_extend)
        layout.addWidget(btn_duplicate)

        self.setLayout(layout)

    def confirmar_ou_reverter(self):
        msg_box = QMessageBox()
        msg_box.setWindowTitle("Confirmação de Mudança")

        msg_box.addButton("Manter", QMessageBox.ButtonRole.AcceptRole)
        btn_reverter = msg_box.addButton("Reverter", QMessageBox.ButtonRole.RejectRole)
        msg_box.setText(
            f"A configuração foi aplicada.\nVoltando ao normal em {self.controller.timeout} segundos..."
        )

        timer = QTimer()
        timer.timeout.connect(lambda: self.controller.atualizar_timer(msg_box, timer))
        timer.start(1000)
        msg_box.exec()
        timer.stop()

        if msg_box.clickedButton() == btn_reverter or self.controller.timeout <= 0:
            self.controller.recarregar_sway()

    def keyPressEvent(self, event: QKeyEvent, /) -> None:
        if event.key() == Qt.Key.Key_Escape:
            self.close()
        else:
            super().keyPressEvent(event)


if __name__ == "__main__":
    argv = sys.argv
    print(argv)

    if len(argv) > 1:
        DisplayCmd()
        sys.exit(0)

    SwayService.validar_monitores()

    app = QApplication(sys.argv)
    ex = DisplaySwitcher()
    ex.show()
    sys.exit(app.exec())
