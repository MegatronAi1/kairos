"""Environment-driven settings. No secrets in code."""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="KAIROS_", env_file=".env", extra="ignore")

    api_token: str = ""
    cors_origins: str = "http://localhost:5173"  # comma-separated
    artifacts_dir: Path = Path("artifacts")
    data_dir: Path = Path("data")
    scenario: str = "investor_demo"

    aws_region: str = Field("us-east-1", validation_alias="AWS_REGION")
    # Named profile in ~/.aws/credentials (local laptop). Empty: default chain / instance role.
    aws_profile: str = Field("", validation_alias="AWS_PROFILE")
    model_chat: str = ""
    model_fast: str = ""
    bedrock_max_rps: float = 0.8

    tick_hz: float = 2.0
    default_speed_h_per_s: float = 1.0
    local_shap_every_n_ticks: int = 10


    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
