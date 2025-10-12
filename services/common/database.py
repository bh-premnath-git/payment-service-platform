"""
Shared database utilities (PostgreSQL)
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from typing import Generator


# Base class for all SQLAlchemy models
Base = declarative_base()


class DatabaseManager:
    """Database connection manager"""
    
    def __init__(self, database_url: str, pool_size: int = 10):
        self.engine = create_engine(
            database_url,
            pool_size=pool_size,
            pool_pre_ping=True,
        )
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
    
    def get_db(self) -> Generator:
        """Dependency for FastAPI to get DB session"""
        db = self.SessionLocal()
        try:
            yield db
        finally:
            db.close()
