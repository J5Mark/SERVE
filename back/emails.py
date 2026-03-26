from mailersend import MailerSendClient, EmailBuilder
from os import environ as env
import logging

logger = logging.getLogger()

email_token = env.get("EMAIL_TOKEN")
email_gateway = env.get("EMAIL_GATEWAY")

ms = None

if email_token and email_gateway:
    ms = MailerSendClient(api_key=email_token, base_url=email_gateway, debug=True)


async def send_email(to: str, message: str):
    if not ms:
        logger.error(f'Mailersend client is not configured!')
        return
    email = (
        EmailBuilder()
        .from_email("sender@test-q3enl6k652r42vwr.mlsender.net", "SERVE")
        .to_many([{'email': to, "name": ""}])
        .subject("Your email verification code")
        .text(message)
        .build()
    )

    response = ms.emails.send(email)
    
