import os

class Config:
    """Database configuration"""
    DB_USER = os.getenv('DB_USER', 'SYSTEM')
    DB_PASSWORD = os.getenv('DB_PASSWORD', 'Password123')
    DB_HOST = os.getenv('DB_HOST', 'localhost')
    DB_PORT = os.getenv('DB_PORT', '1521')
    DB_SERVICE = os.getenv('DB_SERVICE', 'XEPDB1')
    
    @staticmethod
    def get_dsn():
        """Returns the DSN string for Oracle connection"""
        return f"{Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_SERVICE}"
