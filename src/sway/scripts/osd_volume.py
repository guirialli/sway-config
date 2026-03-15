#!/bin/env python3
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QProgressBar, QLabel
from PySide6.QtCore import Qt, QTimer
import subprocess
import sys


QT_QPA_PLATFORM = "wayland"


class MixerService:
    @classmethod
    def _get_status(cls):
        resultado = subprocess.run(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            text=True,
            capture_output=True,
        )

        return resultado.stdout.strip()

    @classmethod
    def get_is_muted(cls) -> bool:
        saida = cls._get_status()
        return "[MUTED]" in saida

    @classmethod
    def get_volume(cls) -> float:
        saida = cls._get_status()
        volume = 0.0
        for palava in saida.split():
            try:
                volume = float(palava) * 100
                break
            except Exception:
                continue

        return volume

    @classmethod
    # percent deve seguir o padrão do wpctl usando 5%+ por exemplo para aumentar 5 porcento
    # Ou 5%- para reduzir 5 porcento
    def set_volume(cls, percent: str):
        subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", percent])

    @classmethod
    def toggle_volume_muted(cls):
        subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])


class MixerController:
    @classmethod
    def gerenciar_volume(cls, acao: str) -> list[float | bool]:
        if acao != "mute" and MixerService.get_is_muted():
            MixerService.toggle_volume_muted()

        if acao == "up":
            volume = MixerService.get_volume()
            if volume >= 100:
                return [volume, MixerService.get_is_muted()]
            MixerService.set_volume("5%+")
        elif acao == "down":
            MixerService.set_volume("5%-")
        elif acao == "mute":
            MixerService.toggle_volume_muted()

        volume = MixerService.get_volume()
        is_muted = MixerService.get_is_muted()

        return [volume, is_muted]


class OSDVolume(QWidget):
    def __init__(self, volume: float, is_muted: bool):
        super().__init__()

        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.resize(300, 50)

        QApplication.setDesktopFileName("sway.osd.volume")

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

        indicador = "🔇" if is_muted else "🎧"
        icon_label = QLabel(indicador)
        icon_label.setFixedWidth(50)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(icon_label)

        self.bar = QProgressBar()
        self.bar.setRange(0, 100)
        self.bar.setValue(int(volume))
        self.bar.setTextVisible(False)
        layout.addWidget(self.bar)

        QTimer.singleShot(900, QApplication.quit)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    acao = sys.argv[1] if len(sys.argv) > 1 else ""

    volume, is_muted = MixerController.gerenciar_volume(acao)

    janela = OSDVolume(volume, bool(is_muted))
    janela.setWindowTitle("OSD Volume")
    janela.show()
    sys.exit(app.exec())
