#!/bin/sh

# Стартовая папка
START_DIR=$(pwd)

#1. Возвращать информативный код ошибки 
error_exit() {
    echo "ОШИБКА: $1" >&2
    exit 1
}

# Для очистки временного каталога
cleanup() {
    cd "$START_DIR"
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Проверка количества аргументов
if [ "$#" -ne 1 ]; then
    error_exit "После $0 должен передаваться 1 аргумент"  
fi

# Проверка на существование файла
SOURCE_FILE="$1"
SOURCE_DIR=$(dirname "$SOURCE_FILE")
SOURCE_FILENAME=$(basename "$SOURCE_FILE")
if [ ! -f "$SOURCE_FILE" ]; then
    error_exit "Исходный файл не найден/недоступен для чтения: $SOURCE_FILE"
fi

# Проверка расширения файла
if [ "${SOURCE_FILENAME##*.}" != "cpp" ]; then
    error_exit "Поддерживаются только файлы с расширением .cpp: $SOURCE_FILE"
fi

# 2. Анализ текста и поиск комментария с именем выходного файла
OUTPUT_FILENAME=$(grep 'Output:' "$SOURCE_FILE" | sed 's/.*Output:[[:space:]]*//')

# Проверка на коммент(-z на пустоту переменной)
if [ -z "$OUTPUT_FILENAME" ]; then
    error_exit "Не удалось найти комментарий с именем выходного файла в формате 'Output: <имя_файла>'."
fi

# 3. Сборка должна производиться в временном каталоге с  mktemp, 
TEMP_DIR=$(mktemp -d XXXXXXX)

# 4. Каталог должен быть удалён при любом исходе работы скрипта
trap cleanup EXIT HUP INT TERM

# Копируем исходник во временную папку
cp "$SOURCE_FILE" "$TEMP_DIR/$SOURCE_FILENAME"

# Переходим во временный каталог 
cd "$TEMP_DIR"

echo "Компиляция C++ файла началась"

# Компилируем
if g++ -o "$OUTPUT_FILENAME" "$SOURCE_FILENAME"; then
    COMPILATION_SUCCESSFUL=true
else
    error_exit "Ошибка компиляции"
fi

# Проверка наличия скомпилированного файла
if [ "$COMPILATION_SUCCESSFUL" = true ]; then
    if [ -f "$OUTPUT_FILENAME" ]; then
        # Возвращаем файл обратно
        mv "$OUTPUT_FILENAME" "$START_DIR/$SOURCE_DIR/"
        echo "Компиляция окончена. Результат: $START_DIR/$SOURCE_DIR/$OUTPUT_FILENAME"
    else
        error_exit "Скомпилированный файл не найден в temp каталоге."
    fi
fi

exit 0