"""App-wide configuration management.

Uses pydantic-settings so values can be safely defaulted locally and
transparently overridden by Docker Compose env vars or an AWS Fargate
task definition's environment/secrets injection.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Runtime environment: "local" | "staging" | "production"
    ENVIRONMENT: str = "local"

    # Discrete database connection components (used in production / Fargate).
    DB_HOST: str = "db"
    DB_USER: str = "postgres"
    DB_PASSWORD: str = "local_secure_password123"
    DB_NAME: str = "b2b_monolith_dev"
    DB_PORT: int = 5432

    # Security
    JWT_SECRET_KEY: str = "local_development_only_secret_key_987654321"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24

    # Full DSN. When provided (e.g. local docker-compose), it wins outright.
    DATABASE_URL: str | None = None

    # AWS / messaging
    AWS_REGION: str = "eu-west-2"
    NOTIFICATIONS_QUEUE_URL: str | None = None

    # When set (e.g. the consumer Lambda, which has no ECS-style secret
    # injection), the DB password is fetched from this Secrets Manager secret
    # at connect time. ECS injects DB_PASSWORD directly and leaves this unset.
    DB_SECRET_ARN: str | None = None

    @property
    def db_url(self) -> str:
        """Resolve the SQLAlchemy connection string.

        If DATABASE_URL is injected directly we use it verbatim, otherwise we
        compile the discrete components into a standard PostgreSQL DSN, sourcing
        the password from Secrets Manager when DB_SECRET_ARN is set.
        """
        if self.DATABASE_URL:
            return self.DATABASE_URL
        password = self._resolve_db_password()
        return (
            f"postgresql://{self.DB_USER}:{password}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    def _resolve_db_password(self) -> str:
        """Return the DB password.

        ECS injects DB_PASSWORD from Secrets Manager via the task definition, so
        it is already present in the environment. AWS Lambda has no equivalent
        secret injection, so when DB_SECRET_ARN is provided we fetch the
        RDS-managed secret (a JSON blob with username/password) at runtime.
        """
        if self.DB_SECRET_ARN:
            import json
            import boto3

            client = boto3.client("secretsmanager", region_name=self.AWS_REGION)
            secret = client.get_secret_value(SecretId=self.DB_SECRET_ARN)
            return json.loads(secret["SecretString"])["password"]
        return self.DB_PASSWORD


settings = Settings()
