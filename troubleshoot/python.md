# Python: “I Know This Stuff, But in the Interview I Freeze” Kit

## Strong intro

You can write Python every day and still freeze in an interview.

That freeze usually does not mean you lack Python skill. It means your knowledge is stored as working memory: fixing a traceback, reading logs, testing a function, checking a virtual environment, debugging imports, improving a slow loop, handling bad input, writing a quick script, or tracing why one object changed when another one should not have.

An interview is different. It asks you to explain clearly, out loud, under pressure.

This kit is built for that moment.

It covers 30 common Python issues interviewers ask about, with symptoms, causes, resolutions, and examples. The goal is not to memorize clever tricks. The goal is to give you a reliable structure when your mind blanks.

When you freeze, start with this sentence:

> “I would first identify whether the issue is syntax, data type, scope, mutability, imports, environment, exception handling, I/O, concurrency, performance, testing, or packaging. Then I would reproduce the error, read the traceback, isolate the smallest failing case, fix the cause, and add a test.”

That sounds like someone who can debug Python safely.

---

## How to use this kit

For every Python issue, use this structure:

```text
Symptom → Cause → Minimal example → Fix → Verify → Prevent
```

A strong Python interview answer usually includes:

1. What error or behavior you see.
2. Why Python behaves that way.
3. A small example.
4. A corrected version.
5. How you would prevent it in real code.

Example:

> “If I see a `TypeError`, I would check the value’s actual type at runtime, confirm what the function expects, and either convert the input, validate it, or fix the caller. I would avoid hiding the issue with broad exception handling.”

That is much stronger than saying:

> “I would Google the error.”

---

# Top 30 Python issues and resolutions

---

## 1. `TypeError` from mixing incompatible types

### Interview freeze point

The interviewer asks:

> “Why does this Python code fail?”

```python
age = 30
message = "Age: " + age
```

### Strong interview answer

> “Python does not automatically concatenate strings and integers. I would convert the integer to a string or use an f-string.”

### Symptom

```text
TypeError: can only concatenate str (not "int") to str
```

### Cause

Python is strongly typed. It will not guess that an integer should become text in a string concatenation.

### Fix

```python
age = 30
message = "Age: " + str(age)
print(message)
```

Better:

```python
age = 30
message = f"Age: {age}"
print(message)
```

### Production example

Bad:

```python
def build_user_message(user_id: int) -> str:
    return "User ID: " + user_id
```

Good:

```python
def build_user_message(user_id: int) -> str:
    return f"User ID: {user_id}"
```

### Prevention

Use type hints and tests:

```python
def build_user_message(user_id: int) -> str:
    return f"User ID: {user_id}"


def test_build_user_message():
    assert build_user_message(42) == "User ID: 42"
```

### Takeaway summary

`TypeError` often means the value is not the type the code expects. Check the actual type, then convert or validate intentionally.

---

## 2. `NoneType` errors

### Interview freeze point

You know this one, but under pressure it is easy to miss.

### Strong interview answer

> “A `NoneType` error usually means I expected an object but got `None`. I would trace where the value is assigned, check functions that may return `None`, and handle the missing value explicitly.”

### Symptom

```text
AttributeError: 'NoneType' object has no attribute 'lower'
```

### Bad example

```python
name = None
print(name.lower())
```

### Fix

```python
name = None

if name is not None:
    print(name.lower())
else:
    print("missing name")
```

### Better function design

Bad:

```python
def find_user(user_id: int):
    if user_id == 1:
        return {"name": "Alice"}
```

If user is not found, Python returns `None` implicitly.

Better:

```python
from typing import Optional


def find_user(user_id: int) -> Optional[dict]:
    if user_id == 1:
        return {"name": "Alice"}
    return None
```

Use it safely:

```python
user = find_user(2)

if user is None:
    print("User not found")
else:
    print(user["name"])
```

### Common causes

- Function forgot a return.
- Lookup found no result.
- Environment variable missing.
- Dictionary `.get()` returned `None`.
- API response missing field.
- Database query returned no row.

### Example with environment variable

```python
import os

api_key = os.getenv("API_KEY")

if api_key is None:
    raise RuntimeError("API_KEY is required")
```

### Takeaway summary

`None` is not an error by itself. The error happens when code treats `None` like a real object.

---

## 3. Mutable default argument bug

### Interview freeze point

This is a classic Python interview question.

### Strong interview answer

> “Default arguments are evaluated once when the function is defined, not each time it is called. A mutable default like a list or dictionary is shared across calls.”

### Bad example

```python
def add_item(item, items=[]):
    items.append(item)
    return items


print(add_item("a"))
print(add_item("b"))
```

Output:

```text
['a']
['a', 'b']
```

### Why this happens

The same list object is reused every time the function is called.

### Fix

```python
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items


print(add_item("a"))
print(add_item("b"))
```

Output:

```text
['a']
['b']
```

### Production example

Bad:

```python
def build_payload(user_id: int, metadata: dict = {}):
    metadata["user_id"] = user_id
    return metadata
```

Good:

```python
def build_payload(user_id: int, metadata: dict | None = None) -> dict:
    if metadata is None:
        metadata = {}

    return {
        **metadata,
        "user_id": user_id,
    }
```

### When mutable defaults are okay

Almost never in normal application code. Sometimes they are used intentionally for caching, but that should be explicit and documented.

### Takeaway summary

Never use mutable objects like `[]` or `{}` as default arguments unless you intentionally want shared state.

---

## 4. List mutation while iterating

### Interview freeze point

The code looks reasonable but skips items.

### Strong interview answer

