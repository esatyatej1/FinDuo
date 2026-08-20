from pydantic import BaseModel
from typing import Optional, List

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class UserBase(BaseModel):
    username: str
    name: str
    monthly_income: float

class UserCreate(BaseModel):
    username: str
    name: str
    password: str
    monthly_income: float = 0.0

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    username: Optional[str] = None
    monthly_income: Optional[float] = None
    password: Optional[str] = None

class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

# --- Account Schemas ---
class AccountBase(BaseModel):
    account_type: str
    bank_name: str
    is_active: bool = True
    limit: float = 0.0
    balance_left: float = 0.0

class AccountCreate(AccountBase):
    user_id: int

class AccountUpdate(BaseModel):
    bank_name: Optional[str] = None
    is_active: Optional[bool] = None
    limit: Optional[float] = None
    balance_left: Optional[float] = None

class AccountResponse(AccountBase):
    id: int
    user_id: int
    class Config:
        from_attributes = True

# --- Loan Schemas ---
class LoanBase(BaseModel):
    loan_name: str
    emi_amount: float
    lender: str = ""
    notes: str = ""
    is_active: bool = True

class LoanCreate(LoanBase):
    user_id: int

class LoanUpdate(BaseModel):
    loan_name: Optional[str] = None
    emi_amount: Optional[float] = None
    lender: Optional[str] = None
    notes: Optional[str] = None
    is_active: Optional[bool] = None

class LoanResponse(LoanBase):
    id: int
    user_id: int
    class Config:
        from_attributes = True

# --- Category Schemas ---
class CategoryBase(BaseModel):
    name: str
    parent_id: Optional[int] = None
    icon: Optional[str] = "category"

class CategoryResponse(CategoryBase):
    id: int
    class Config:
        from_attributes = True

# --- Fixed Expense Schemas ---
class FixedExpenseBase(BaseModel):
    name: str
    amount: float
    is_variable: bool
    notes: Optional[str] = ""

class FixedExpenseUpdate(BaseModel):
    name: Optional[str] = None
    amount: Optional[float] = None
    is_variable: Optional[bool] = None
    notes: Optional[str] = None

class FixedExpenseResponse(FixedExpenseBase):
    id: int
    class Config:
        from_attributes = True

# --- Transaction Schemas ---
class TransactionCreate(BaseModel):
    amount: float
    title: str = ""
    notes: str = ""
    category_id: Optional[int] = None
    sub_category_id: Optional[int] = None
    payment_method: str = "UPI"
    account_ref: str = ""
    txn_date: str  # "YYYY-MM-DD"
    txn_ref: str = ""   # UPI ref for dedup
    source: str = "manual"  # manual | sms | gmail | auto_sms | auto_gmail | auto_phonepe
    is_pending_review: bool = False
    txn_type: str = "sent"

class TransactionUpdate(BaseModel):
    amount: Optional[float] = None
    title: Optional[str] = None
    notes: Optional[str] = None
    category_id: Optional[int] = None
    sub_category_id: Optional[int] = None
    payment_method: Optional[str] = None
    account_ref: Optional[str] = None
    txn_date: Optional[str] = None
    txn_ref: Optional[str] = None
    source: Optional[str] = None
    is_pending_review: Optional[bool] = None
    txn_type: Optional[str] = None

class TransactionResponse(TransactionCreate):
    id: int
    user_id: int
    class Config:
        from_attributes = True

class BulkImportRequest(BaseModel):
    transactions: List[TransactionCreate]
    skip_duplicates: bool = True

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]

class ChatResponse(BaseModel):
    response: str

# --- User Settings Schemas ---
class UserSettingsBase(BaseModel):
    is_dark_mode: bool = True
    theme_color: str = "0xFF00BCD4"
    selected_font: str = "Inter"
    currency: str = "₹"

class UserSettingsUpdate(BaseModel):
    is_dark_mode: Optional[bool] = None
    theme_color: Optional[str] = None
    selected_font: Optional[str] = None
    currency: Optional[str] = None

class UserSettingsResponse(UserSettingsBase):
    id: int
    user_id: int
    class Config:
        from_attributes = True
