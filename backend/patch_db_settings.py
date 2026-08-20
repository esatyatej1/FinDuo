import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:postgres@localhost:5432/finduo')
    try:
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS user_settings (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE UNIQUE,
                is_dark_mode BOOLEAN DEFAULT TRUE,
                theme_color VARCHAR DEFAULT '0xFF00BCD4',
                selected_font VARCHAR DEFAULT 'Inter',
                currency VARCHAR DEFAULT '₹'
            )
        ''')
        await conn.execute('''
            ALTER TABLE user_settings ADD COLUMN IF NOT EXISTS currency VARCHAR DEFAULT '₹';
        ''')
        print("Table user_settings created successfully!")
    except Exception as e:
        print("Error:", e)
    finally:
        await conn.close()

asyncio.run(main())