> “Mutating a list while iterating over it can change indexes and cause items to be skipped. I would create a new list or iterate over a copy.”

### Bad example

```python
numbers = [1, 2, 3, 4, 5, 6]

for number in numbers:
    if number % 2 == 0:
        numbers.remove(number)

print(numbers)
```

This may behave unexpectedly because the list changes during iteration.

### Better: create a new list

```python
numbers = [1, 2, 3, 4, 5, 6]
numbers = [number for number in numbers if number % 2 != 0]

print(numbers)
```

Output:

```text
[1, 3, 5]
```

### Better: iterate over a copy

```python
numbers = [1, 2, 3, 4, 5, 6]

for number in numbers[:]:
    if number % 2 == 0:
        numbers.remove(number)

print(numbers)
```

### Production example

Bad:

```python
for job in jobs:
    if job.status == "done":
        jobs.remove(job)
```

Good:

```python
jobs = [job for job in jobs if job.status != "done"]
```

### Takeaway summary

Do not remove items from a list while directly iterating over that same list. Build a new list or iterate over a copy.

---

## 5. Confusing `is` and `==`

### Interview freeze point

The code works sometimes, then behaves strangely.

### Strong interview answer

> “`==` compares values. `is` compares object identity. I use `is` for `None`, `True`, and `False` checks, but normally use `==` for comparing values.”

### Bad example

```python
a = "hello world"
b = "hello world"

print(a is b)
```

This may be `False` because they may be different objects.

### Correct

```python
a = "hello world"
b = "hello world"

print(a == b)
```

### Correct use of `is`

```python
value = None

if value is None:
    print("missing")
```

### Common mistake

```python
status = "ready"

if status is "ready":
    print("go")
```

Better:

```python
status = "ready"

if status == "ready":
    print("go")
```

### Interview explanation

```text
== asks: do these values mean the same thing?
is asks: are these the exact same object in memory?
```

### Takeaway summary

Use `==` for value equality. Use `is` for identity checks, especially `is None`.

---

## 6. Scope and `UnboundLocalError`

### Interview freeze point

A variable exists, but Python says it is not associated with a value.

### Strong interview answer

> “If a variable is assigned anywhere inside a function, Python treats it as local to that function unless declared `global` or `nonlocal`. I would avoid globals where possible and pass values explicitly.”

### Bad example

```python
count = 0

def increment():
    count += 1
    return count
```

Error:

```text
UnboundLocalError: cannot access local variable 'count' where it is not associated with a value
```

### Why it happens

Because `count += 1` assigns to `count`, Python treats `count` as a local variable inside `increment`.

### Fix with return value

```python
def increment(count: int) -> int:
    return count + 1


count = 0
count = increment(count)
print(count)
```

### Fix with `global`

```python
count = 0

def increment():
    global count
    count += 1
    return count
```

This works, but global state is often harder to test and maintain.

### Better object design

```python
class Counter:
    def __init__(self) -> None:
        self.count = 0

    def increment(self) -> int:
        self.count += 1
        return self.count


counter = Counter()
print(counter.increment())
```

### Takeaway summary

Avoid hidden global mutation. Pass values explicitly or use an object to hold state.

---

## 7. Dictionary key errors

### Interview freeze point

A dictionary lookup fails in production data but not test data.

### Strong interview answer

> “A `KeyError` means the key does not exist. I would check whether the key is required or optional. Required keys should fail clearly. Optional keys should use `.get()` or validation.”

### Bad example

```python
user = {"name": "Alice"}

print(user["email"])
```

Error:

```text
KeyError: 'email'
```

### Optional field

```python
email = user.get("email")
if email is None:
    print("No email provided")
```

### Required field

```python
def get_required_user_email(user: dict) -> str:
    try:
        return user["email"]
    except KeyError as exc:
        raise ValueError("user.email is required") from exc
```

### Better validation

```python
def validate_user(user: dict) -> None:
    required = ["name", "email"]

    missing = [key for key in required if key not in user]
    if missing:
        raise ValueError(f"Missing required fields: {missing}")
```

### Common causes

- API response changed.
- Optional field missing.
- Typo in key.
- Nested dictionary path wrong.
- Test data too perfect.
- JSON field uses different case.

### Takeaway summary

Use direct indexing for required keys. Use `.get()` for optional keys. Validate external data early.

---

## 8. Index errors with lists

### Interview freeze point

The code assumes a list has at least one item.

### Strong interview answer

> “An `IndexError` means the code accessed a list position that does not exist. I would check length before indexing or handle empty data explicitly.”

### Bad example

```python
users = []
first_user = users[0]
```

Error:

```text
IndexError: list index out of range
```

### Fix

```python
users = []

if users:
    first_user = users[0]
else:
    first_user = None
```

### Function example

```python
from typing import Optional


def first_or_none(items: list[str]) -> Optional[str]:
    if not items:
        return None
    return items[0]
```

### Common causes

- API returned empty array.
- Database query found no rows.
- Split string did not produce expected fields.
- Pagination returned no items.
- Filtering removed all items.

### Safer unpacking

Bad:

```python
name, email = line.split(",")
```

If the line has more or fewer than two fields, this fails.

Better:

```python
parts = line.split(",")

if len(parts) != 2:
    raise ValueError(f"Expected 2 fields, got {len(parts)}")

name, email = parts
```

### Takeaway summary

Empty lists are normal. Code should say what happens when there is no first item.

---

## 9. File not found or wrong working directory

### Interview freeze point

The script works locally but fails in CI, Docker, or cron.

### Strong interview answer

> “I would check the current working directory and use absolute paths or paths relative to the script file. Many file errors happen because the process starts from a different directory than expected.”

