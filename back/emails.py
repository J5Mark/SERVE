import smtplib
import logging
from email.mime.text import MIMEText
from os import environ as env

logger = logging.getLogger()

smtp_email = env.get("GOOGLE_SENDER_EMAIL")
smtp_password = env.get("GOOGLE_PASSWORD")

if not smtp_email or not smtp_password:
    logger.warning("Gmail SMTP credentials not configured (GOOGLE_SENDER_EMAIL, GOOGLE_TOKEN)")


async def send_email(to: str, subject: str, message: str):
    if not smtp_email or not smtp_password:
        logger.error("Gmail SMTP credentials not configured!")
        return

    try:
        msg = MIMEText(message)
        msg['Subject'] = subject
        msg['From'] = smtp_email
        msg['To'] = to

        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(smtp_email, smtp_password)
            smtp.send_message(msg)

        logger.info(f"Email sent successfully to {to}")
    except Exception as e:
        logger.error(f"Error sending email to {to}: {e}")
