# Queue

## Installation

```
pip install litequeue
```

## Use cases

You can use this to implement a persistent queue. It also has timing metrics for the messages, and the api to set a message as done lets you specify the `message_id` to be set as done.

Since it's all based on SQLite / SQL, it is easily extendable.

Tasks/messages are always passed as strings, so you can use JSON data as messages. Messages are interpreted as tasks, so after you `pop` a message, you need to mark it as done when you finish processing it.

## Differences with a normal Python `queue.Queue`

- Persistence
- Different API to mark messages as done (you tell it which `message_id ` to set as done)
- Timing metrics. As long as messages are still in the queue or not pruned, you can see how long they have been there or how long they took to finish.
- Easy to extend using SQL
- Messages/elements/tasks in the queue are always strings

## Messages data

- message (text): the message itself, it must be a string
- message_id (text): a random string ID generated when the message is put in the queue.
- status (int): status of the message. 0 = free, 1 = locked (the message is being processed), 2 = done (the message has been processed, and it can be deleted).
- in_time (int): the [Unix epoch time](https://en.wikipedia.org/wiki/Unix_time) when the message was inserted in the queue
- lock_time (int): the Unix epoch time when the message was locked for processing
- done_time (int): the Unix epoch time when the message was marked as done/processed

## Architecture

SQLite does not have row-level locks, so we can't use the pattern like `SELECT ... FOR UPDATE SKIP LOCKED`. The current `litequeue` implementation marks a message as locked first and then returns it. The application is in charge of setting it as done. The problem with this approach is that the application could crash while processing the message/task, so it would stay marked locked forever. The messages table has an `in_time` and `lock_time` columns (both are Unix epochs). To counter the lock + crash problem, some logic could be implemented like:

```
time_locked = in_time - lock_time

if time_locked > threshhold:
delete/modify/add_again ( message )
```

With that pattern, you can check all the tasks that have been locked for more than `X` seconds and do whatever you need with them.

## Examples

Initialize a queue and put 4 messages. Each time you put a message in the queue, it returns the `rowid` of the message you just inserted.

### Put messages

```python
from litequeue import SQLQueue

q = SQLQueue(":memory:")

q.put("hello")
q.put("world")
q.put("foo")
q.put("bar")
# 4  <- ID of the last row modified
```

### Pop messages

Now we can use the `q.pop()` method to retrieve the next message. For each message, a random `message_id` will be generated on creation. The `.pop()` method returns a dictionary with the message's data.

```python
q.pop()
# {'message': 'hello', 'message_id': '7da620ac542acd76c806dbcf00218426', ...}
```

### Printing the queue

The queue object implements a `__repr__` method, so you can use `print(q)` to check the contents.

```python
print(q)


#    SQLQueue(Connection='sqlite3.Connection(...)', items=[{'done_time': None,
#      'in_time': 1612711137,
#      'lock_time': 1612711137,
#      'message': 'hello',
#      'status': 1,
#      'message_id': '7da620ac542acd76c806dbcf00218426'},
#       ...
```

### Message processing

If we `pop` all the messages and try to `pop` another one, it will return `None`.

```python
# pop remaining
for _ in range(3):
    q.pop()


assert q.pop() is None
```

Now we will insert 4 more messages. The last message returns `8`. That means the last message inserted has a `rowid` of `8`. Then we will `pop()` a message and save it in a variable called `task`. The tasks are returned as dictionaries.

```python
q.put("hello")
q.put("world")
q.put("foo")
q.put("bar")

# 8 <- ID of the last row modified

task = q.pop()

assert task["message"] == "hello"
```

### Peek a message

With the `q.peek()` method you can have a look at the next message to be processed. The method will return the message, but it won't `pop` it from the queue. Since we have already popped the `"hello"` message, the `peek()` method will return the `"world"` message.

```
q.peek()


#    {'message': 'world',
#     'message_id': '44cbc85f12b62891aa596b91f14183e5',
#     'status': 0,
#     'in_time': 1612711138,
#     'lock_time': None,
#     'done_time': None}


# next one that is free
assert q.peek()["message"] == "world"

# status = 0 = free
assert q.peek()["status"] == 0
```

Now we'll go back to the message we previously popped from the queue. We will mark it as done with the `q.done(message_id)` method. After that, we can use the `q.get(message_id)` method to check it has been marked as done (`'status' = 2`)

```
task["message"], task["message_id"]

# ('hello', 'c9b9ef76e3a77cc66dd749d485613ec1')

q.done(task["message_id"])

# 8 <- ID of the last row modified

q.get(task["message_id"])

#    {'message': 'hello',
#     'message_id': 'c9b9ef76e3a77cc66dd749d485613ec1',
#     'status': 2,    <---- status is now 2 (DONE)
#     'in_time': 1612711138,
#     'lock_time': 1612711138,
#     'done_time': 1612711138}


already_done = q.get(task["message_id"])

# stauts = 2 = done
assert already_done["status"] == 2
```

### Message timing data

We can use the timing data that is automatically created during messages create/lock/mark as done steps.

```python
in_time = already_done["in_time"]
lock_time = already_done["lock_time"]
done_time = already_done["done_time"]

assert done_time >= lock_time >= in_time

print(
    f"Task {already_done['message_id']} took {done_time - lock_time} seconds to get done and was in the queue for {done_time - in_time} seconds"
)

# Task c9b9ef76e3a77cc66dd749d485613ec1 took 0 seconds to get done and was in the queue for 0 seconds
```

### Check queue size

We can get the queue size using the `q.size()` method. It will ignore the finished items, so the real number of rows in the SQLite database can be bigger than the number returned.

To remove the messages marked as done (`'status' = 2`), use the `q.prune()` method. This will remove those messages **permanently**.

```python
assert q.qsize() == 7

next_one_msg = q.peek()["message"]
next_one_id = q.peek()["message_id"]

task = q.pop()

assert task["message"] == next_one_msg
assert task["message_id"] == next_one_id

# remove finished items
q.prune()

print(q)


#    SQLQueue(Connection='sqlite3.Connection(...)', items=[{'done_time': None,
#      'in_time': 1612711137,
#      'lock_time': 1612711137,
#      'message': 'hello',
#      'status': 1,
#      'message_id': '7da620ac542acd76c806dbcf00218426'},
#     {'done_time': None,
#      'in_time': 1612711137,
#      'lock_time': 1612711137,
#      'message': 'world',
#      'status': 1,
#      'message_id': 'a593292cfc8d2f3949eab857eafaf608'},
#     {'done_time': None,
#      'in_time': 1612711137,
#      'lock_time': 1612711137,
#      'message': 'foo',
#      'status': 1,
#      'message_id': '17e843a29770df8438ad72bbcf059bf5'},
#     ...
```

### Set a max queue size

If you specify a `maxsize` when you initialize the queue, it will create a trigger that will raise an error when that size is reached. In Python, it will rise an `sqlite3.IntegrityError` exception.

```python
from string import ascii_lowercase, printable
from random import choice


def random_string(string_length=10):
    """Generate a random string of fixed length """
    return "".join(choice(ascii_lowercase) for i in range(string_length))

q = SQLQueue(":memory:", maxsize=50)

for i in range(50):

    q.put(random_string(20))

assert q.qsize() == 50
```

An error is raised when the queue has reached its size limit.

```python
import sqlite3

try:
    q.put(random_string(20))
except sqlite3.IntegrityError: # max len reached
    print("test pass")

# test pass
```

When we `pop` and item we can add another one. Take into account that `q.put()` will return the `rowid` of the latest inserted message, it does **not** represent the current queue size.

```python
q.pop()

#    {'message': 'aktabyjadzrsohlitnei',
#     'message_id': '08b201c31099a296ef37f23b5257e5b6'}

# Now we can put another message without error
q.put("hello")

# 51
```

### Empty queues

We can check if a queue is empty using the `q.empty()` method.

```python
# Check if a queue is empty
assert q.empty() == False

q2 = SQLQueue(":memory:")

assert q2.empty() == True
```

## Benchmarks

Inserting items in the queue.

```python
import gc
```

In-memory SQL queue

```python
q = SQLQueue(":memory:", maxsize=None)

gc.collect()

# %%timeit -n10000 -r7

q.put(random_string(20))

# 40.2 µs ± 12 µs per loop (mean ± std. dev. of 7 runs, 10000 loops each)

q.qsize()

# 70000
```

Standard python queue.

```python
from queue import Queue

q = Queue()

gc.collect()

# %%timeit -n10000 -r7

q.put(random_string(20))

# 21.9 µs ± 3.57 µs per loop (mean ± std. dev. of 7 runs, 10000 loops each)
```

Persistent SQL queue

```python
q = SQLQueue("test.queue", maxsize=None)

gc.collect()

# %%timeit -n10000 -r7

q.put(random_string(20))

# 161 µs ± 5.36 µs per loop (mean ± std. dev. of 7 runs, 10000 loops each)

assert q.conn.isolation_level is None
```

Creating, popping and setting messages as done.

```python
q = Queue()

gc.collect()

# %%timeit -n10000 -r7

tid = random_string(20)

q.put(tid)

q.get()

q.task_done()

# 27 µs ± 3.69 µs per loop (mean ± std. dev. of 7 runs, 10000 loops each)

q = SQLQueue(":memory:", maxsize=None)

gc.collect()

# %%timeit -n10000 -r7

tid = random_string(20)

q.put(tid)

task = q.pop()

q.done(task["message_id"])

# 80.2 µs ± 4.02 µs per loop (mean ± std. dev. of 7 runs, 10000 loops each)
```

## SQLite version `3.35.0`

SQLite introduced the RETURNING clause in version `3.35.0`. If the SQLite used in you application supports it, the `RETURNING` clause will be used. The RETURNING clause makes message `pop`'ing a lot faster:

```python
from litequeue import SQLQueue
import gc

from string import ascii_lowercase, printable
from random import choice


def random_string(string_length=10, fuzz=False, space=False):
    """Generate a random string of fixed length"""
    letters = ascii_lowercase
    letters = letters + " " if space else letters
    if fuzz:
        letters = printable
    return "".join(choice(letters) for i in range(string_length))

q = SQLQueue("pop_bench.db", maxsize=None)

###
# RETURNING
###
q.pop = q._pop_returning

gc.collect()

for _ in range(10000):
    tid = random_string(60)

    q.put(tid)

# benchmark block
for _ in range(8000):
    task = q.pop()

# time: 2.15 s


q = SQLQueue("pop_bench.db", maxsize=None)

###
# custom locking logic in a transaction
###
q.pop = q._pop_transaction

gc.collect()

for _ in range(10000):
    tid = random_string(60)

    q.put(tid)


# benchmark block
for _ in range(8000):
    task = q.pop()

# time: 9.08 s
```

## Disclaimer

I'm still designing the internal structure of litequeue, the messages metadata and how they are created / locked / deleted, so changes can be expected. However, the main functionality and the exposed API of `put()` / `pop()` / `done()` / `get()` should stay the same. The changes will be mostly internal or adding new methods to the queue. Feedback is welcome!

## Alternatives

- [Huey](https://github.com/coleifer/huey): Huey is a task queue implemented in Python, with multiple backends (Redis/SQLite/in-memory). Huey is a more "complete" task queue, it includes a lot of functionality that is missing from `litequeue`. The scope of Huey is much bigger, it lets you decorate functions, run tasks periodically, etc. `litequeue` tries to "just" be a primitive queue implementation on which to build other tools. Even though it's written in Python, `litequeue` is easy to port to other programming languages and have multiple processes interact with the same persistent queue.
