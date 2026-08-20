from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional

from database import get_db, engine, Base
import models
import schemas
from auth import verify_password, create_access_token, oauth2_scheme, ALGORITHM, SECRET_KEY
from jose import jwt, JWTError

app = FastAPI(title="FinDuo API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────
# Auth & User
# ─────────────────────────────────────────
async def get_current_user(token: str = Depends(oauth2_scheme), db: AsyncSession = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    result = await db.execute(select(models.User).where(models.User.username == username))
    user = result.scalars().first()
    if user is None:
        raise credentials_exception
    return user

@app.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(models.User).where(models.User.username == form_data.username))
    user = result.scalars().first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

import httpx
import uuid
from auth import get_password_hash

@app.post("/auth/google", response_model=schemas.Token)
async def google_auth(request: dict, db: AsyncSession = Depends(get_db)):
    id_token = request.get("id_token")
    if not id_token:
        raise HTTPException(status_code=400, detail="id_token missing")
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"https://oauth2.googleapis.com/tokeninfo?id_token={id_token}")
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid Google token")
        
        data = resp.json()
        email = data.get("email")
        name = data.get("name")
        if not email:
            raise HTTPException(status_code=400, detail="Email not provided by Google")
            
    # Check if user exists
    result = await db.execute(select(models.User).where(models.User.username == email))
    user = result.scalars().first()
    
    if not user:
        # Create user
        random_pwd = str(uuid.uuid4())
        user = models.User(
            username=email,
            name=name or email.split("@")[0],
            password_hash=get_password_hash(random_pwd),
            monthly_income=0.0
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=schemas.UserResponse)
async def read_users_me(current_user: models.User = Depends(get_current_user)):
    return current_user

@app.put("/users/me/income", response_model=schemas.UserResponse)
async def update_my_income(income: float, current_user: models.User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    current_user.monthly_income = income
    await db.commit()
    await db.refresh(current_user)
    return current_user

@app.get("/users", response_model=List[schemas.UserResponse])
async def get_all_users(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.User))
    return result.scalars().all()

