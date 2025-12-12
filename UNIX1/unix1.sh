#!/bin/sh
START_DIR=$(pwd)

error_exit() {
    echo "ОШИБКА: $1" >&2
    exit 1
}

cleanup() {
    cd "$START_DIR"
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

if [ "$#" -ne 1 ]; then
    error_exit "После $0 должен передаваться 1 аргумент"  
fi

SOURCE_FILE="$1"
SOURCE_DIR=$(dirname "$SOURCE_FILE")
SOURCE_FILENAME=$(basename "$SOURCE_FILE")
if [ ! -f "$SOURCE_FILE" ]; then
    error_exit "Исходный файл не найден/недоступен для чтения: $SOURCE_FILE"
fi

if [ "${SOURCE_FILENAME##*.}" != "cpp" ]; then
    error_exit "Поддерживаются только файлы с расширением .cpp: $SOURCE_FILE"
fi

OUTPUT_FILENAME=$(grep 'Output:' "$SOURCE_FILE" | sed 's/.*Output:[[:space:]]*//')

if [ -z "$OUTPUT_FILENAME" ]; then
    error_exit "Не удалось найти комментарий с именем выходного файла в формате 'Output: <имя_файла>'."
fi

TEMP_DIR=$(mktemp -d XXXXXXX)

trap cleanup EXIT HUP INT TERM

cp "$SOURCE_FILE" "$TEMP_DIR/$SOURCE_FILENAME"

cd "$TEMP_DIR"

echo "Компиляция C++ файла началась"

if g++ -o "$OUTPUT_FILENAME" "$SOURCE_FILENAME"; then
    COMPILATION_SUCCESSFUL=true
else
    error_exit "Ошибка компиляции"
fi

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