### Symptom

```text
FileNotFoundError: [Errno 2] No such file or directory
```

### Bad example

```python
with open("config.json") as file:
    data = file.read()
```

This depends on where the command is run from.

### Better

```python
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
config_path = BASE_DIR / "config.json"

with config_path.open() as file:
    data = file.read()
```

### Diagnostic

```python
from pathlib import Path

print("cwd:", Path.cwd())
print("script:", Path(__file__).resolve())
```

### Common causes

- Running from a different directory.
- File not copied into Docker image.
- CI checkout path differs.
- Cron starts from home directory.
- Relative path assumed.
- Case-sensitive filesystem in Linux but not local Mac/Windows.

### Takeaway summary

Relative paths depend on the working directory. Use `pathlib` and explicit paths for reliable scripts.

---

## 10. Import errors

### Interview freeze point

The module exists, but Python cannot import it.

### Strong interview answer

> “I would check the active Python interpreter, virtual environment, package installation, module path, working directory, package structure, and whether a local file is shadowing a real package.”

### Symptoms

- `ModuleNotFoundError`
- `ImportError`
- Works in IDE but not terminal.
- Works locally but not Docker/CI.
- Installed package not found.
- Wrong version imported.

### Diagnostic commands

```bash
which python
python --version
python -m pip show requests
python -c "import sys; print(sys.path)"
```

Use:

```bash
python -m pip install requests
```

instead of guessing which `pip` is active.

### Common causes

- Package installed in different environment.
- Virtual environment not activated.
- Wrong Python version.
- Local file shadows package.
- Missing `__init__.py` in older package style.
- Running script from wrong location.
- Package not installed in Docker image.

### Shadowing example

Bad file name:

```text
requests.py
```

Then:

```python
import requests
```

may import your local file instead of the real package.

### Better project structure

```text
project/
  pyproject.toml
  src/
    myapp/
      __init__.py
      main.py
  tests/
```

### Takeaway summary

Import errors are usually environment, path, package installation, or naming conflicts.

---

## 11. Virtual environment confusion

### Interview freeze point

The package is installed, but the code still fails.

### Strong interview answer

> “I would confirm the interpreter and pip belong to the same virtual environment. I prefer `python -m pip` because it installs into the interpreter I am actually using.”

### Symptoms

- `pip install` succeeds, import still fails.
- IDE uses different interpreter.
- CI uses system Python.
- `requirements.txt` installed globally by mistake.
- Different package version at runtime.

### Create and use venv

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
python -m pip install -r requirements.txt
```

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### Verify

```bash
which python
python -m pip --version
python -c "import sys; print(sys.executable)"
```

### Common causes

- Wrong interpreter selected.
- Running `pip` outside venv.
- IDE configured with different Python.
- Shell not activated.
- Docker image missing dependencies.
- Multiple Python versions installed.

### Takeaway summary

Always match `python` and `pip`. `python -m pip` removes much of the guesswork.

---

## 12. Exception handling too broad

### Interview freeze point

The code “handles errors,” but hides the real problem.

### Strong interview answer

> “I avoid broad `except Exception` unless I re-raise or log enough context. Good exception handling catches expected errors, handles them intentionally, and lets unexpected errors fail loudly.”

### Bad example

```python
try:
    result = process_order(order)
except Exception:
    result = None
```

This hides the actual failure.

### Better

```python
try:
    result = process_order(order)
except ValueError as exc:
    raise ValueError(f"Invalid order: {order['id']}") from exc
```

### Logging unexpected errors

```python
import logging

logger = logging.getLogger(__name__)

try:
    result = process_order(order)
except Exception:
    logger.exception("Failed to process order_id=%s", order.get("id"))
    raise
```

### Common causes

- Catching all exceptions and continuing.
- Swallowing API failures.
- Returning `None` for every error.
- Losing original traceback.
- Catching wrong exception type.
- Retry loop hides permanent failure.

### Good interview phrase

> “I catch the narrowest exception I can handle. If I cannot handle it, I log context and re-raise.”

### Takeaway summary

Do not hide errors. Handle expected failures and preserve context for unexpected ones.

---

## 13. Forgetting to close files or connections

### Interview freeze point

Code works in small tests but leaks resources.

### Strong interview answer

> “I would use context managers for files, locks, database connections, and network resources so cleanup happens even when exceptions occur.”

### Bad example

```python
file = open("data.txt")
data = file.read()
file.close()
```

If `read()` raises, `close()` may not run.

### Better

```python
with open("data.txt") as file:
    data = file.read()
```

### With pathlib

```python
from pathlib import Path

data = Path("data.txt").read_text()
```

### Database-like example

```python
with get_connection() as conn:
    with conn.cursor() as cur:
        cur.execute("select 1")
```

### Custom context manager

```python
from contextlib import contextmanager


@contextmanager
def managed_resource():
    print("open")
    try:
        yield
    finally:
        print("close")


with managed_resource():
    print("use")
```

### Takeaway summary

Use `with` for resources that must be cleaned up. It is safer and clearer.

---

## 14. Slow code from inefficient loops

### Interview freeze point

A solution works but is too slow.

### Strong interview answer

> “I would check algorithmic complexity before micro-optimizing. Often the fix is using a set or dictionary instead of nested loops.”

### Bad example

```python
users = [1, 2, 3, 4]
active_users = [2, 4]

result = []

for user in users:
    if user in active_users:
        result.append(user)
```

This is okay for small lists, but `user in active_users` is O(n), making the loop O(n²)-like for large data.

### Better

```python
users = [1, 2, 3, 4]
active_users = [2, 4]
active_set = set(active_users)

