from functools import lru_cache
from typing import Literal

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_env: Literal["development", "production"] = "development"
    app_secret: SecretStr = SecretStr("change-me")
    cors_origins: str = "http://localhost:8081,http://localhost:8080"

    # Database / Cache
    database_url: str = "mysql+pymysql://handliv:handliv@localhost:3306/handliv"
    redis_url: str = "redis://localhost:6379/0"

    # JWT
    jwt_secret: SecretStr = SecretStr("change-me-jwt")
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    password_reset_expire_minutes: int = 30

    # Stripe
    stripe_secret_key: SecretStr = SecretStr("")
    stripe_publishable_key: SecretStr = SecretStr("")
    stripe_webhook_secret: SecretStr = SecretStr("")
    stripe_product_free: str = ""
    stripe_product_start: str = ""
    stripe_product_ultimate: str = ""
    stripe_price_free: str = ""
    stripe_price_pro: str = ""
    stripe_price_premium: str = ""

    # Links externos
    whatsapp_url: str = "https://wa.me/551152866453"
    discord_url: str = "https://discord.com/invite/6X3MamvS5T"
    cursos_url: str = "https://handliv.kpages.online/cursos"

    # Super Admin bootstrap
    admin_name: str = "Handliv"
    admin_email: str = "admin@handliv.com"
    admin_username: str = "Handliv"
    admin_password: SecretStr = SecretStr("samsung12")

    # SMTP (Gmail)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: SecretStr = SecretStr("")
    smtp_from: str = "no-reply@handliv.com"

    # Push (Expo)
    expo_access_token: SecretStr = SecretStr("")

    # Market data
    market_data_provider: Literal["yfinance"] = "yfinance"

    # IA / NLP
    llm_provider: Literal["disabled", "openai", "anthropic"] = "disabled"
    llm_api_key: SecretStr = SecretStr("")

    # MT5
    mt5_api_base_url: str = ""
    mt5_api_token: SecretStr = SecretStr("")

    # Uploads
    uploads_driver: Literal["local", "s3", "minio"] = "local"
    uploads_base_dir: str = "./storage/uploads"
    uploads_max_size_mb: int = 100
    uploads_allowed_ext: str = "zip,rar,ex5,mq5,pdf"

    # Polling yfinance: schedules (horário Brasília), separados por vírgula
    yfinance_fetch_times: str = "10:00,18:00"

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def uploads_allowed_exts(self) -> list[str]:
        return [e.strip().lower() for e in self.uploads_allowed_ext.split(",") if e.strip()]

    @property
    def fetch_times_list(self) -> list[str]:
        return [t.strip() for t in self.yfinance_fetch_times.split(",") if t.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


settings = get_settings()