#!/usr/bin/env python3
import sys
import subprocess
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QProgressBar, QLabel
from PySide6.QtCore import Qt, QTimer


QT_QPA_PLATFORM = "wayland"


class BrightnessctlService:
    @classmethod
    def get_brightness_cmd(cls, cmd: list[str]) -> int:
        try:
            cmd = ["brightnessctl"] + cmd
            return int(subprocess.check_output(cmd).strip())
        except Exception:
            return 0

    @classmethod
    def get_current_percentage(cls):
        cur = cls.get_brightness_cmd(["g"])
        maxv = cls.get_brightness_cmd(["m"])

        if maxv == 0:
            return 0
        return int((cur * 100) / maxv)

    @classmethod
    def set_brightness(cls, value: int):
        if value < 1:
            value = 1
        elif value > 100:
            value = 100

        subprocess.run(["brightnessctl", "set", f"{value}%"])
        return value


class BrightnessctlController:
    @classmethod
    def toggle_brightness(cls, acao: str):
        curr = BrightnessctlService.get_current_percentage()

        if acao == "up":
            curr += 5
        elif acao == "down":
            curr -= 5

        return BrightnessctlService.set_brightness(curr)


class OSDBrightness(QWidget):
    def __init__(self, acao: str):
        super().__init__()
        self.setWindowFlag(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )

        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.resize(300, 50)

        QApplication.setDesktopFileName("sway.osd.brightness")
        layout = QHBoxLayout()
        self.setLayout(layout)

        self.setStyleSheet("""
            QWidget {
                background-color: rgba(30, 30, 30, 220);
                border-radius: 8px;
            }
            QProgressBar {
                border: 1px solid #444;
                border-radius: 4px;
                background-color: #222;
                text-align: center;
                color: transparent;
            }
            QProgressBar::chunk {
                background-color: #9A67EA ;
                border-radius: 3px;
            }
            QLabel {
                color: #ffffff;
                font-family: sans-serif;
                font-weight: bold;
                font-size: 30px;
                background: transparent;
            }
        """)
        brightness_percent = BrightnessctlController.toggle_brightness(acao)

        icon_label = QLabel("🌕")
        icon_label.setFixedWidth(50)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(icon_label)

        self.bar = QProgressBar()
        self.bar.setRange(0, 100)
        self.bar.setValue(brightness_percent)
        self.bar.setTextVisible(False)
        layout.addWidget(self.bar)

        QTimer.singleShot(1000, QApplication.quit)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    acao = sys.argv[1] if len(sys.argv) > 1 else ""

    janela = OSDBrightness(acao)
    janela.setWindowTitle("OSD Brightness")
    janela.show()
    sys.exit(app.exec())