result = [user for user in users if user in active_set]
```

### Example with records

```python
orders = [{"id": 1, "user_id": 10}, {"id": 2, "user_id": 20}]
users = [{"id": 10, "name": "Alice"}, {"id": 20, "name": "Bob"}]

user_by_id = {user["id"]: user for user in users}

for order in orders:
    order["user_name"] = user_by_id[order["user_id"]]["name"]
```

### Common causes

- Nested loops over large collections.
- Repeated database/API calls inside loop.
- Recomputing expensive values.
- Using list membership instead of set membership.
- Reading full files into memory unnecessarily.

### Takeaway summary

Performance often improves by choosing the right data structure, not by making the same loop slightly faster.

---

## 15. Memory issues from loading everything at once

### Interview freeze point

The code works for small files but fails with real data.

### Strong interview answer

> “I would avoid loading huge files or datasets fully into memory. I would stream, iterate, paginate, or process in chunks.”

### Bad example

```python
with open("large.log") as file:
    lines = file.readlines()

for line in lines:
    process(line)
```

### Better

```python
with open("large.log") as file:
    for line in file:
        process(line)
```

### CSV example

```python
import csv

with open("users.csv", newline="") as file:
    reader = csv.DictReader(file)
    for row in reader:
        process_user(row)
```

### API pagination pattern

```python
def fetch_pages(client):
    page = 1

    while True:
        response = client.get_users(page=page)
        users = response["users"]

        if not users:
            break

        for user in users:
            yield user

        page += 1
```

### Common causes

- `read()`, `readlines()`, or `list()` on huge data.
- Storing all API responses.
- Building giant lists when a generator would work.
- Combining all records before processing.
- Pandas used for data too large for memory.

### Takeaway summary

For large data, stream or batch. Do not load everything unless you know it fits.

---

## 16. Confusing shallow copy and deep copy

### Interview freeze point

Changing one object unexpectedly changes another.

### Strong interview answer

> “A shallow copy copies the outer container but keeps references to nested objects. If nested objects must be independent, use `copy.deepcopy()` or build a new structure intentionally.”

### Bad example

```python
original = {"users": ["Alice", "Bob"]}
copy_data = original.copy()

copy_data["users"].append("Charlie")

print(original)
```

Output:

```text
{'users': ['Alice', 'Bob', 'Charlie']}
```

### Why

The outer dictionary was copied, but the nested list is shared.

### Deep copy

```python
import copy

original = {"users": ["Alice", "Bob"]}
copy_data = copy.deepcopy(original)

copy_data["users"].append("Charlie")

print(original)
print(copy_data)
```

### Better explicit copy

```python
original = {"users": ["Alice", "Bob"]}

copy_data = {
    "users": list(original["users"])
}
```

### Common causes

- Copying nested dictionaries.
- Reusing default config objects.
- Updating request payload templates.
- Mutating nested lists.
- Shared state between tests.

### Takeaway summary

Shallow copy is only one level deep. Nested mutable objects are still shared.

---

## 17. Class instance attribute versus class attribute bug

### Interview freeze point

Different objects accidentally share data.

### Strong interview answer

> “Class attributes are shared by all instances. Instance attributes belong to one object. For per-instance mutable state, initialize it in `__init__`.”

### Bad example

```python
class Team:
    members = []

    def add_member(self, name):
        self.members.append(name)


team_a = Team()
team_b = Team()

team_a.add_member("Alice")
team_b.add_member("Bob")

print(team_a.members)
print(team_b.members)
```

Both show:

```text
['Alice', 'Bob']
```

### Fix

```python
class Team:
    def __init__(self):
        self.members = []

    def add_member(self, name):
        self.members.append(name)
```

### Class attribute used correctly

```python
class User:
    role = "viewer"

    def __init__(self, name):
        self.name = name
```

Here `role` is a shared default value, not a mutable list.

### Dataclass version

Bad:

```python
from dataclasses import dataclass

@dataclass
class Team:
    members: list[str] = []
```

Better:

```python
from dataclasses import dataclass, field

@dataclass
class Team:
    members: list[str] = field(default_factory=list)
```

### Takeaway summary

Use instance attributes for per-object state. Be careful with mutable class attributes.

---

## 18. Dataclass mutable defaults

### Interview freeze point

This is the dataclass version of the mutable default bug.

### Strong interview answer

> “For dataclasses, mutable defaults should use `field(default_factory=...)` so each instance gets its own object.”

### Bad example

```python
from dataclasses import dataclass

@dataclass
class Cart:
    items: list[str] = []
```

This is invalid in modern dataclasses because Python protects you from this common bug.

### Correct

```python
from dataclasses import dataclass, field

@dataclass
class Cart:
    items: list[str] = field(default_factory=list)
```

### Example

```python
cart_a = Cart()
cart_b = Cart()

cart_a.items.append("book")

print(cart_a.items)
print(cart_b.items)
```

Output:

```text
['book']
[]
```

### Dictionary default

```python
from dataclasses import dataclass, field

@dataclass
class Config:
    options: dict[str, str] = field(default_factory=dict)
```

### Takeaway summary

In dataclasses, use `default_factory` for lists, dictionaries, sets, and other mutable defaults.

---

## 19. Floating point precision surprise

### Interview freeze point

The math looks wrong.

### Strong interview answer

> “Floating point numbers are binary approximations. For money or exact decimal arithmetic, I would use `Decimal` instead of float.”

### Example

```python
print(0.1 + 0.2)
```

Output:

```text
0.30000000000000004
```

### Why

Many decimal fractions cannot be represented exactly in binary floating point.

### Use rounding for display

```python
value = 0.1 + 0.2
print(round(value, 2))
```

### Use Decimal for money

```python
from decimal import Decimal

