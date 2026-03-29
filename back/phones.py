import aiohttp
from os import environ as env
import logging

sms_api_key = env.get("SMS_API_KEY", "DEFAULT KEY")
sms_relay_addr = env.get("SMS_RELAY_ADDR")


async def send_sms(to: str, message: str):
    if not sms_api_key or not sms_relay_addr:
        return

    headers = {
        "X-Api-Key": sms_api_key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    data = {"to": to, "message": message}

    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(sms_relay_addr, headers=headers, json=data) as resp:
                if resp.status == 200:
                    logging.info("SMS sent successfully")

                else:
                    error_text = await resp.text()
                    logging.error(f"Failed to send SMS:\n{e}")

    except aiohttp.ClientError as e:
        logging.error(f"Failed to send SMS to {to}: {e}")
