import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from passlib.context import CryptContext
from models import Base, User, Account, Loan, FixedExpense, Category
from database import DATABASE_URL, engine

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password):
    return pwd_context.hash(password)

async def seed():
    async with engine.begin() as conn:
        print("Dropping and recreating tables...")
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
        print("Tables created.")

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        # 1. Create Users
        satya = User(
            name="Satya Enumula",
            username="satya",
            password_hash=get_password_hash("Admin@123#"),
            monthly_income=0.0 # Editable via Admin portal
        )
        teja = User(
            name="Teja Sanivarapu",
            username="teja",
            password_hash=get_password_hash("Admin@123#"),
            monthly_income=0.0 # Editable via Admin portal
        )
        session.add_all([satya, teja])
        await session.flush() # flush to get IDs

        # 2. Add Accounts & Loans for Satya
        satya_accounts = [
            Account(user_id=satya.id, account_type="Bank", bank_name="Axis Bank", is_active=True),
            Account(user_id=satya.id, account_type="Bank", bank_name="SBI", is_active=False),
            Account(user_id=satya.id, account_type="Credit Card", bank_name="Axis Bank", limit=37000.0, balance_left=0.0)
        ]
        satya_loans = [
            Loan(user_id=satya.id, loan_name="House Loan EMI HDFC Bank", emi_amount=2600.0),
            Loan(user_id=satya.id, loan_name="Personal Axis Bank Loan EMI", emi_amount=5000.0),
            Loan(user_id=satya.id, loan_name="Harish Oneplus 15 Mobile EMI", emi_amount=13334.0)
        ]

        # 3. Add Accounts & Loans for Teja
        teja_accounts = [
            Account(user_id=teja.id, account_type="Bank", bank_name="Axis Bank", is_active=True),
            Account(user_id=teja.id, account_type="Bank", bank_name="SBI", is_active=False),
            Account(user_id=teja.id, account_type="Credit Card", bank_name="Axis Bank", limit=47000.0, balance_left=0.0),
            Account(user_id=teja.id, account_type="Credit Card", bank_name="One Card", limit=55999.0, balance_left=55999.0),
            Account(user_id=teja.id, account_type="Credit Card", bank_name="SBI", limit=79000.0, balance_left=0.0)
        ]
        teja_loans = [
            Loan(user_id=teja.id, loan_name="Axis Personal Loan EMI", emi_amount=33000.0)
        ]

        session.add_all(satya_accounts + satya_loans + teja_accounts + teja_loans)

        # 4. Add Fixed Expenses
        fixed_expenses = [
            FixedExpense(name="House Rent", amount=32000.0, is_variable=False),
            FixedExpense(name="Airtel Monthly Bill", amount=2850.0, is_variable=False),
            FixedExpense(name="Act Monthly Bill", amount=1950.0, is_variable=False),
            FixedExpense(name="Electricity Bill", amount=3000.0, is_variable=True) # approx changes every month
        ]
        session.add_all(fixed_expenses)

        # 5. Add Categories
        category_tree = {
            "Food": ["Zomato", "Swiggy"],
            "Online order": ["Blink it", "Instamart", "Zepto"],
            "Online store": ["Amazon", "Flipkart"],
            "NonVeg Raw items": ["Chicken", "Mutton", "Prawns", "Fish"],
            "Food Raw items": ["Vegetables", "Fruits"],
            "Restaurants": ["Café’s", "Restaurants", "Others"],
            "Fuel": ["Car Fuel", "Bike Fuel KTM 390 Duke", "Bike Fuel KTM 390 RC", "Bike Fuel Yamaha FZS"],
            "Gas Cylinder": []
        }

        for main_cat_name, sub_cats in category_tree.items():
            main_cat = Category(name=main_cat_name)
            session.add(main_cat)
            await session.flush()
            
            for sub_cat_name in sub_cats:
                sub_cat = Category(name=sub_cat_name, parent_id=main_cat.id)
                session.add(sub_cat)

        await session.commit()
        print("Database seeded successfully with all initial records!")

if __name__ == "__main__":
    asyncio.run(seed())