price = Decimal("0.10")
tax = Decimal("0.20")

print(price + tax)
```

Output:

```text
0.30
```

### Bad money code

```python
total = 0.0

for price in [0.10, 0.20, 0.30]:
    total += price
```

Better:

```python
from decimal import Decimal

total = Decimal("0.00")

for price in ["0.10", "0.20", "0.30"]:
    total += Decimal(price)
```

### Takeaway summary

Float is fine for approximate measurement. Use `Decimal` for exact decimal values like money.

---

## 20. Date and timezone bugs

### Interview freeze point

Date code works locally but fails in production.

### Strong interview answer

> “I would avoid naive datetimes for systems that cross time zones. I would store timestamps in UTC and convert to local time only at the edges.”

### Bad example

```python
from datetime import datetime

created_at = datetime.now()
```

This creates a naive datetime with no timezone information.

### Better

```python
from datetime import datetime, timezone

created_at = datetime.now(timezone.utc)
```

### Parse ISO timestamp

```python
from datetime import datetime

timestamp = datetime.fromisoformat("2026-05-02T12:30:00+00:00")
```

### Common causes

- Naive datetime mixed with aware datetime.
- Server timezone differs from developer machine.
- Daylight saving changes.
- Storing local time in database.
- Comparing string dates.
- Assuming all timestamps are UTC without checking.

### Example comparison failure

```python
from datetime import datetime, timezone

aware = datetime.now(timezone.utc)
naive = datetime.now()

print(aware > naive)
```

This raises because Python will not compare aware and naive datetimes.

### Takeaway summary

Use timezone-aware UTC datetimes internally. Convert for display only.

---

## 21. JSON serialization errors

### Interview freeze point

The object is valid Python but not valid JSON.

### Strong interview answer

> “JSON supports limited types. I would convert Python-specific objects like datetime, Decimal, set, or custom classes into JSON-safe types before serialization.”

### Symptom

```text
TypeError: Object of type datetime is not JSON serializable
```

### Bad example

```python
import json
from datetime import datetime, timezone

data = {
    "created_at": datetime.now(timezone.utc)
}

json.dumps(data)
```

### Fix

```python
import json
from datetime import datetime, timezone

data = {
    "created_at": datetime.now(timezone.utc).isoformat()
}

print(json.dumps(data))
```

### Common non-JSON types

```text
datetime
date
Decimal
set
bytes
custom class
UUID
```

### Custom encoder example

```python
import json
from datetime import datetime
from decimal import Decimal


class AppEncoder(json.JSONEncoder):
    def default(self, value):
        if isinstance(value, datetime):
            return value.isoformat()
        if isinstance(value, Decimal):
            return str(value)
        return super().default(value)


payload = {
    "amount": Decimal("10.50"),
    "created_at": datetime.utcnow(),
}

print(json.dumps(payload, cls=AppEncoder))
```

### Takeaway summary

Before converting to JSON, convert Python-specific objects into strings, numbers, lists, dictionaries, booleans, or null.

---

## 22. Logging with `print` instead of structured logging

### Interview freeze point

The script works, but production troubleshooting is weak.

### Strong interview answer

> “For production code, I would use the `logging` module instead of print. Logging supports levels, timestamps, formatting, handlers, and integration with observability systems.”

### Bad example

```python
print("failed to process order")
```

### Better

```python
import logging

logger = logging.getLogger(__name__)

logger.info("Processing order_id=%s", order_id)
logger.warning("Retrying order_id=%s", order_id)
logger.exception("Failed to process order_id=%s", order_id)
```

### Basic setup

```python
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
```

### Exception logging

```python
try:
    process_order(order)
except Exception:
    logger.exception("Failed to process order_id=%s", order["id"])
    raise
```

`logger.exception()` includes traceback when called inside an exception handler.

### Common mistakes

- Using print in services.
- Logging secrets.
- Losing stack trace.
- Logging too much at error level.
- String formatting before log level check.

Better:

```python
logger.info("User %s logged in", user_id)
```

Avoid:

```python
logger.info(f"User {user_id} logged in")
```

The f-string is evaluated before logging decides whether to emit it.

### Takeaway summary

Use logging for production code. Include context, avoid secrets, and preserve tracebacks.

---

## 23. Testing only the happy path

### Interview freeze point

The function works for ideal input but fails on edge cases.

### Strong interview answer

> “I would test the happy path, edge cases, invalid input, empty input, and failure behavior. Good tests prove how code behaves when data is imperfect.”

### Example function

```python
def normalize_email(email: str) -> str:
    return email.strip().lower()
```

### Tests

```python
import pytest

def test_normalize_email():
    assert normalize_email(" ALICE@EXAMPLE.COM ") == "alice@example.com"

def test_normalize_email_empty_string():
    assert normalize_email("   ") == ""

def test_normalize_email_none_rejected():
    with pytest.raises(AttributeError):
        normalize_email(None)
```

Better function with validation:

```python
def normalize_email(email: str) -> str:
    if not isinstance(email, str):
        raise TypeError("email must be a string")

    normalized = email.strip().lower()

    if not normalized:
        raise ValueError("email cannot be empty")

    return normalized
```

Better tests:

```python
def test_normalize_email_none_rejected():
    with pytest.raises(TypeError):
        normalize_email(None)

def test_normalize_email_empty_rejected():
    with pytest.raises(ValueError):
        normalize_email("   ")
