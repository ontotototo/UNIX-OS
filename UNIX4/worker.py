import asyncio
import json
import os
import signal
import socket
from typing import Dict, Any
from loguru import logger
from aiokafka import AIOKafkaConsumer

KAFKA_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", default="kafka:9092")
INPUT_TOPIC = "tasks_topic"

GROUP_NAME = "text_parity_analyzers"
INSTANCE_ID = socket.gethostname()

stop_signal = asyncio.Event()

def signal_handler(signum: int):
    """Обработчик сигналов завершения"""
    logger.warning(f"Получен сигнал завершения {signum} — завершение текущей задачи...")
    stop_signal.set()

async def analyze_message(data: Dict[str, Any], instance: str) -> None:
    """Анализ длины текста и определение чётности"""
    source_text = data.get("input_text", "")
    
    text_length = len(source_text)
    result_type = "чётная" if text_length % 2 == 0 else "нечётная"

    await asyncio.sleep(2)  #симуляция бурной работы

    logger.info(f"[{instance}] УРА Задача выполнена")
    logger.info(f"Исходный текст: \"{source_text[:30]}...\"")
    logger.info(f"Длина: {text_length} символов → {result_type.upper()}\n")

async def start_processor():
    """Основной цикл обработки сообщений"""
    current_loop = asyncio.get_running_loop()
    
    current_loop.add_signal_handler(signal.SIGTERM, lambda: signal_handler(signal.SIGTERM))
    current_loop.add_signal_handler(signal.SIGINT, lambda: signal_handler(signal.SIGINT))

    logger.info(f"Процессор [{INSTANCE_ID}] запускается...")
    
    kafka_consumer = None
    connection_attempts = 0
    max_connections = 25

    while connection_attempts < max_connections:
        try:
            logger.info(f"[{INSTANCE_ID}] Подключение к Kafka (попытка {connection_attempts + 1}/{max_connections})...")
            kafka_consumer = AIOKafkaConsumer(
                INPUT_TOPIC,
                bootstrap_servers=KAFKA_SERVERS,
                group_id=GROUP_NAME,
                auto_offset_reset='latest',
                enable_auto_commit=False,
                value_deserializer=lambda msg: json.loads(msg.decode('utf-8'))
            )
            await kafka_consumer.start()
            logger.info(f"[{INSTANCE_ID}] Подключён к топику '{INPUT_TOPIC}'")
            break
        except Exception as exc:
            logger.warning(f"[{INSTANCE_ID}] Ошибка подключения: {exc}")
            connection_attempts += 1
            await asyncio.sleep(5)
    
    if kafka_consumer is None:
        logger.critical(f"[{INSTANCE_ID}] Критическая ошибка: не удалось подключиться к Kafka")
        return

    try:
        while not stop_signal.is_set():
            record = await kafka_consumer.getone()
            message_data = record.value
            await analyze_message(message_data, INSTANCE_ID)
            await kafka_consumer.commit()
    finally:
        await kafka_consumer.stop()
        logger.info(f"[{INSTANCE_ID}] Процессор остановлен")

if __name__ == "__main__":
    asyncio.run(start_processor())