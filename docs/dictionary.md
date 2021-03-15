# Dictionary

## Installation

```
pip install litedict
```

## Use cases

You can use this to implement a persistent dictionary. It also uses some SQLite functions to enable getting keys using pattern matching (see examples). Values are JSON encoded before being saved, the underlying database uses a `TEXT`column for the values. The enconder/decoder can be overriden to use the pickle module and convert the objects to bytes and then to and hex string. The reason for this is that these SQLite structures are not meant to be used from wherever you want, not just Python. By having the values as JSON strings, it's easier to interact with the database from different applications using different programming languages.

## Examples

Initalize dictionary and set up 2 key names.


```python
from litedict import SQLDict

TEST_1 = "key_test_1"
TEST_2 = "key_test_2"
```

The dictionary object inherits from [collections.abc.MutableMapping](https://docs.python.org/3/library/collections.abc.html#collections.abc.MutableMapping), so you can use it as you would use a normal Python dictionary.

```python
d = SQLDict(":memory:")

d[TEST_1] = "asdfoobar"

assert d[TEST_1] == "asdfoobar"

del d[TEST_1]

assert d.get(TEST_1, None) is None
```

Values are JSON encoded before being saved, so you can store numbers normally and operate as if they were numbers. You don't have to worry abount parsing the `string` as an `int`, the values are encoded/decoded internally.

## Pattern matching

By using SQLite's [GLOB](https://www.sqlite.org/lang_expr.html#glob) operator, we can select a set of keys by pattern.

```python
d[TEST_1] = "asdfoobar"

d[TEST_2] = "foobarasd"

d["key_testx_3"] = "barasdfoo"

assert d.glob("key_test*") == ["asdfoobar", "foobarasd", "barasdfoo"]

assert d.glob("key_test_?") == ["asdfoobar", "foobarasd"]

assert d.glob("key_tes[tx]*") == ["asdfoobar", "foobarasd", "barasdfoo"]
```

## Use a custom encoder/decoder

You can pass both functions during the initialization. Make sure they return a string.

```python
import pickle

d = SQLDict(
    ":memory:",
    encoder=lambda x: pickle.dumps(x).hex(),
    decoder=lambda x: pickle.loads(bytes.fromhex(x)),
)
```

## Benchmarks

We will have a look at some benchmarks. First we will import some libraries and create a utility function to generate random strings.

```python
from string import ascii_lowercase, printable
from random import choice
import random
import gc
import pickle
import json


def random_string(string_length=10, fuzz=False, space=False):
    """Generate a random string of fixed length """
    letters = ascii_lowercase
    letters = letters + " " if space else letters
    if fuzz:
        letters = printable
    return "".join(choice(letters) for i in range(string_length))
```

**Pickle**

Enconding values with `pickle.dumps()` and converting the bytes output to and hexadecimal string.

```python
d = SQLDict(
    ":memory:",
    encoder=lambda x: pickle.dumps(x).hex(),
    decoder=lambda x: pickle.loads(bytes.fromhex(x)),
)

gc.collect()

# %%timeit -n20000 -r10

d[random_string(8)] = random_string(50)

d.get(random_string(8), None)

# 69.2 µs ± 4.84 µs per loop (mean ± std. dev. of 10 runs, 20000 loops each)
```

**Pickle custom Python object**

```python
d = SQLDict(
    ":memory:",
    encoder=lambda x: pickle.dumps(x).hex(),
    decoder=lambda x: pickle.loads(bytes.fromhex(x)),
)

gc.collect()

class C:
    def __init__(self, x):
        self.x = x

    def pp(self):
        return x

    def f(self):
        def _f(y):
            return y * self.x ** 2

        return _f

# %%timeit -n20000 -r10

d[random_string(8)] = C(random.randint(1, 200))

d.get(random_string(8), None)

# 41.1 µs ± 2.75 µs per loop (mean ± std. dev. of 10 runs, 20000 loops each)
```

**Noop**

Do not do any encoding/encoding. This requires all values to be strings before being saved.

```python
d = SQLDict(
    ":memory:",
    encoder=lambda x: x,
    decoder=lambda x: x,
)

gc.collect()

# %%timeit -n20000 -r10

d[random_string(8)] = random_string(50)

d.get(random_string(8), None)

# 66.8 µs ± 2.41 µs per loop (mean ± std. dev. of 10 runs, 20000 loops each)
```

**JSON**

This is the **default** enconder.

```python
d = SQLDict(
    ":memory:",
    encoder=lambda x: json.dumps(x),
    decoder=lambda x: json.loads(x),
)

gc.collect()

# %%timeit -n20000 -r10

d[random_string(8)] = random_string(50)

d.get(random_string(8), None)

# 68.6 µs ± 3.07 µs per loop (mean ± std. dev. of 10 runs, 20000 loops each)
```

**Dictionary**

Using a standard Python dictionary.

```python
d = {}

gc.collect()

# %%timeit -n20000 -r10

d[random_string(8)] = random_string(50)

d.get(random_string(8), None)

# 53.1 µs ± 4.42 µs per loop (mean ± std. dev. of 10 runs, 20000 loops each)
```

There's a ~33% difference between the standard Python dictionary and the SQLite + JSON encoding one.

## Alternatives

* [RaRe-Technologies/sqlitedict](https://github.com/RaRe-Technologies/sqlitedict): This library uses a separate writing thread. Modern versions of SQLite are thread safe by default (serialized), so a separate writing thread is not strictly needed. It can be helpful to avoid DB locks, but it also adds extra complexity. That implementation is also missing some performance optimizations that are present in this library.
