#!/bin/sh

DATA_DIR="/data"
mkdir -p "$DATA_DIR"

CONTAINER_ID=$(hostname)
echo "Starting Container $CONTAINER_ID"

LOCK_FILE="$DATA_DIR/.lockfile"

for SEQ in $(seq 1 5); do
    TARGET_FILE=""
    FOUND=0

    {
        flock -x 33
        i=1
        while [ $i -le 5 ]; do
            NAME=$(printf "%03d" $i)
            FILE_PATH="$DATA_DIR/$NAME"
            if [ ! -e "$FILE_PATH" ]; then
                TARGET_FILE="$FILE_PATH"
                printf "CID: %s | SEQ: %d\n" "$CONTAINER_ID" "$SEQ" > "$TARGET_FILE"
                FOUND=1
                break
            fi
            i=$((i + 1))
        done
    } 33>"$LOCK_FILE"

    if [ "$FOUND" -eq 0 ] || [ -z "$TARGET_FILE" ] || [ ! -f "$TARGET_FILE" ]; then
        echo "ERROR: Failed to create file on iteration $SEQ. Aborting." >&2
        exit 1
    fi

    echo "[Created] $TARGET_FILE (ID: $CONTAINER_ID, SEQ: $SEQ)"
    sleep 1

    if [ -f "$TARGET_FILE" ]; then
        rm -f "$TARGET_FILE"
        echo "[Deleted] $TARGET_FILE"
    else
        echo "WARNING: File $TARGET_FILE disappeared before deletion." >&2
    fi
done

echo "Container $CONTAINER_ID completed 999 files."
