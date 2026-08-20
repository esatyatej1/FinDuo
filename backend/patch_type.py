import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:postgres@localhost:5432/finduo')
    try:
        await conn.execute("ALTER TABLE transactions ADD COLUMN txn_type VARCHAR DEFAULT 'sent'")
        print("Column added successfully!")
    except Exception as e:
        print("Error:", e)
    finally:
        await conn.close()

asyncio.run(main())
