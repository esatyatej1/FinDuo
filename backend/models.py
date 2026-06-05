from sqlalchemy import Column, Integer, String, Float, ForeignKey, Boolean, Text
from sqlalchemy.orm import relationship
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    username = Column(String, unique=True, index=True)
    password_hash = Column(String)
    monthly_income = Column(Float, default=0.0)

    accounts = relationship("Account", back_populates="user", cascade="all, delete-orphan")
    loans = relationship("Loan", back_populates="user", cascade="all, delete-orphan")

class Account(Base):
    __tablename__ = "accounts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    account_type = Column(String)  # 'Bank' or 'Credit Card'
    bank_name = Column(String)
    is_active = Column(Boolean, default=True)  # Active/Passive for banks
    
    # For Credit Cards
    limit = Column(Float, default=0.0)
    balance_left = Column(Float, default=0.0)

    user = relationship("User", back_populates="accounts")

class Loan(Base):
    __tablename__ = "loans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    loan_name = Column(String)
    emi_amount = Column(Float)
    lender = Column(String, default="")
    notes = Column(Text, default="")
    is_active = Column(Boolean, default=True)

    user = relationship("User", back_populates="loans")

class FixedExpense(Base):
    __tablename__ = "fixed_expenses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    amount = Column(Float)
    is_variable = Column(Boolean, default=False)  # e.g. Electricity changes every month
    notes = Column(Text, default="")

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    icon = Column(String, default="category")  # Material icon name hint
    parent_id = Column(Integer, ForeignKey("categories.id"), nullable=True)

    parent = relationship("Category", remote_side=[id], backref="subcategories")

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    amount = Column(Float, nullable=False)
    title = Column(String, default="")          # short description
    notes = Column(Text, default="")            # optional detail
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    sub_category_id = Column(Integer, ForeignKey("categories.id", ondelete="SET NULL"), nullable=True)
    payment_method = Column(String, default="UPI")  # UPI | Cash | Credit Card | Debit Card
    account_ref = Column(String, default="")    # e.g. "Axis Credit Card"
    txn_date = Column(String, nullable=False)   # ISO date string "YYYY-MM-DD"
    txn_ref = Column(String, default="")        # UPI ref / dedup key — prevents double import
    source = Column(String, default="manual")   # manual | sms | gmail | auto_sms | auto_gmail

    user = relationship("User", foreign_keys=[user_id])