```

### Common missing tests

```text
Empty input
None input
Invalid type
Missing field
Duplicate data
Large input
External API failure
Permission error
Timeout
```

### Takeaway summary

Good tests cover expected behavior and failure behavior.

---

## 24. Mocking external services incorrectly

### Interview freeze point

Tests pass, but integration fails.

### Strong interview answer

> “I would mock external services at the boundary and keep tests realistic. Over-mocking internal behavior makes tests pass without proving the real contract.”

### Bad design

```python
def get_user_email(user_id):
    response = requests.get(f"https://api.example.com/users/{user_id}")
    return response.json()["email"]
```

This is hard to test without making a real HTTP call.

### Better design

```python
class UserClient:
    def __init__(self, base_url: str, http_client):
        self.base_url = base_url
        self.http_client = http_client

    def get_user_email(self, user_id: int) -> str:
        response = self.http_client.get(f"{self.base_url}/users/{user_id}")
        response.raise_for_status()
        return response.json()["email"]
```

### Test with fake client

```python
class FakeResponse:
    def raise_for_status(self):
        pass

    def json(self):
        return {"email": "alice@example.com"}


class FakeHttpClient:
    def get(self, url):
        return FakeResponse()


def test_get_user_email():
    client = UserClient("https://api.example.com", FakeHttpClient())
    assert client.get_user_email(1) == "alice@example.com"
```

### Common mistakes

- Mocking the function under test.
- Mocking too deep.
- Not testing error responses.
- Not checking request URL/body.
- Mock response does not match real API.
- No integration test at all.

### Takeaway summary

Mock external boundaries, not the code you are trying to prove.

---

## 25. Async code not awaited

### Interview freeze point

The async function returns a coroutine instead of a result.

### Strong interview answer

> “Calling an async function returns a coroutine. It does not run to completion until awaited or scheduled in an event loop.”

### Bad example

```python
async def fetch_data():
    return {"status": "ok"}


result = fetch_data()
print(result)
```

Output looks like:

```text
<coroutine object fetch_data at ...>
```

### Fix

```python
import asyncio

async def fetch_data():
    return {"status": "ok"}


async def main():
    result = await fetch_data()
    print(result)


asyncio.run(main())
```

### Common causes

- Forgot `await`.
- Calling async function from sync code incorrectly.
- Mixing sync requests with async code.
- Creating tasks but never awaiting them.
- Event loop already running in notebook/web framework.

### Running tasks concurrently

```python
import asyncio

async def fetch_user(user_id: int) -> dict:
    return {"id": user_id}


async def main():
    users = await asyncio.gather(
        fetch_user(1),
        fetch_user(2),
        fetch_user(3),
    )
    print(users)


asyncio.run(main())
```

### Takeaway summary

Async functions must be awaited or scheduled. Otherwise you only have a coroutine object.

---

## 26. Blocking calls inside async code

### Interview freeze point

The code is async but still slow.

### Strong interview answer

> “Async only helps if the work yields control while waiting. Blocking calls like `time.sleep()` or synchronous HTTP clients block the event loop.”

### Bad example

```python
import time

async def handle_request():
    time.sleep(5)
    return "done"
```

This blocks the event loop.

### Better

```python
import asyncio

async def handle_request():
    await asyncio.sleep(5)
    return "done"
```

### Bad HTTP example

```python
import requests

async def fetch_url(url: str):
    response = requests.get(url)
    return response.text
```

`requests.get()` is blocking.

### Better with async client

```python
import httpx

async def fetch_url(url: str):
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        response.raise_for_status()
        return response.text
```

### Common blocking calls

```text
time.sleep
requests.get
subprocess.run
CPU-heavy loops
synchronous database drivers
large file operations
```

### Takeaway summary

Async code must use non-blocking libraries or offload blocking work. Otherwise the event loop gets stuck.

---

## 27. Threading race condition

### Interview freeze point

The code works sometimes and fails randomly.

### Strong interview answer

> “A race condition happens when multiple threads access shared state without coordination. I would avoid shared mutable state where possible or protect it with locks.”

### Bad example

```python
import threading

counter = 0

def increment():
    global counter
    for _ in range(100_000):
        counter += 1


threads = [threading.Thread(target=increment) for _ in range(2)]

for thread in threads:
    thread.start()

for thread in threads:
    thread.join()

print(counter)
```

The final value may be wrong because increments are not safely coordinated.

### Fix with lock

```python
import threading

counter = 0
lock = threading.Lock()

def increment():
    global counter
    for _ in range(100_000):
        with lock:
            counter += 1
```

### Better design

Avoid shared mutation:

```python
def count_items(items: list[int]) -> int:
    return len(items)
```

Collect results and combine them after threads finish.

### Common causes

- Shared counters.
- Shared lists/dicts.
- Writing same file.
- Updating cache.
- Multiple workers processing same job.
- Check-then-act logic without lock.

### Takeaway summary

Concurrency bugs are often shared-state bugs. Avoid shared mutation or guard it with synchronization.

---

## 28. Misunderstanding the GIL

### Interview freeze point

The interviewer asks about Python threading performance.

### Strong interview answer

> “The GIL means only one thread executes Python bytecode at a time in the standard CPython interpreter. Threads can still help with I/O-bound work, but CPU-bound work often needs multiprocessing, native extensions, or another architecture.”

### Good use of threads

I/O-bound work:

```python
from concurrent.futures import ThreadPoolExecutor
import requests

def fetch(url: str) -> int:
    response = requests.get(url, timeout=5)
    return response.status_code

urls = ["https://example.com"] * 10

with ThreadPoolExecutor(max_workers=5) as pool:
    print(list(pool.map(fetch, urls)))
