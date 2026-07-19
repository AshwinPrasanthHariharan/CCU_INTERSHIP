# OTFS FPGA Accelerator

**OTFS FPGA Accelerator** is an open research project providing a Python
reference implementation and a SystemVerilog RTL implementation of an
orthogonal time frequency space (OTFS) transceiver for FPGA-based
acceleration. The repository contains the full development flow, from
algorithm modelling and fixed-point quantization to RTL implementation,
simulation and verification with Python generated reference vectors.

As a collaborative and extensible codebase, it provides a foundation for
ongoing development, allowing future contributors to extend the
transmitter, implement receiver-side processing, implement FPGA
deployment, and evaluate new architectures and optimizations.


## Repository Layout

```text
.
├── notebooks/
├── rtl/
├── scripts/
├── src/
├── vivado/
├── README.md
├── LICENSE.txt
├── pixi.toml
├── pixi.lock
└── pyproject.toml
```

| Path             | Description                                                                                                             |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `notebooks/`     | Jupyter notebooks for algorithm exploration, validation and development of the OTFS transmitter.                        |
| `rtl/`           | RTL development and functional verification SystemVerilog source files, testbenches, and verification vectors.         |
| `scripts/`       | Development utilities and helper scripts used to ease common development tasks and Vivado workflows.                   |
| `src/`           | Python source code for the OTFS reference model implementation and fixed point quantization utilities.                 |
| `vivado/`        | Vivado project files used for FPGA synthesis, implementation, and project management.                                  |
| `README.md`      | Project Overview, Repository Structure and Onboarding Guide                                                            |
| `LICENSE.txt`    | Software license and copyright information.                                                                             |
| `pixi.toml`      | Pixi project configuration describing environments, dependencies, and development tasks.                                |
| `pixi.lock`      | Locked dependency versions to ensure a reproducible development environment.                                            |
| `pyproject.toml` | Python package configuration, build metadata, and project information.                                                  |

### Directory Organization

The repository is organized into independent components:

* **Python Reference Model (`src/`)** implements the floating-point reference model and fixed-point utilities.
* **RTL Implementation (`rtl/`)** contains the hardware implementation, verification testbenches, and simulation vectors.
* **Development Utilities (`scripts/`)** provide helper functions and automation for common development workflows.
* **Design Exploration (`notebooks/`)** contains notebooks used during algorithm development and validation.
* **FPGA Project (`vivado/`)** contains the Vivado project used for synthesis and implementation.


 ## Contributing

This repository serves as the primary development repository for the OTFS
FPGA Accelerator project. Contributors should follow the existing project
structure, coding conventions, and documentation style when extending the
codebase.

When introducing new functionality:

* Document new modules, scripts, and workflows.
* Maintain consistency between the Python reference model and the RTL
  implementation where applicable.
* Include or update verification vectors and testbenches for RTL changes.
* Verify functionality before committing changes.
* Use clear and descriptive commit messages.



## License

This project is licensed under the MIT License.

Copyright © 2026 National Chung Cheng University, Department of Communications Engineering.

For the complete license terms, see the [`LICENSE`](./LICENSE) file.

## Acknowledgements

This project was initiated during a research internship at the
Department of Communications Engineering,
National Chung Cheng University.

The initial implementation was developed by
**Ashwin Prasanth Hariharan** under the supervision of
**Prof. Jen-Yi Pan**.

