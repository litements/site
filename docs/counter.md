# Counter

## Installation

```
pip install litecounter
```

**IMPORTANT**: This package uses SQLite's [UPSERT](https://sqlite.org/lang_upsert.html) statment so it needs to run at least with SQLite version 3.24.0 (released 2018-06-04).

If you need to run the latest version, with Python you can use [pysqlite3](https://github.com/coleifer/pysqlite3) and override `sqlite3`

```python
import pysqlite3 # pre-built if you install pysqlite3-binary
import sys
sys.modules['sqlite3'] = pysqlite3 
```

In near releases you will be able to use a `Connection` instead of a just the database name to create the counter, so you won't need to override `sqlite3` globally.

## Use cases

You can use this to implement a persistent counter. It also uses some SQLite syntax to initialize keys to `0` when the counter starts on them, just as if you had a `collections.defaultdict` where the default is `0`.

## Examples

Set up 2 example key names and initialize the database.

```python
TEST_1 = "key_test_1"
TEST_2 = "key_test_2"

from litecounter import SQLCounter

counter = SQLCounter(":memory:")
```

### Increment or decrement a key

Now we can increment from 0 to 20 using the `counter.incr(keyname)` method. By default, when a key does not exist, it's set to `0`.

```python
for _ in range(20):
    counter.incr(TEST_1) 
```

To check the current count of a key, use the method `counter.count(keyname)`.

```python
assert counter.count(TEST_1) == 20
```

Or decrement by 10 (from 20 to 10) using the `counter.decr(keyname)` method.

```python
for _ in range(10):
    counter.decr(TEST_1)
    
assert counter.count(TEST_1) == 10
```

More examples.

```python

# From 0 to -10, then -20.

for _ in range(10):
    counter.decr(TEST_2)
    
assert counter.count(TEST_2) == -10

for _ in range(10):
    counter.decr(TEST_2)
    
assert counter.count(TEST_2) == -20
```

We can set a key to 0 with the `counter.zero(keyname)` method.

```python
counter.zero(TEST_1)

assert counter.count(TEST_1) == 0
```
```
# Increment the second test key by 100, from -20 to 80.

for _ in range(100):
    counter.incr(TEST_2)
    
assert counter.count(TEST_2) == 80

assert counter.count(TEST_1) == 0
```

### Deleting a key

Use the `counter.delete(keyname)` method.

```
counter.delete(TEST_1)

assert counter.count(TEST_1) is None
```

When the key does not exist, `.delete()` just ignores it

```python
counter.delete("foobar")

# Nothing happens
```

### Priting

The counter implements a `__repr__` method so you can use `print()` on it.

```python
import random

for key in ["foo", "bar", "baz", "foobar", "asd", TEST_1]:
    for _ in range(random.randint(0,10)):
        counter.incr(key)

print(counter)

# SQLCounter(dbname=':memory:', items=[('key_test_2', 80), ('foo', 8), ('baz', 5), ('foobar', 6), ('key_test_1', 10)])
```