import asyncio
import json
import os
from loguru import logger
from aiokafka import AIOKafkaProducer
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional

KAFKA_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", default="kafka:9092")
QUEUE_TOPIC = "tasks_topic"

application = FastAPI()
kafka_producer: Optional[AIOKafkaProducer] = None

class InputText(BaseModel):
    text: str

async def initialize_kafka() -> None:
    """Инициализация подключения к Kafka брокеру"""
    global kafka_producer
    attempts = 0
    max_attempts = 25
    
    while attempts < max_attempts:
        try:
            logger.info(f"Подключение к Kafka (попытка {attempts + 1}/{max_attempts})")
            kafka_producer = AIOKafkaProducer(
                bootstrap_servers=KAFKA_SERVERS,
                value_serializer=lambda data: json.dumps(data).encode('utf-8')
            )
            await kafka_producer.start()
            logger.info("Успешное подключение к Kafka!")
            return
        except Exception as error:
            logger.warning(f"Ошибка подключения: {error}")
            attempts += 1
            await asyncio.sleep(5)
    
    raise RuntimeError("Не удалось подключиться к Kafka")

async def cleanup_kafka() -> None:
    """Завершение работы с Kafka"""
    if kafka_producer:
        await kafka_producer.stop()
        logger.info("Kafka продюсер остановлен")

@app.on_event("startup")
async def on_startup():
    await initialize_kafka()

@app.on_event("shutdown")
async def on_shutdown():
    await cleanup_kafka()

@app.post("/analyze", status_code=202)
async def process_text(input_data: InputText):
    """Обработка входящего текста, постановка задачи в очередь"""
    
    await kafka_producer.send_and_wait(
        QUEUE_TOPIC,
        {"input_text": input_data.text}
    )
    
    return {
        "status": "queued",
        "message": "Задача принята, результат анализа будет сформирован воркерами"
    }