# Универсальные GPU-скрипты для llama.cpp

В этой директории лежат общие скрипты для подготовки окружения и запуска `llama.cpp` на разных NVIDIA GPU. Текущие значения по умолчанию подобраны под RTX 4090, но все GPU-зависимые параметры вынесены в переменные окружения.

Каталог можно переименовать, например в `scripts`, и положить в любое место на сервере. Скрипты не завязаны на имя директории и должны вызываться по полному пути через `bash`.

## Скрипты

- `profiles.sh`: загружает готовый профиль переменных окружения по имени GPU.
- `setup.sh`: собирает Docker-образ и проверяет доступ Docker к GPU.
- `download.sh`: скачивает GGUF-модель из Hugging Face.
- `run.sh`: запускает `llama-server` с выбранной моделью и runtime-параметрами.
- `llama-server.dockerfile`: Dockerfile для сборки с настраиваемой CUDA-архитектурой.

## Общие переменные

При смене GPU или модели обычно нужно задавать эти переменные:

- `ROOT_DIR`: базовая директория для моделей и кэшей. По умолчанию: `$HOME/llama-runtime`
- `IMAGE_TAG`: тег Docker-образа. По умолчанию: `llama-server:local`
- `DOCKERFILE_PATH`: путь к `llama-server.dockerfile`
- `BUILD_CONTEXT`: build context для `setup.sh`
- `CUDA_ARCHITECTURES`: CUDA-архитектура, передаваемая в CMake при сборке
- `MODEL_REPO`: репозиторий Hugging Face для `download.sh`
- `MODEL_FILE`: имя GGUF-файла для `download.sh` и `run.sh`
- `MODEL_DIR_NAME`: имя локальной директории модели. По умолчанию: имя файла без `.gguf`
- `GPU_VISIBLE_DEVICES`: какие GPU отдавать в Docker. Варианты: `all`, `0`, `1`, `0,1`
- `CTX_SIZE`
- `BATCH_SIZE`
- `UBATCH_SIZE`
- `THREADS`
- `N_GPU_LAYERS`
- `SPLIT_MODE`: например `none`, `layer` или другой режим `llama.cpp`
- `MAIN_GPU`: индекс основной GPU внутри контейнера
- `TENSOR_SPLIT`: опциональное распределение по нескольким GPU, например `1,1` или `3,2,2,1`

## Быстрый старт

Сначала загрузи профиль GPU в текущую shell-сессию:

```bash
source /path/to/scripts/profiles.sh 4090
```

Доступные профили:

```bash
3090
v100
4090
h100
h200
h100nvl
```

Собрать образ:

```bash
bash /path/to/scripts/setup.sh
```

Скачать модель:

```bash
HF_TOKEN=... \
bash /path/to/scripts/download.sh
```

Запустить модель:

```bash
bash /path/to/scripts/run.sh
```

При необходимости можно переопределять отдельные переменные уже после загрузки профиля:

```bash
source /path/to/scripts/profiles.sh h100
export GPU_VISIBLE_DEVICES=0,1
export SPLIT_MODE=layer
export TENSOR_SPLIT=1,1
bash /path/to/scripts/run.sh
```

## Профили GPU

Доступные профили:

- `3090`
- `v100`
- `4090`
- `h100`
- `h200`
- `h100nvl`

Профиль загружается так:

```bash
source /path/to/scripts/profiles.sh 4090
```

## Примеры для нескольких GPU

Две GPU, отдать обе в Docker и разделить нагрузку поровну:

```bash
source /path/to/scripts/profiles.sh 4090
export GPU_VISIBLE_DEVICES=0,1
export SPLIT_MODE=layer
export MAIN_GPU=0
export TENSOR_SPLIT=1,1
bash /path/to/scripts/run.sh
```

Четыре GPU, немного сместить нагрузку в сторону первой:

```bash
source /path/to/scripts/profiles.sh h100
export GPU_VISIBLE_DEVICES=0,1,2,3
export SPLIT_MODE=layer
export MAIN_GPU=0
export TENSOR_SPLIT=3,2,2,1
bash /path/to/scripts/run.sh
```

Образ обычно достаточно собрать один раз под семейство GPU сервера, а дальше можно быстро переключать модели через переменные модели.

## Замечания

- `profiles.sh` нужно подключать через `source`, иначе переменные не останутся в текущей shell-сессии.
- `setup.sh` нужно пересобирать с правильным `CUDA_ARCHITECTURES` под целевой сервер.
- Если `GPU_VISIBLE_DEVICES` не равен `all`, в контейнер будут проброшены только выбранные GPU.
- Если упираешься в OOM, сначала уменьшай `CTX_SIZE` или `BATCH_SIZE`.
- Для очень больших моделей на нескольких GPU `TENSOR_SPLIT` обычно нужно подбирать экспериментально.
