#!/usr/bin/env python3
import sys
import os
import subprocess
from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QListWidget,
    QListWidgetItem,
)
from PySide6.QtGui import QIcon, QImage, QPixmap, QKeyEvent
from PySide6.QtCore import QSize, Qt, QThread, Signal


class CarregadorDeImagens(QThread):
    imagem_carregada = Signal(str, QImage)

    def __init__(self, pasta: str):
        super().__init__()
        self.pasta = pasta

    def run(self, /) -> None:
        extensoes_validar = (".jpg", ".jpeg", ".png", ".webp")
        if not os.path.isdir(self.pasta):
            return
        for nome_arquivo in sorted(os.listdir(self.pasta)):
            if not nome_arquivo.lower().endswith(extensoes_validar):
                continue

            caminho_completo = os.path.join(self.pasta, nome_arquivo)
            imagem = QImage(caminho_completo)

            if imagem.isNull():
                continue

            miniatura = imagem.scaled(
                240,
                135,
                Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                Qt.TransformationMode.SmoothTransformation,
            )
            self.imagem_carregada.emit(caminho_completo, miniatura)


class ListaImagens(QListWidget):
    def __init__(self, fn_aplicar_image, fn_close):
        super().__init__()
        self.fn_aplicar_image = fn_aplicar_image
        self.fn_close = fn_close

    def keyPressEvent(self, event: QKeyEvent) -> None:
        if (
            event.key() in (Qt.Key.Key_Enter, Qt.Key.Key_Return)
            and self.fn_aplicar_image
        ):
            item = self.currentItem()
            self.fn_aplicar_image(item)
        elif event.key() == Qt.Key.Key_Escape and self.fn_close:
            self.fn_close()
        else:
            return super().keyPressEvent(event)


class WallpapaerPicker(QWidget):
    def __init__(self, pasta_imagem: str):
        super().__init__()
        self.pasta_imagens = pasta_imagem
        self.arquivo_config = os.path.expanduser("~/.config/sway/config.d/42-wallpaper")

        self.setWindowTitle("Seletor Wallpaper")
        self.resize(900, 600)
        QApplication.setDesktopFileName("sway.apps.wallpaper-picker")
        layout = QVBoxLayout()
        self.setLayout(layout)

        self.lista_imagens = ListaImagens(self.aplicar_wallpaper, lambda: self.close())
        self.lista_imagens.setViewMode(QListWidget.ViewMode.IconMode)
        self.lista_imagens.setIconSize(QSize(240, 135))
        self.lista_imagens.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.lista_imagens.setSpacing(15)
        layout.addWidget(self.lista_imagens)

        self.setStyleSheet("""
            QScrollBar:vertical {
                border: none;
                background-color: #1a1b26; /* Fundo invisível/mesma cor da janela */
                width: 12px;
                margin: 0px;
            }
            
            QScrollBar::handle:vertical {
                background-color: #9d7cd8; 
                min-height: 30px;
                border-radius: 6px; 
            }
            
            QScrollBar::handle:vertical:hover {
                background-color: #bb9af7;
            }
            
            QScrollBar::sub-line:vertical, QScrollBar::add-line:vertical {
                height: 0px;
                background: none;
            }
            
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
                background: transparent;
            }

            QWidget{
                background-color: rgba(30, 30, 30, 220);
                color: #c0caf5;
            }
            QListWidget {
                border: none;
                outline: none;
                background-color: transparent;
            }
            QListWidget::item{
                border-radius: 8px;
                padding: 5px;
            }
            QListWidget::item:selected {
                background-color: #9A67EA;
            }

        """)
        self.lista_imagens.itemDoubleClicked.connect(self.aplicar_wallpaper)

        self.carregador = CarregadorDeImagens(self.pasta_imagens)
        self.carregador.imagem_carregada.connect(self.carregar_imagem)
        self.carregador.start()

    def carregar_imagem(self, caminho: str, image: QImage):
        item = QListWidgetItem()
        pixmap = QPixmap.fromImage(image)
        item.setIcon(QIcon(pixmap))
        item.setData(Qt.ItemDataRole.UserRole, caminho)

        self.lista_imagens.addItem(item)

    def aplicar_wallpaper(self, item: QListWidgetItem):
        caminho_imagem = item.data(Qt.ItemDataRole.UserRole)
        linha_config = f'output "*" bg {caminho_imagem} fill\n'

        try:
            os.makedirs(os.path.dirname(self.arquivo_config), exist_ok=True)
            with open(self.arquivo_config, "w") as f:
                f.write(linha_config)

            subprocess.run(["swaymsg", "reload"])
            self.close()
        except Exception as e:
            print(f"Erro ao aplicar wallpaper {e}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(
            "Uso correto: python wallpaper_picker.py /caminho/para/sua/pasta/de/imagens"
        )
        sys.exit(1)

    app = QApplication(sys.argv)
    pasta = sys.argv[1]
    janela = WallpapaerPicker(pasta)
    janela.show()
    sys.exit(app.exec())
