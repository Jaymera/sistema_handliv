from __future__ import annotations

import logging
from email.message import EmailMessage

import aiosmtplib

from app.config import settings

logger = logging.getLogger(__name__)


async def send_email(to: str, subject: str, html_body: str) -> None:
    if not settings.smtp_user or not settings.smtp_password.get_secret_value():
        logger.warning("SMTP not configured; skipping email send to %s", to)
        return
    message = EmailMessage()
    message["From"] = settings.smtp_from or settings.smtp_user
    message["To"] = to
    message["Subject"] = subject
    message.set_content("Seu cliente de e-mail não suporta HTML.")
    message.add_alternative(html_body, subtype="html")
    try:
        await aiosmtplib.send(
            message,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=settings.smtp_user,
            password=settings.smtp_password.get_secret_value(),
            start_tls=True,
        )
    except Exception as exc:
        logger.exception("Failed sending email to %s: %s", to, exc)