```

### CPU-bound work

For CPU-heavy Python code, use processes:

```python
from concurrent.futures import ProcessPoolExecutor

def calculate(n: int) -> int:
    return sum(i * i for i in range(n))

with ProcessPoolExecutor() as pool:
    print(list(pool.map(calculate, [10_000_000, 10_000_000])))
```

### Interview phrasing

```text
Threads: good for waiting on I/O.
Processes: better for CPU-bound Python work.
Async: good for high-concurrency I/O when libraries support it.
```

### Takeaway summary

The GIL does not make threads useless. It makes them better for I/O than CPU-heavy Python code.

---

## 29. Packaging and dependency version conflicts

### Interview freeze point

The app works on one machine but breaks elsewhere.

### Strong interview answer

> “I would pin dependencies, use virtual environments, separate app dependencies from dev dependencies, and build reproducibly. Dependency conflicts are environment problems as much as code problems.”

### Symptoms

- Works locally but not CI.
- Different package version installed.
- Transitive dependency breaks app.
- `ImportError` after upgrade.
- Docker build uses newer dependency.
- Tests fail after fresh install.

### Basic requirements

```text
requests==2.32.3
pydantic==2.8.2
```

Install:

```bash
python -m pip install -r requirements.txt
```

### Modern project file example

```toml
[project]
name = "myapp"
version = "0.1.0"
dependencies = [
  "requests>=2.32,<3",
  "pydantic>=2,<3",
]
```

### Common causes

- Unpinned dependencies.
- Different Python version.
- Different OS.
- Transitive dependency changed.
- Lock file ignored.
- Global packages leaking into environment.
- Dev dependency needed at runtime.

### Prevention

```text
Use virtual environments
Pin or lock dependencies
Run clean installs in CI
Build Docker image from scratch
Keep dependency update process controlled
```

### Takeaway summary

Reproducible Python needs controlled Python version, dependency versions, and environment setup.

---

## 30. Poor script structure makes code hard to test

### Interview freeze point

The script works, but it is hard to maintain.

### Strong interview answer

> “I would separate pure logic from side effects. Code is easier to test when parsing, business logic, I/O, and CLI entrypoints are separated.”

### Bad script

```python
import requests

response = requests.get("https://api.example.com/users")
users = response.json()

for user in users:
    print(user["email"].lower())
```

This runs on import and is hard to test.

### Better structure

```python
import requests


def normalize_email(email: str) -> str:
    return email.strip().lower()


def fetch_users(base_url: str) -> list[dict]:
    response = requests.get(f"{base_url}/users", timeout=10)
    response.raise_for_status()
    return response.json()


def main() -> None:
    users = fetch_users("https://api.example.com")

    for user in users:
        print(normalize_email(user["email"]))


if __name__ == "__main__":
    main()
```

### Test pure function

```python
def test_normalize_email():
    assert normalize_email(" ALICE@EXAMPLE.COM ") == "alice@example.com"
```

### Benefits

```text
No side effects on import
Pure functions are testable
I/O is isolated
CLI entrypoint is clear
Errors are easier to locate
```

### Takeaway summary

Good Python structure separates logic from I/O and uses `if __name__ == "__main__"` for script entrypoints.

---

# Bonus: Python interview answer frameworks

## Framework 1: The traceback answer

Use this when asked:

> “How do you debug a Python error?”

```text
1. Read the last line of the traceback.
2. Identify exception type and message.
3. Find the first line in my code.
4. Inspect variable values at that line.
5. Create the smallest reproduction.
6. Fix the root cause, not only the symptom.
7. Add or update a test.
```

Interview version:

> “The exception type tells me the category. The traceback tells me where. The variable values tell me why.”

---

## Framework 2: The data validation answer

Use this when asked:

> “How do you handle bad input?”

```text
1. Treat external input as untrusted.
2. Validate required fields.
3. Validate types.
4. Normalize values.
5. Fail clearly for invalid input.
6. Use defaults only when safe.
7. Add tests for missing and malformed data.
```

Interview version:

> “I validate at boundaries so the rest of the code can work with trusted shapes.”

---

## Framework 3: The performance answer

Use this when asked:

> “How do you optimize slow Python code?”

```text
1. Measure first.
2. Identify whether it is CPU, I/O, memory, or algorithmic.
3. Check data structures.
4. Remove unnecessary repeated work.
5. Batch external calls.
6. Stream large data.
7. Use profiling tools when needed.
8. Keep code readable.
```

Interview version:

> “I avoid guessing. I measure first, then fix the biggest bottleneck.”

---

## Framework 4: The concurrency answer

Use this when asked:

> “Threads, async, or multiprocessing?”

```text
1. I/O-bound with blocking libraries: threads may help.
2. I/O-bound with async libraries: async can scale well.
3. CPU-bound Python code: multiprocessing is often better.
4. Shared state requires careful synchronization.
5. Simpler code is better unless concurrency is needed.
```

Interview version:

> “I choose concurrency based on the bottleneck, not because one model sounds modern.”

---

## Framework 5: The production Python answer

Use this when asked:

> “What makes Python code production-ready?”

```text
1. Clear structure.
2. Type hints where useful.
3. Input validation.
4. Good logging.
5. Tests for success and failure paths.
6. Dependency pinning.
7. Configuration through environment or files.
8. Proper exception handling.
9. Observability.
10. Repeatable deployment.
```

Interview version:

> “Production Python is about predictable behavior, clear failures, and repeatable environments.”

---

# Common Python interview traps and better answers

## Trap 1: “Would you just catch all exceptions?”

Weak answer:

> “Yes, to stop the program from crashing.”

Better answer:

> “I would catch only exceptions I can handle. For unexpected exceptions, I would log context and re-raise.”

---

## Trap 2: “Are lists and tuples basically the same?”

Weak answer:

> “Yes, both store items.”

Better answer:

> “Both are sequences, but lists are mutable and tuples are immutable. I use lists for changing collections and tuples for fixed groupings.”

---

## Trap 3: “Does Python pass variables by value or reference?”

Weak answer:

> “By reference.”

Better answer:

> “Python passes object references by assignment. Mutating a passed mutable object can affect the caller, but rebinding the local name does not.”

Example:

```python
def add_item(items):
    items.append("x")


