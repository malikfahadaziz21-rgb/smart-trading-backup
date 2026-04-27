import os
import sys
from sqlalchemy import text
from dotenv import load_dotenv

# Add the project root to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.db.database import engine

load_dotenv()

def add_columns():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT FALSE;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS daily_used INTEGER DEFAULT 0;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS last_used_date DATE;"))
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS stripe_customer_id VARCHAR(255);"))
            conn.commit()
            print("Successfully added columns to users table.")
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    add_columns()
