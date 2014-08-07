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
* core-firmware @ [c0d1211b0960eba2bb68b9a602be62edd8a53ccc](https://github.com/spark/core-firmware/tree/c0d1211b0960eba2bb68b9a602be62edd8a53ccc)
* core-communication-lib @ [6dd05041452b180aeed1c6a7322069133c9d3f0f](https://github.com/spark/core-communication-lib/tree/6dd05041452b180aeed1c6a7322069133c9d3f0f)
* core-common-lib @ [3283e75870ae3a7a5256c8944313644f821dc89b](https://github.com/spark/core-common-lib/tree/3283e75870ae3a7a5256c8944313644f821dc89b)

# Todo

* Support for Windows and Linux
* Suppressing core-firmware warnings
* Downloading binaries (gcc/make/dfu-util) from server
* Integration with Spark CLI
* Spark Cloud variables and commands panel
* Support for libraries
* Built-in firmware reference
* Built-in examples
