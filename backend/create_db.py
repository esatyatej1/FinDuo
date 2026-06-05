import asyncio
import asyncpg
import sys

async def create_db():
    try:
        conn = await asyncpg.connect(user='postgres', password='postgres', database='postgres', host='localhost')
        await conn.execute('CREATE DATABASE finduo')
        print("Database finduo created successfully.")
        await conn.close()
    except asyncpg.exceptions.DuplicateDatabaseError:
        print("Database finduo already exists.")
    except Exception as e:
        print(f"Failed to create database: {e}")
        sys.exit(1)

if __name__ == '__main__':
    asyncio.run(create_db())
