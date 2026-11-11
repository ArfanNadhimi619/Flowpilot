from pydantic_settings import BaseSettings, SettingsConfigDict
class Settings(BaseSettings):
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    local_demo_mode: bool = False
    frontend_origins: str = "http://localhost:5173,http://localhost:5174,http://127.0.0.1:5173,http://127.0.0.1:5174"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    @property
    def origins(self): return [x.strip() for x in self.frontend_origins.split(",") if x.strip()]
settings = Settings()
