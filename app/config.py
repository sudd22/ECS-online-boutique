from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    ENVIRONMENT: str = "local"
    DB_HOST: str = "db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "local_secure_password123"
    DB_NAME: str = "b2b_monolith_dev"
    DB_PORT: int = 5432

    JWT_SECRET_KEY: str = "local_development_only_secret_key_987654321"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24

    DATABASE_URL: str | None = None

    AWS_REGION: str = "eu-west-2"
    NOTIFICATIONS_QUEUE_URL: str | None = None

    DB_SECRET_ARN: str | None = None

    @property
    def db_url(self) -> str:
        if self.DATABASE_URL:
            return self.DATABASE_URL
        password = self._resolve_db_password()
        return (
            f"postgresql://{self.DB_USER}:{password}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    def _resolve_db_password(self) -> str:
        if self.DB_SECRET_ARN:
            import json

            import boto3

            client = boto3.client("secretsmanager", region_name=self.AWS_REGION)
            secret = client.get_secret_value(SecretId=self.DB_SECRET_ARN)
            return json.loads(secret["SecretString"])["password"]
        return self.DB_PASSWORD


settings = Settings()
