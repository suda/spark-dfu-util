# Support for Spark Core development in Atom

This package contains all necessary tools (like cross compiler and dfu-util) for developing [Spark Core](http://spark.io/) projects without using cloud IDE.

![A screenshot of your spankin' package](http://cl.ly/image/2J142C1K0r0V/atom-spark-core.gif)

# Features

* Building Arduino projects
* Build log with highlighted output
* Uploading code via USB
* DFU mode instruction dialog
* Upload progress bar
* **Currently working only on OS X**

# Usage

**This package only works with projects containing an .ino file.**

* Use command palette and search for `Atom Spark Core: Build` or `Atom Spark Core: Flash`

or

* `F5` to build
* `F6` to flash

For .ino syntax highlighting and snippets, use [language-arduino](https://atom.io/packages/language-arduino).

# Bundled software

* make **3.82**
* dfu-util **0.7**
* gcc-arm-none-eabi **4.8-2014-q2-update**
* core-firmware @ [106aae0b1cc242c52271f34e4ded9bd332b1ac6d](https://github.com/spark/core-firmware/tree/106aae0b1cc242c52271f34e4ded9bd332b1ac6d)
* core-communication-lib @ [aef1c7f352e91187999e86b0abd88156be0715c3](https://github.com/spark/core-communication-lib/tree/aef1c7f352e91187999e86b0abd88156be0715c3)
* core-common-lib @ [9e611a4e58ad82921a9f6e966f887b8d4cb25b17](https://github.com/spark/core-common-lib/tree/9e611a4e58ad82921a9f6e966f887b8d4cb25b17)

# Todo

* Support for Windows and Linux
* Suppressing core-firmware warnings
* Downloading binaries (gcc/make/dfu-util) from server
* Integration with Spark CLI
* Spark Cloud variables and commands panel
* Support for libraries
* Built-in firmware reference
* Built-in examples
