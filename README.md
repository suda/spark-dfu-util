# Support for flashing Spark Core using dfu-util

Formerly **Atom Spark Core**. This package allows quick flash of [Spark Core](http://spark.io/) using dfu-util.

![Spark DFU Util](http://cl.ly/image/1U2N3R2L3x39/Screen%20Recording%202014-10-06%20at%2006.36%20pm.gif)

# Features

* Uploading code via USB
* DFU mode instruction dialog
* Upload progress bar
* **Currently working only on OS X**

# Usage

* Use command palette and search for `Spark Dfu Util: Flash`

or

* `F6` to flash

Package will search for **.bin** file in project's directory and flash latest one.

For .ino syntax highlighting and snippets, use [language-arduino](https://atom.io/packages/language-arduino).

# Bundled software

* dfu-util **0.7**

# What happened to compiling locally?

With very fast development of [Core Firmware](https://github.com/spark/firmware) this package
always lagged behind with old code. Also bundling **gcc** made it very heavy. As a suggested method
use [Spark CLI](https://github.com/spark/spark-cli) and `spark compile .` command (you can execute it
right from Atom using [run-command](https://atom.io/packages/run-command) package).

# Todo

* Support for Windows and Linux
