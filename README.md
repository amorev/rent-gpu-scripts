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
- `API_KEY`: если задан, будет проброшен в контейнер для `llama-server`
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

Если нужен ключ для HTTP API `llama-server`, его можно задать через env:

```bash
API_KEY=my-secret-key bash /path/to/scripts/run.sh
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
- Если задаёшь `ROOT_DIR`, `MODEL_DIR`, `HF_HOME_DIR` или `LLAMA_CACHE_DIR` вручную, используй абсолютный путь без кавычек-литералов вроде `'$HOME/...'`.
- `setup.sh` нужно пересобирать с правильным `CUDA_ARCHITECTURES` под целевой сервер.
- Если `GPU_VISIBLE_DEVICES` не равен `all`, в контейнер будут проброшены только выбранные GPU.
- Если упираешься в OOM, сначала уменьшай `CTX_SIZE` или `BATCH_SIZE`.
- Для очень больших моделей на нескольких GPU `TENSOR_SPLIT` обычно нужно подбирать экспериментально.

## Примеры запусков Qwen 3.6

Есть готовые bundle-скрипты:

- `bundles/3090-1.sh`: подготовка окружения под одну RTX 3090
- `bundles/4090-1.sh`: подготовка окружения под одну RTX 4090

Важно: bundle не сохраняет свои `export` после завершения, потому что запускается через `bash`, а не через `source`. После `bundles/*.sh` запускай `run.sh` с теми же env-переменными, которые bundle печатает в конце одной готовой командой.

### На сервере одна RTX 4090
В этом случае можно запустить Qwen только в 4-кванте. Остальные уже не влезут только в GPU.

```bash
# Запуск 35b-a3b
export MODEL_FILE=Qwen3.6-35B-A3B-Q4_K_M.gguf 
export MODEL_REPO=lmstudio-community/Qwen3.6-35B-A3B-GGUF
export CTX_SIZE=100000
bash scripts/bundles/4090-1.sh
bash scripts/run.sh
```

```bash
# Запуск 35b-a3b
export MODEL_FILE=Qwen3.6-27B-Q4_K_M.gguf
export MODEL_REPO=lmstudio-community/Qwen3.6-27B-GGUF
export CTX_SIZE=100000
bash scripts/bundles/4090-1.sh
bash scripts/run.sh
```
