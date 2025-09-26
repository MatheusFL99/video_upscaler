# FFmpeg Video Upscaler & Frame Interpolator

![GitHub last commit](https://img.shields.io/github/last-commit/MatheusFL99/video_upscaler)
![GitHub top language](https://img.shields.io/github/languages/top/MatheusFL99/video_upscaler)
![License](https://img.shields.io/github/license/MatheusFL99/video_upscaler)

Um aplicativo de desktop multiplataforma construído com Flutter para processar vídeos usando as ferramentas de linha de comando FFmpeg e FFprobe. Ele permite aumentar a resolução (upscaling) e a taxa de quadros (interpolação de frames) de seus vídeos de forma simples e intuitiva.

## 🚀 Funcionalidades

- **Análise de Vídeo**: Obtém automaticamente as propriedades do vídeo (resolução, FPS, duração, codecs, etc.) usando o FFprobe.
- **Upscaling de Resolução**: Aumente a resolução do vídeo para presets populares (HD, Full HD, 4K) ou para uma dimensão personalizada.
- **Interpolação de Frames**: Aumente a fluidez do vídeo interpolando novos frames para alcançar taxas de FPS mais altas (60fps, 120fps, etc.).
- **Processamento em Tempo Real**: Exibe o progresso do processamento do FFmpeg e estima o tempo restante.
- **Log de Console**: Mostra a saída detalhada do FFmpeg para depuração.

**Observação:** Para a **interpolação de frames**, essa aplicação usa o filtro `minterpolate`, que utiliza apenas a CPU. Para um processamento mais rápido, considere usar outras soluções que podem utilizar o GPU se preferir, como o [DAIN](https://github.com/baowenbo/DAIN) ou [RIFE](https://github.com/hzwer/ECCV2022-RIFE).

## 📦 Tecnologias Usadas

- **Flutter**: Framework de UI para construir o aplicativo de desktop.
- **FFmpeg & FFprobe**: Ferramentas poderosas para processamento de vídeo e análise de mídia.
- **process_run**: Biblioteca Dart para executar comandos de linha de forma segura.
- **file_picker**: Biblioteca para abrir caixas de diálogo de seleção de arquivo.

## ⚙️ Instalação e Requisitos

### Pré-requisitos

Para que o aplicativo funcione corretamente, você deve ter o **FFmpeg** e o **FFprobe** instalados e acessíveis a partir do seu PATH do sistema.

- [**Baixe FFmpeg & FFprobe**](https://ffmpeg.org/download.html)

### Buildando o Projeto

1.  **Clone o repositório:**
    ```bash
    git clone https://github.com/MatheusFL99/video_upscaler.git
    cd video_upscaler
    ```
2.  **Instale as dependências do Flutter:**
    ```bash
    flutter pub get
    ```
3.  **Execute o aplicativo:**
    ```bash
    flutter run -d windows  # ou -d macos, -d linux
    ```
