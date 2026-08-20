import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:postgres@localhost:5432/finduo')
    try:
        await conn.execute('ALTER TABLE transactions ADD COLUMN is_pending_review BOOLEAN DEFAULT FALSE')
        print("Column added successfully!")
    except Exception as e:
        print("Error:", e)
    finally:
        await conn.close()

asyncio.run(main())