@app.post("/users", response_model=schemas.UserResponse)
async def create_user(data: schemas.UserCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Check if username already exists
    existing = await db.execute(select(models.User).where(models.User.username == data.username))
    if existing.scalars().first():
        raise HTTPException(status_code=400, detail="Username already exists")
    new_user = models.User(
        name=data.name,
        username=data.username,
        password_hash=get_password_hash(data.password),
        monthly_income=data.monthly_income,
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@app.put("/users/me", response_model=schemas.UserResponse)
async def update_my_profile(data: schemas.UserProfileUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    update_data = data.dict(exclude_unset=True)
    if 'password' in update_data:
        current_user.password_hash = get_password_hash(update_data.pop('password'))
    for key, val in update_data.items():
        setattr(current_user, key, val)
    await db.commit()
    await db.refresh(current_user)
    return current_user

@app.put("/users/{user_id}", response_model=schemas.UserResponse)
async def update_user(user_id: int, data: schemas.UserProfileUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.User).where(models.User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    update_data = data.dict(exclude_unset=True)
    if 'password' in update_data:
        user.password_hash = get_password_hash(update_data.pop('password'))
    for key, val in update_data.items():
        setattr(user, key, val)
    await db.commit()
    await db.refresh(user)
    return user

@app.delete("/users/{user_id}")
async def delete_user(user_id: int, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    result = await db.execute(select(models.User).where(models.User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    await db.delete(user)
    await db.commit()
    return {"status": "deleted"}

@app.put("/users/{user_id}/income", response_model=schemas.UserResponse)
async def update_user_income(user_id: int, income: float, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.User).where(models.User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.monthly_income = income
    await db.commit()
    await db.refresh(user)
    return user

# ─────────────────────────────────────────
# Settings
# ─────────────────────────────────────────
@app.get("/users/me/settings", response_model=schemas.UserSettingsResponse)
async def get_my_settings(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.UserSettings).where(models.UserSettings.user_id == current_user.id))
    settings = result.scalars().first()
    if not settings:
        settings = models.UserSettings(user_id=current_user.id)
        db.add(settings)
        await db.commit()
        await db.refresh(settings)
    return settings

@app.put("/users/me/settings", response_model=schemas.UserSettingsResponse)
async def update_my_settings(data: schemas.UserSettingsUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.UserSettings).where(models.UserSettings.user_id == current_user.id))
    settings = result.scalars().first()
    if not settings:
        settings = models.UserSettings(user_id=current_user.id)
        db.add(settings)
        
    update_data = data.dict(exclude_unset=True)
    for key, val in update_data.items():
        setattr(settings, key, val)
        
    await db.commit()
    await db.refresh(settings)
    return settings

# ─────────────────────────────────────────
# Accounts
# ─────────────────────────────────────────
@app.get("/accounts", response_model=List[dict])
async def get_my_accounts(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
    accounts = result.scalars().all()
    return [{"id": a.id, "user_id": a.user_id, "bank_name": a.bank_name, "type": a.account_type,
             "is_active": a.is_active, "limit": a.limit, "balance_left": a.balance_left} for a in accounts]

@app.get("/accounts/all", response_model=List[dict])
async def get_all_accounts(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Account))
    accounts = result.scalars().all()
    return [{"id": a.id, "user_id": a.user_id, "bank_name": a.bank_name, "type": a.account_type,
             "is_active": a.is_active, "limit": a.limit, "balance_left": a.balance_left} for a in accounts]

@app.post("/accounts", response_model=dict)
async def create_account(account: schemas.AccountCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_acc = models.Account(**account.dict())
    db.add(new_acc)
    await db.commit()
    await db.refresh(new_acc)
    return {"id": new_acc.id, "user_id": new_acc.user_id, "bank_name": new_acc.bank_name,
            "type": new_acc.account_type, "is_active": new_acc.is_active,
            "limit": new_acc.limit, "balance_left": new_acc.balance_left}

@app.put("/accounts/{account_id}", response_model=dict)
async def update_account(account_id: int, data: schemas.AccountUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Account).where(models.Account.id == account_id))
    acc = result.scalars().first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")
    update_data = data.dict(exclude_unset=True)
    for key, val in update_data.items():
        setattr(acc, key, val)
    await db.commit()
    await db.refresh(acc)
    return {"id": acc.id, "user_id": acc.user_id, "bank_name": acc.bank_name,
            "type": acc.account_type, "is_active": acc.is_active,
            "limit": acc.limit, "balance_left": acc.balance_left}

@app.delete("/accounts/{account_id}")
async def delete_account(account_id: int, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Account).where(models.Account.id == account_id))
    acc = result.scalars().first()
    if not acc:
        raise HTTPException(status_code=404, detail="Account not found")
    await db.delete(acc)
    await db.commit()
    return {"status": "deleted"}

# ─────────────────────────────────────────
# Loans
# ─────────────────────────────────────────
@app.get("/loans", response_model=List[dict])
async def get_my_loans(
    active_only: bool = True,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    query = select(models.Loan).where(models.Loan.user_id == current_user.id)
    if active_only:
        query = query.where(models.Loan.is_active == True)
    result = await db.execute(query)
    loans = result.scalars().all()
    return [{"id": l.id, "user_id": l.user_id, "name": l.loan_name, "emi": l.emi_amount,
             "lender": l.lender, "notes": l.notes, "is_active": l.is_active} for l in loans]

@app.get("/loans/all", response_model=List[dict])
async def get_all_loans(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Loan))
    loans = result.scalars().all()
    return [{"id": l.id, "user_id": l.user_id, "name": l.loan_name, "emi": l.emi_amount,
             "lender": l.lender, "notes": l.notes, "is_active": l.is_active} for l in loans]

@app.post("/loans", response_model=dict)
async def create_loan(loan: schemas.LoanCreate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_loan = models.Loan(**loan.dict())
    db.add(new_loan)
    await db.commit()
    await db.refresh(new_loan)
    return {"id": new_loan.id, "user_id": new_loan.user_id, "name": new_loan.loan_name,
            "emi": new_loan.emi_amount, "lender": new_loan.lender, "notes": new_loan.notes, "is_active": new_loan.is_active}

@app.put("/loans/{loan_id}", response_model=dict)
async def update_loan(loan_id: int, data: schemas.LoanUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Loan).where(models.Loan.id == loan_id))
    loan = result.scalars().first()
    if not loan:
        raise HTTPException(status_code=404, detail="Loan not found")
    update_data = data.dict(exclude_unset=True)
    for key, val in update_data.items():
        setattr(loan, key, val)
    await db.commit()
    await db.refresh(loan)
    return {"id": loan.id, "user_id": loan.user_id, "name": loan.loan_name,
            "emi": loan.emi_amount, "lender": loan.lender, "notes": loan.notes, "is_active": loan.is_active}

@app.delete("/loans/{loan_id}")
async def delete_loan(loan_id: int, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Loan).where(models.Loan.id == loan_id))
    loan = result.scalars().first()
    if not loan:
        raise HTTPException(status_code=404, detail="Loan not found")
    await db.delete(loan)
    await db.commit()
    return {"status": "deleted"}

# ─────────────────────────────────────────
# Fixed Expenses
# ─────────────────────────────────────────
@app.get("/expenses", response_model=List[schemas.FixedExpenseResponse])
async def get_expenses(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.FixedExpense))
    return result.scalars().all()

@app.post("/expenses", response_model=schemas.FixedExpenseResponse)
async def create_expense(expense: schemas.FixedExpenseBase, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_exp = models.FixedExpense(**expense.dict())
    db.add(new_exp)
    await db.commit()
    await db.refresh(new_exp)
    return new_exp

@app.put("/expenses/{expense_id}", response_model=schemas.FixedExpenseResponse)
async def update_expense(expense_id: int, data: schemas.FixedExpenseUpdate, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.FixedExpense).where(models.FixedExpense.id == expense_id))
    exp = result.scalars().first()
    if not exp:
        raise HTTPException(status_code=404, detail="Expense not found")
    update_data = data.dict(exclude_unset=True)
    for key, val in update_data.items():
        setattr(exp, key, val)
    await db.commit()
    await db.refresh(exp)
    return exp

@app.delete("/expenses/{expense_id}")
async def delete_expense(expense_id: int, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.FixedExpense).where(models.FixedExpense.id == expense_id))
    exp = result.scalars().first()
    if not exp:
        raise HTTPException(status_code=404, detail="Expense not found")
    await db.delete(exp)
    await db.commit()
    return {"status": "deleted"}

# ─────────────────────────────────────────
# Categories
# ─────────────────────────────────────────
@app.get("/categories", response_model=List[schemas.CategoryResponse])
async def get_categories(db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Category))
    return result.scalars().all()

@app.post("/categories", response_model=schemas.CategoryResponse)
async def create_category(category: schemas.CategoryBase, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    new_cat = models.Category(**category.dict())
    db.add(new_cat)
    await db.commit()
    await db.refresh(new_cat)
    return new_cat

@app.put("/categories/{category_id}", response_model=schemas.CategoryResponse)
async def update_category(category_id: int, category: schemas.CategoryBase, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Category).where(models.Category.id == category_id))
    cat = result.scalars().first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    update_data = category.dict(exclude_unset=True)
    for key, val in update_data.items():
        setattr(cat, key, val)
    await db.commit()
    await db.refresh(cat)
    return cat

@app.delete("/categories/{category_id}")
async def delete_category(category_id: int, db: AsyncSession = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    result = await db.execute(select(models.Category).where(models.Category.id == category_id))
    cat = result.scalars().first()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    await db.delete(cat)
    await db.commit()
    return {"status": "deleted"}

# ─────────────────────────────────────────
# Transactions
# ─────────────────────────────────────────
@app.get("/transactions", response_model=List[schemas.TransactionResponse])
async def get_transactions(
    month: Optional[str] = None,   # "YYYY-MM" filter
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    query = select(models.Transaction).where(models.Transaction.user_id == current_user.id)
    if month:
        query = query.where(models.Transaction.txn_date.like(f"{month}%"))
    query = query.order_by(models.Transaction.txn_date.desc())
    result = await db.execute(query)
    return result.scalars().all()

@app.get("/transactions/summary")
async def get_transaction_summary(
    month: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns total spend and per-category breakdown for the month."""
    query = select(models.Transaction).where(models.Transaction.user_id == current_user.id)
    if month:
        query = query.where(models.Transaction.txn_date.like(f"{month}%"))
    result = await db.execute(query)
    txns = result.scalars().all()

    def is_received(t):
        return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))

    total = sum(t.amount for t in txns if not is_received(t))
    total_received = sum(t.amount for t in txns if is_received(t))
    by_category: dict = {}
    for t in txns:
        if not is_received(t):
            cat_id = t.category_id
            key = str(cat_id) if cat_id else "uncategorized"
            by_category[key] = by_category.get(key, 0) + t.amount

    by_method: dict = {}
    for t in txns:
        by_method[t.payment_method] = by_method.get(t.payment_method, 0) + t.amount

    return {
        "total": total,
        "total_received": total_received,
        "count": len(txns),
        "by_category": by_category,
        "by_method": by_method,
    }

@app.post("/transactions", response_model=schemas.TransactionResponse)
async def create_transaction(
    txn: schemas.TransactionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    new_txn = models.Transaction(**txn.dict(), user_id=current_user.id)
    db.add(new_txn)
    
    if txn.account_ref:
        acc_result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
        accounts = acc_result.scalars().all()
        for acc in accounts:
            if acc.bank_name in txn.account_ref:
                if txn.txn_type == "sent":
                    acc.balance_left -= txn.amount
                elif txn.txn_type == "received":
                    acc.balance_left += txn.amount
                break

    await db.commit()
    await db.refresh(new_txn)
    return new_txn

@app.put("/transactions/{txn_id}", response_model=schemas.TransactionResponse)
async def update_transaction(
    txn_id: int,
    data: schemas.TransactionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    result = await db.execute(
        select(models.Transaction).where(
            models.Transaction.id == txn_id,
            models.Transaction.user_id == current_user.id
        )
    )
    txn = result.scalars().first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
        
    if txn.account_ref:
        acc_result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
        accounts = acc_result.scalars().all()
        for acc in accounts:
            if acc.bank_name in txn.account_ref:
                if txn.txn_type == "sent":
                    acc.balance_left += txn.amount
                elif txn.txn_type == "received":
                    acc.balance_left -= txn.amount
                break

    for key, val in data.dict(exclude_unset=True).items():
        setattr(txn, key, val)
        
    if txn.account_ref:
        acc_result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
        accounts = acc_result.scalars().all()
        for acc in accounts:
            if acc.bank_name in txn.account_ref:
                if txn.txn_type == "sent":
                    acc.balance_left -= txn.amount
                elif txn.txn_type == "received":
                    acc.balance_left += txn.amount
                break

    await db.commit()
    await db.refresh(txn)
    return txn

@app.delete("/transactions/{txn_id}")
async def delete_transaction(
    txn_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    result = await db.execute(
        select(models.Transaction).where(
            models.Transaction.id == txn_id,
            models.Transaction.user_id == current_user.id
        )
    )
    txn = result.scalars().first()
    if not txn:
        raise HTTPException(status_code=404, detail="Transaction not found")
        
    if txn.account_ref:
        acc_result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
        accounts = acc_result.scalars().all()
        for acc in accounts:
            if acc.bank_name in txn.account_ref:
                if txn.txn_type == "sent":
                    acc.balance_left += txn.amount
                elif txn.txn_type == "received":
                    acc.balance_left -= txn.amount
                break
                
    await db.delete(txn)
    await db.commit()
    return {"status": "deleted"}

# ─────────────────────────────────────────
# Bulk Import (SMS + Gmail, with dedup)
# ─────────────────────────────────────────
@app.post("/transactions/bulk")
async def bulk_import_transactions(
    payload: schemas.BulkImportRequest,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Bulk import with smart deduplication.
    Dedup strategy:
      1. If txn_ref is provided → check exact ref match
      2. Else → check same amount + same date (fuzzy dedup)
    """
    imported = 0
    skipped = 0
    for t in payload.transactions:
        if payload.skip_duplicates:
            # Primary: dedup by ref number
            if t.txn_ref:
                exists = await db.execute(
                    select(models.Transaction).where(
                        models.Transaction.user_id == current_user.id,
                        models.Transaction.txn_ref == t.txn_ref,
                        models.Transaction.txn_ref != ""
                    )
                )
                if exists.scalars().first():
                    skipped += 1
                    continue
            else:
                # Fallback: same amount + same date
                exists = await db.execute(
                    select(models.Transaction).where(
                        models.Transaction.user_id == current_user.id,
                        models.Transaction.amount == t.amount,
                        models.Transaction.txn_date == t.txn_date,
                    )
                )
                if exists.scalars().first():
                    skipped += 1
                    continue

        new_txn = models.Transaction(**t.dict(), user_id=current_user.id)
        db.add(new_txn)
        imported += 1

    await db.commit()
    return {"imported": imported, "skipped": skipped}

# ─────────────────────────────────────────
# AI Chat
# ─────────────────────────────────────────
@app.post("/ai/chat", response_model=schemas.ChatResponse)
async def chat_with_ai(
    payload: schemas.ChatRequest,
    current_user: models.User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    from cerebras_manager import cerebras_manager
    import json
    
    # Fetch user data context
    accounts_res = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
    accounts = [{"bank_name": a.bank_name, "type": a.account_type, "limit": a.limit, "balance": a.balance_left} for a in accounts_res.scalars().all()]

    loans_res = await db.execute(select(models.Loan).where(models.Loan.user_id == current_user.id))
    loans = [{"name": l.loan_name, "emi": l.emi_amount, "lender": l.lender} for l in loans_res.scalars().all()]
    
    expenses_res = await db.execute(select(models.FixedExpense))
    expenses = [{"name": e.name, "amount": e.amount} for e in expenses_res.scalars().all()]

    txns_res = await db.execute(select(models.Transaction).where(models.Transaction.user_id == current_user.id).order_by(models.Transaction.txn_date.desc()).limit(30))
    txns = [{"date": t.txn_date, "amount": t.amount, "title": t.title, "method": t.payment_method} for t in txns_res.scalars().all()]
    
    user_context = {
        "monthly_income": current_user.monthly_income,
        "accounts": accounts,
        "loans": loans,
        "fixed_expenses": expenses,
        "recent_transactions": txns
    }
    
    system_prompt = (
        "You are FinDuo Assist, an advanced AI assistant built into the FinDuo platform. "
        "IMPORTANT INSTRUCTION: You have been granted explicit permission and access by the user to view and analyze their personal banking and financial data. "
        f"Here is the user's current financial data context (in JSON format): {json.dumps(user_context)}\n"
        "You MUST use this provided data to answer the user's questions about their finances, balances, spending, loans, and accounts. "
        "Do not say you don't have access. The data is provided to you above. "
        "Be helpful, direct, and provide the exact numbers from the JSON."
    )

    messages = [{"role": msg.role, "content": msg.content} for msg in payload.messages]
    
    # Prepend or update system message
    system_msg_idx = next((i for i, msg in enumerate(messages) if msg["role"] == "system"), -1)
    if system_msg_idx == -1:
        messages.insert(0, {
            "role": "system",
            "content": system_prompt
        })
    else:
        messages[system_msg_idx]["content"] = system_prompt + "\n\n" + messages[system_msg_idx]["content"]
        
    try:
        response_content = await cerebras_manager.generate_chat_response(messages)
        return {"response": response_content}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error communicating with AI service: {str(e)}")


# ─────────────────────────────────────────
# Analytics
# ─────────────────────────────────────────
@app.get("/analytics/monthly")
async def get_monthly_analytics(
    months: int = 6,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns per-month spending totals for the last N months."""
    from datetime import datetime, timedelta
    now = datetime.now()
    result_data = []

    for i in range(months - 1, -1, -1):
        # Build month string
        target = datetime(now.year, now.month, 1) - timedelta(days=i * 28)
        month_str = f"{target.year}-{str(target.month).zfill(2)}"

        query = select(models.Transaction).where(
            models.Transaction.user_id == current_user.id,
            models.Transaction.txn_date.like(f"{month_str}%")
        )
        res = await db.execute(query)
        txns = res.scalars().all()
        def is_received(t):
            return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))
            
        total = sum(t.amount for t in txns if not is_received(t))
        total_received = sum(t.amount for t in txns if is_received(t))
        count = len(txns)

        # Category breakdown for this month
        by_cat: dict = {}
        for t in txns:
            if not is_received(t):
                key = str(t.category_id) if t.category_id else "uncategorized"
                by_cat[key] = by_cat.get(key, 0) + t.amount

        result_data.append({
            "month": month_str,
            "total": total,
            "total_received": total_received,
            "count": count,
            "by_category": by_cat,
        })

    return result_data


@app.get("/analytics/daily-spending")
async def get_daily_spending(
    month: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns per-day spending totals for the given month (sparkline data)."""
    from datetime import datetime
    if not month:
        now = datetime.now()
        month = f"{now.year}-{str(now.month).zfill(2)}"

    query = select(models.Transaction).where(
        models.Transaction.user_id == current_user.id,
        models.Transaction.txn_date.like(f"{month}%")
    )
    res = await db.execute(query)
    txns = res.scalars().all()
    
    def is_received(t):
        return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))

    daily: dict = {}
    daily_received: dict = {}
    for t in txns:
        day = t.txn_date[:10] if len(t.txn_date) >= 10 else t.txn_date
        if is_received(t):
            daily_received[day] = daily_received.get(day, 0) + t.amount
        else:
            daily[day] = daily.get(day, 0) + t.amount

    # Build all days in month
    parts = month.split("-")
    year, mon = int(parts[0]), int(parts[1])
    import calendar
    num_days = calendar.monthrange(year, mon)[1]
    now = datetime.now()
    max_day = min(num_days, now.day if year == now.year and mon == now.month else num_days)

    result = []
    for d in range(1, max_day + 1):
        day_str = f"{month}-{str(d).zfill(2)}"
        result.append({
            "date": day_str,
            "spent": daily.get(day_str, 0),
            "received": daily_received.get(day_str, 0),
        })

    return result


@app.get("/analytics/spending-velocity")
async def get_spending_velocity(
    month: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns spending velocity metrics: avg per day, projected month total, streak data."""
    from datetime import datetime
    import calendar
    now = datetime.now()
    if not month:
        month = f"{now.year}-{str(now.month).zfill(2)}"

    query = select(models.Transaction).where(
        models.Transaction.user_id == current_user.id,
        models.Transaction.txn_date.like(f"{month}%")
    )
    res = await db.execute(query)
    txns = res.scalars().all()

    def is_received(t):
        return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))

    total_spent = sum(t.amount for t in txns if not is_received(t))
    total_received = sum(t.amount for t in txns if is_received(t))
    sent_count = sum(1 for t in txns if not is_received(t))
    recv_count = sum(1 for t in txns if is_received(t))

    parts = month.split("-")
    year, mon = int(parts[0]), int(parts[1])
    total_days = calendar.monthrange(year, mon)[1]
    
    # Days elapsed so far
    if year == now.year and mon == now.month:
        days_elapsed = now.day
    else:
        days_elapsed = total_days

    avg_per_day = total_spent / max(days_elapsed, 1)
    projected_total = avg_per_day * total_days
    
    # Today's spending
    today_str = now.strftime("%Y-%m-%d")
    today_spent = sum(t.amount for t in txns if not is_received(t) and t.txn_date[:10] == today_str)
    today_received = sum(t.amount for t in txns if is_received(t) and t.txn_date[:10] == today_str)
    today_count = sum(1 for t in txns if t.txn_date[:10] == today_str)

    # Find highest spending day
    daily: dict = {}
    for t in txns:
        if not is_received(t):
            day = t.txn_date[:10]
            daily[day] = daily.get(day, 0) + t.amount
    highest_day = max(daily.items(), key=lambda x: x[1]) if daily else (None, 0)
    
    # Avg transaction amount
    avg_txn = total_spent / max(sent_count, 1)

    return {
        "total_spent": total_spent,
        "total_received": total_received,
        "sent_count": sent_count,
        "received_count": recv_count,
        "days_elapsed": days_elapsed,
        "total_days": total_days,
        "avg_per_day": round(avg_per_day, 2),
        "projected_total": round(projected_total, 2),
        "today_spent": today_spent,
        "today_received": today_received,
        "today_count": today_count,
        "highest_day": highest_day[0],
        "highest_day_amount": highest_day[1],
        "avg_transaction": round(avg_txn, 2),
    }


@app.get("/analytics/account-flow")
async def get_account_flow(
    month: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns per-account inflow/outflow for the month."""
    from datetime import datetime
    now = datetime.now()
    if not month:
        month = f"{now.year}-{str(now.month).zfill(2)}"

    # Get user accounts
    acc_result = await db.execute(select(models.Account).where(models.Account.user_id == current_user.id))
    accounts = acc_result.scalars().all()

    # Get transactions
    query = select(models.Transaction).where(
        models.Transaction.user_id == current_user.id,
        models.Transaction.txn_date.like(f"{month}%")
    )
    res = await db.execute(query)
    txns = res.scalars().all()

    def is_received(t):
        return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))

    # Group by payment method
    method_flow: dict = {}
    for t in txns:
        m = t.payment_method or "UPI"
        if m not in method_flow:
            method_flow[m] = {"outflow": 0, "inflow": 0, "count": 0}
        if is_received(t):
            method_flow[m]["inflow"] += t.amount
        else:
            method_flow[m]["outflow"] += t.amount
        method_flow[m]["count"] += 1

    # Account summary
    account_data = []
    for a in accounts:
        account_data.append({
            "id": a.id,
            "bank_name": a.bank_name,
            "type": a.account_type,
            "balance": a.balance_left,
            "limit": a.limit,
            "is_active": a.is_active,
        })

    return {
        "method_flow": method_flow,
        "accounts": account_data,
    }


@app.get("/analytics/insights")
async def get_spending_insights(
    db: AsyncSession = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Returns AI-generated quick insights from spending patterns."""
    from datetime import datetime, timedelta
    now = datetime.now()
    curr_month = f"{now.year}-{str(now.month).zfill(2)}"
    prev_dt = datetime(now.year, now.month, 1) - timedelta(days=1)
    prev_month = f"{prev_dt.year}-{str(prev_dt.month).zfill(2)}"

    # Current month transactions
    res = await db.execute(
        select(models.Transaction).where(
            models.Transaction.user_id == current_user.id,
            models.Transaction.txn_date.like(f"{curr_month}%")
        )
    )
    curr_txns = res.scalars().all()

    # Previous month transactions
    res2 = await db.execute(
        select(models.Transaction).where(
            models.Transaction.user_id == current_user.id,
            models.Transaction.txn_date.like(f"{prev_month}%")
        )
    )
    prev_txns = res2.scalars().all()

    def is_received(t):
        return t.txn_type == "received" or (t.notes and "Received:" in str(t.notes))

    curr_spent = sum(t.amount for t in curr_txns if not is_received(t))
    prev_spent = sum(t.amount for t in prev_txns if not is_received(t))
    curr_received = sum(t.amount for t in curr_txns if is_received(t))

    # Spending change %
    spend_change = 0.0
    if prev_spent > 0:
        spend_change = round(((curr_spent - prev_spent) / prev_spent) * 100, 1)

    # Top category this month
    cat_totals: dict = {}
    for t in curr_txns:
        if not is_received(t):
            key = str(t.category_id) if t.category_id else "uncategorized"
            cat_totals[key] = cat_totals.get(key, 0) + t.amount
    
    top_cat_id = max(cat_totals.items(), key=lambda x: x[1])[0] if cat_totals else None
    top_cat_name = "Uncategorized"
    top_cat_amount = 0.0
    if top_cat_id and top_cat_id != "uncategorized":
        cat_res = await db.execute(select(models.Category).where(models.Category.id == int(top_cat_id)))
        cat = cat_res.scalars().first()
        if cat:
            top_cat_name = cat.name
        top_cat_amount = cat_totals.get(top_cat_id, 0)
    elif top_cat_id == "uncategorized":
        top_cat_amount = cat_totals.get("uncategorized", 0)

    # Most frequent payment method
    method_counts: dict = {}
    for t in curr_txns:
        m = t.payment_method or "UPI"
        method_counts[m] = method_counts.get(m, 0) + 1
    top_method = max(method_counts.items(), key=lambda x: x[1])[0] if method_counts else "UPI"

    # Largest single transaction
    sent_txns = [t for t in curr_txns if not is_received(t)]
    largest = max(sent_txns, key=lambda t: t.amount) if sent_txns else None

    # Active days (days with at least one txn)
    active_days = len(set(t.txn_date[:10] for t in curr_txns))

    # Category count
    unique_cats = len(set(str(t.category_id) for t in curr_txns if t.category_id))

    insights = []
    if spend_change > 0:
        insights.append({
            "type": "warning",
            "icon": "trending_up",
            "text": f"Spending is up {spend_change}% vs last month",
        })
    elif spend_change < 0:
        insights.append({
            "type": "positive",
            "icon": "trending_down",
            "text": f"Spending is down {abs(spend_change)}% vs last month 🎉",
        })

    if top_cat_name != "Uncategorized":
        pct = round((top_cat_amount / curr_spent * 100), 0) if curr_spent > 0 else 0
        insights.append({
            "type": "info",
            "icon": "category",
            "text": f"Top category: {top_cat_name} ({pct:.0f}% of spending)",
        })

    if largest:
        insights.append({
            "type": "info",
            "icon": "arrow_upward",
            "text": f"Biggest expense: ₹{largest.amount:,.0f} — {largest.title or 'Uncategorized'}",
        })

    insights.append({
        "type": "info",
        "icon": "payment",
        "text": f"Most used: {top_method} ({method_counts.get(top_method, 0)} transactions)",
    })

    if curr_received > 0:
        insights.append({
            "type": "positive",
            "icon": "call_received",
            "text": f"Received ₹{curr_received:,.0f} this month",
        })

    insights.append({
        "type": "info",
        "icon": "calendar_today",
        "text": f"Active {active_days} days across {unique_cats} categories",
    })

    return {
        "insights": insights,
        "spend_change_pct": spend_change,
        "current_total": curr_spent,
        "previous_total": prev_spent,
        "current_received": curr_received,
        "top_category": top_cat_name,
        "top_category_amount": top_cat_amount,
        "top_method": top_method,
    }



