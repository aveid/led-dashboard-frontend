# =============================================================================
# frontend/Dockerfile — сборка Flutter Web в статику + раздача через nginx.
#
# Официального Docker-образа Flutter от Google нет, поэтому SDK клонируется из
# репозитория (канал stable) прямо на этапе сборки. Итоговый образ — просто
# nginx со статикой, самого Flutter SDK в нём нет (multi-stage build).
#
# API_URL передаётся как build-arg и "запекается" в сборку через
# --dart-define — Flutter Web не читает переменные окружения в рантайме,
# значение фиксируется в момент `flutter build web`. Чтобы сменить адрес
# бэкенда, образ нужно пересобрать (см. docker-compose.yml, build.args).
# =============================================================================

# --- Этап 1: сборка ---
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Клонируем Flutter SDK (канал stable, без истории — быстрее и легче образ).
RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 /flutter
ENV PATH="/flutter/bin:${PATH}"

# Прогреваем инструменты веб-сборки один раз, чтобы это осело в кэш слоя
# (следующие пересборки с тем же base-образом это не повторяют).
RUN flutter config --enable-web --no-analytics && flutter precache --web

WORKDIR /app
COPY . .
RUN flutter pub get

# Адрес бэкенда, "запекаемый" в сборку. Дефолт — локальный бэк для разработки;
# для прода переопределяется через build.args в docker-compose.yml.
ARG API_URL=http://localhost:8000
RUN flutter build web --release --dart-define=API_URL=${API_URL}

# --- Этап 2: раздача статики ---
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
