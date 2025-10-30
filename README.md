<!-- :toc: macro -->
<!-- :toc-title: -->
<!-- :toclevels: 99 -->

# build <!-- omit from toc -->

> Layouts modules, compiles them in parallel, links a main executable, and optionally builds tests or hot-reloadable shared objects.

## Table of Contents <!-- omit from toc -->

* [General Information](#general-information)
* [Technologies Used](#technologies-used)
* [Features](#features)
* [Setup](#setup)
* [Usage](#usage)
* [Project Status](#project-status)
* [Room for Improvement](#room-for-improvement)
* [License](#license)

## General Information

This repository is a starting point for projects that need a simple modular build system driven by Bash.
Each module lives in its own folder and exports what to compile and what to expose via a `config.sh`.
The top-level `build.sh` discovers modules, sets compiler flags, runs per-module builds in parallel, links the final executable, and optionally builds tests or creates hot-reloadable `.so` files.

## Technologies Used

<!--
GNU bash, version 5.3.3(1)-release (x86_64-pc-linux-gnu)
Copyright (C) 2025 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>

This is free software; you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
-->
* GNU bash 5.3.3
<!--
clang version 21.1.4
Target: x86_64-pc-linux-gnu
Thread model: posix

Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
See https://llvm.org/LICENSE.txt for license information.
-->
* clang 21.1.4
* gtest - 1.17.0-1
<!--
Copyright (C) 2002-2007 Andrew Tridgell
Copyright (C) 2009-2025 Joel Rosdahl and other contributors
-->
* ccache - 4.12.1
* fd - 10.3.0
* pkg-config - 2.5.1
* llvm-ar - 21.1.4

## Features

* Modular layout. Each module lives in its own folder with `include/`, `src/`, optional `tests/` and a `config.sh` contract that exports what to compile and what to expose.
* Parallel module builds. Modules are built in background jobs to use all cores.
* Multiple build types. Supports `DEBUG`, `RELEASE`, `PROFILE`, and `TESTS` with corresponding compiler flags and `-D` defines.
* Hot reload. Optionally convert archives to `.so` and link with `rpath`. `HOT_RELOAD` define exposed to sources.
* Build cache. Uses `ccache` by default and can be disabled per-run.
* Rebuild controls to force rebuilds.
* Sanitizers and static analysis. Toggle Address/ UB/ Leak sanitizers and `scan-build`.
* Test packaging. Builds test artifacts and a test executable when `Tests` is selected.
* External libs supported via `pkg-config`. **cflags** and **link** flags injected automatically.
* Configurable toolchain and flags. Compiler, link flags, include paths and defines are environment driven.
* Stripping and section removal. Optional objcopy/ strip steps to reduce binary size.
* Colored status output for build steps and module lists.

## Setup

`Dockerfile` is available.

## Usage

Make the script executable and run:

```bash
chmod +x build.sh

./build.sh -d       # Debug
./build.sh -r       # Release
./build.sh -p       # Profile
./build.sh -t       # Build tests
```

Combine flags. Example: build release, strip executable, disable cache:

```bash
./build.sh -ric
```

Force rebuild of all parts:

```bash
./build.sh -au
```

## Project Status

Project is: _in progress_.

## Room for Improvement

* Wrap repeating parts in functions

## License

This project is open source and available under the
[GNU Affero General Public License v3.0](LICENSE).