values = []
add_item(values)
print(values)
```

Output:

```text
['x']
```

---

## Trap 4: “Can you use mutable defaults?”

Weak answer:

> “Yes.”

Better answer:

> “Usually no. Mutable defaults are shared across calls. I would use `None` and create the object inside the function.”

---

## Trap 5: “Are threads always faster?”

Weak answer:

> “Yes.”

Better answer:

> “Not always. Threads can help I/O-bound work, but CPU-bound Python code is limited by the GIL in CPython. I would measure and choose threads, async, or processes based on the workload.”

---

## Trap 6: “Does `is` compare values?”

Weak answer:

> “Yes.”

Better answer:

> “No. `is` compares identity. `==` compares values. I use `is None` but `==` for normal value comparison.”

---

## Trap 7: “Is `print` good enough for production?”

Weak answer:

> “Yes.”

Better answer:

> “For scripts, maybe. For production services, I use structured logging with levels and context.”

---

# Python interview quick-reference table

| Issue | Main symptom | First thing to check | Common fix |
|---|---|---|---|
| Type mismatch | `TypeError` | Actual value type | Convert or validate |
| `NoneType` error | Attribute error | Source of `None` | Handle missing value |
| Mutable default | Shared state | Function defaults | Use `None` default |
| Mutating list | Skipped items | Loop mutation | Build new list |
| `is` vs `==` | Weird comparison | Identity vs value | Use `==` for values |
| Scope error | `UnboundLocalError` | Assignment in function | Pass state explicitly |
| Key error | Missing dict key | Input data shape | Validate or `.get()` |
| Index error | Empty list | List length | Check before indexing |
| File not found | Path error | Working directory | Use `pathlib` |
| Import error | Module missing | Interpreter/env | Fix venv/import path |
| Venv confusion | Package not found | `python -m pip` | Use correct venv |
| Broad except | Hidden failure | Exception handler | Catch narrow errors |
| Resource leak | File/conn open | Cleanup path | Use `with` |
| Slow loop | High runtime | Data structure | Use set/dict |
| Memory issue | OOM/large data | Loading pattern | Stream/batch |
| Copy bug | Shared nested data | Shallow copy | Deep copy or explicit |
| Class attr bug | Shared instance data | Class vs instance attr | Use `__init__` |
| Dataclass default | Shared mutable default | Field default | `default_factory` |
| Float surprise | 0.1 + 0.2 issue | Numeric type | Use Decimal if exact |
| Timezone bug | Wrong time | Naive datetime | Use UTC aware datetime |
| JSON error | Not serializable | Object type | Convert to JSON-safe |
| Weak logging | Poor debugging | print/logging | Use `logging` |
| Weak tests | Edge failures | Test cases | Test failures too |
| Bad mocks | False confidence | Mock boundary | Mock external services |
| Async not awaited | Coroutine object | Await usage | `await` / `asyncio.run` |
| Blocking async | Slow event loop | Blocking call | Use async libraries |
| Race condition | Random results | Shared state | Lock or avoid sharing |
| GIL confusion | Threads not faster | Workload type | Threads/async/processes |
| Dependency conflict | Works on one machine | Versions/env | Pin/lock dependencies |
| Poor structure | Hard to test | Side effects | Separate logic/I/O |

---

# Strong closing takeaway

Python interviews are not just syntax tests. They are debugging, design, and reasoning tests.

A weak answer sounds like:

> “I would try some things until it works.”

A strong answer sounds like:

> “I would read the traceback, identify the exception type, inspect the value that caused it, reduce the problem to a small example, fix the root cause, and add a test so it does not return.”

Python problems usually leave evidence in:

```text
Tracebacks
Exception type
Variable values
Input data shape
Function return values
Environment/interpreter
Dependency versions
Logs
Tests
```

When you freeze, return to this sequence:

```text
Error → Traceback → Failing line → Actual value → Expected value → Root cause → Fix → Test
```

That sequence will carry you through most Python interview questions.

---

# Final takeaway summaries

## The one-minute summary

Python issues usually come from type mismatches, `None`, mutability, scope, imports, virtual environments, file paths, exception handling, data validation, performance, memory, class attributes, dataclasses, floating point, timezones, JSON serialization, logging, testing, async, threading, dependency conflicts, and poor script structure. The best answer starts with the traceback and the actual value that caused the failure.

## The senior-engineer summary

A senior Python engineer understands that Python is simple to write but still needs discipline. They validate external data, avoid hidden shared state, use clear error handling, structure code for testing, choose the right data structures, stream large data, manage dependencies, log with context, and know when to use sync, async, threads, or processes. Seniority is shown by predictable code, clear failures, and maintainable design.

## The interview survival summary

When your mind goes blank, say:

> “I would first read the traceback and identify the exception type. Then I would inspect the failing line, check the actual runtime value and type, reduce the issue to a small example, fix the root cause, and add a test for the edge case.”

That answer works across most Python interview scenarios.
