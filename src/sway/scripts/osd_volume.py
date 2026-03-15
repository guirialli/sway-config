#!/bin/env python3
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QProgressBar, QLabel
from PySide6.QtCore import Qt, QTimer
import subprocess
import sys


QT_QPA_PLATFORM = "wayland"


def gerenciar_volume(acao: str) -> list[float | bool]:
    if acao == "up":
        subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"])
    elif acao == "down":
        subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
    elif acao == "mute":
        print("")
        subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])

    resultado = subprocess.run(
        ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
        text=True,
        capture_output=True,
    )

    saida = resultado.stdout.strip()
    is_muted = "[MUTED]" in saida
    volume = 0.0

    for palava in saida.split():
        try:
            volume = float(palava) * 100
            break
        except Exception:
            continue

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
                background-color: #77aaff;
                border-radius: 3px;
            }
            QLabel {
                color: #ffffff;
                font-family: sans-serif;
                font-weight: bold;
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

        QTimer.singleShot(1000, QApplication.quit)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    acao = sys.argv[1] if len(sys.argv) else ""

    volume, is_muted = gerenciar_volume(acao)

    janela = OSDVolume(volume, bool(is_muted))
    janela.setWindowTitle("OSD Volume")
    janela.show()
    sys.exit(app.exec())
