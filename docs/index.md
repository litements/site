# Litements

## What

Litements is a set of structures/components built on top of SQLite, each of those is called a module inside the docs. Currently there's a [queue](/queue), a [dictionary](/dictionary) and a [counter](/counter), but there are more modules coming. Each module/package is installed separately.

## Why

SQLite is the most deployed database in the world, but it's oftend looked as something just for mobile development, something to use as an aaplication file format or for servers with little or not traffic. However, SQLite is incredibly powerful. It can scale to thousands of concurrent users with the correct settings, the databse does not need a web server on top, and it's just a file in your disk (3 files if [WAL mode](https://sqlite.org/wal.html) is activated, which is the case of this library).

Since it's a file on your disk, it can be used from different processes, or just copied between hosts for processing.

The idea behind `litements` is to implement a set of common programmin patterns/structures on top of SQLite. That way you can interact with the databaseses and using those patterns as you want. The library is currently written in Python, but all the modules are very simple (just a single `.py` file) and are easily ported between programming languages.

For example, one of the modules implement a queue you can use for message passing or task processing. By using that, you can implement a queue as a file on disk, that queue can be used from any process written in any programming language as long as it can use SQLite (it's hard to find a programming language that can't interact with sqlite). So you can have a Python script writing messages to the queue and a Rust program processing them.

## Other info

* The modules are designed to work with string data (for example queue messages will always be strings). In some cases the encoding/decoding can be modified.
* The different structures create a database table if it does no exist, and modify some settings to make it as performant as possible. With that in mind, you can have both the [counter](/counter) and the [queue](/queue) module use the same database file.

## Performance settings

The different modules use this settings:

* 'WAL' journal mode
* isolation_mode = None
* Transactions are manually handled
* Set cache size to 64MB
* Set sync mode to 'NORMAL' (0)

Check the SQLite docs to learn more about those settings.

Some modules use SQLite functions that are only available in new versions, so it's recommended to run a modern SQLite version (at least version 3.24.0, released 2018-06-04). Many systems come with a default SQLite installation that is a bit outdated.

In Python you can use [pysqlite3](https://github.com/coleifer/pysqlite3).

All the modules accept either a filename or an already created sqlite connection. Apart from that, if you have pysqlite3 installed it will use that instead of the sqlite3 module from the standard library.

In other compiled programming languages, the sqlite libraries usually give you the option to compile with a specific sqlite version.

## Project status

The modules are currently in an early stage, so breaking changes may happen (those will be included in the docs). On the other hand, I'm currently using similar (probably even worse) patterns in production sites, so the currently availble modules should be usable as such.