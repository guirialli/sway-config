#!/usr/bin/env python3
import sys
import subprocess
from PySide6.QtCore import Qt
from PySide6.QtWidgets import QApplication, QWidget, QSlider, QHBoxLayout
from PySide6.QtGui import QKeyEvent


def get_brightness_cmd(cmd):
    """Auxiliar para rodar comandos do brightnessctl"""
    try:
        return int(subprocess.check_output(["brightnessctl", cmd]).strip())
    except Exception:
        return 0


def get_current_percentage():
    cur = get_brightness_cmd("g")
    maxv = get_brightness_cmd("m")
    if maxv == 0:
        return 0
    return int((cur * 100) / maxv)


class BrightnessPopup(QWidget):
    def __init__(self):
        super().__init__()

        # --- Configurações da Janela ---
        # Remove a barra de título e bordas
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        # Permite fundo transparente (para bordas arredondadas funcionarem visualmente)
        self.setAttribute(Qt.WA_TranslucentBackground)

        # Tamanho fixo
        self.setFixedSize(320, 60)

        # --- Layout e Widgets ---
        layout = QHBoxLayout()
        layout.setContentsMargins(15, 10, 15, 10)  # Margens internas

        self.slider = QSlider(Qt.Horizontal)
        self.slider.setRange(1, 100)
        self.slider.setValue(get_current_percentage())

        # Conecta os sinais (eventos)
        self.slider.valueChanged.connect(self.set_brightness)
        self.slider.sliderReleased.connect(self.close_app)  # Fecha ao soltar o mouse

        layout.addWidget(self.slider)
        self.setLayout(layout)

        # --- Estilização (CSS/QSS) ---
        # Aqui definimos a cor de fundo escura e o estilo do slider
        self.setStyleSheet("""
            QWidget {
                background-color: #1e1e2e; /* Cor escura (estilo Catppuccin/Astronaut) */
                border: 2px solid #89b4fa; /* Borda azulada */
                border-radius: 15px;
            }
            QSlider::groove:horizontal {
                border: 1px solid #313244;
                height: 8px;
                background: #45475a;
                margin: 2px 0;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #89b4fa;
                border: 1px solid #89b4fa;
                width: 18px;
                height: 18px;
                margin: -5px 0;
                border-radius: 9px;
            }
        """)

        # Tenta centralizar na tela ativa
        self.center_on_screen()

    def center_on_screen(self):
        screen = QApplication.primaryScreen()
        if screen:
            rect = screen.availableGeometry()
            center_point = rect.center()
            frame_geom = self.frameGeometry()
            frame_geom.moveCenter(center_point)
            self.move(frame_geom.topLeft())

    def set_brightness(self, value):
        # Chama o brightnessctl
        self.brilho = value
        subprocess.run(["brightnessctl", "set", f"{value}%"])

    def set_brightnes_ext_monitor(self, value):
        if value != 100:
            value -= 10
        if value <= 0:
            value = 1

        subprocess.run(["ddcutil", "setvcp", "10", f"{value}", "--bus=6", "--noverify"])

    def close_app(self):
        # Fecha o aplicativo suavemente
        self.close()
        self.set_brightnes_ext_monitor(self.brilho)

    def keyPressEvent(self, event: QKeyEvent, /) -> None:
        if event.key() == Qt.Key.Key_Escape:
            self.close()
        else:
            return super().keyPressEvent(event)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = BrightnessPopup()
    window.show()
    sys.exit(app.exec())
