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
| `rtl/`           | RTL development and functional verification, SystemVerilog source files, testbenches, and verification vectors.         |
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

* **Python Reference Model ([`src/'](./src/))** implements the floating-point reference model and fixed-point utilities.
* **RTL Implementation ([`rtl/`](./rtl))** contains the hardware implementation, verification testbenches, and simulation vectors.
* **Development Utilities ([`scripts/`](./scripts/))** provide helper functions and automation for common development workflows.
* **Design Exploration ([`notebooks/`](./notebooks/))** contains notebooks used during algorithm development and validation.
* **FPGA Project ([`vivado/`](./vivado/))** contains the Vivado project used for synthesis and implementation.
* **Pixi Configuration ([`pixi.toml`](./pixi.toml))** defines the project's development environment, dependencies, tasks, and workspace configuration.
* **Python Project Configuration ([`pyproject.toml`](./pyproject.toml))** defines the Python package metadata, build system, and project configuration.


## Project Status

The repository contains a complete floating-point Python reference implementation of
the OTFS transceiver together with a partially completed SystemVerilog RTL
implementation. The current focus of future development is completing the receiver
RTL, improving the fixed-point implementation using the quantization study, and
extending the verification infrastructure.

## Project Status & Roadmap \#(pls free to add to this section if required)

- [x] Python Reference Model
    - [x] Transmitter
        - [x] Modulization
    - [ ] Channel Model
        - [ ] Modulization
    - [ ] Receiver
        - [ ] Modulization
    - [x] End-to-End Validation

- [ ] Fixed-Point Quantization
    - [x] Quantization framework
    - [x] Design-space exploration
    - [x] Initial fixed-point implementation
    - [ ] Migrate to recommended precision
    - [ ] Optimize stage-specific word lengths
    - [ ] Improve numerical accuracy

- [ ] RTL Transmitter
    - [x] Gray-coded 16-QAM Mapper
    - [x] Delay-Doppler Grid Loader
    - [x] ISFFT
    - [x] IFFT
    - [x] Cyclic Prefix Inserter
    - [ ] Top-level integration
    - [ ] Timing optimization
    - [ ] Resource optimization

- [ ] RTL Receiver
    - [x] Cyclic Prefix Remover
    - [x] FFT
    - [ ] SFFT
    - [ ] Channel Equalizer
    - [ ] QAM Demapper
    - [ ] Receiver integration
    - [ ] End-to-End Verification

- [ ] FPGA Development
    - [x] Vivado project
    - [x] RTL synthesis
    - [x] Sythesis
    - [ ] Bitstream generation
    - [x] FPGA programming
    - [ ] Hardware characterization
    - [ ] Performance evaluation

- [ ] Development Workflow
    - [x] Pixi environment
    - [x] Python packaging
    - [ ] Icarus Verilog automation
    - [ ] Vivado Tcl integration
    - [ ] Source-only project generation
        - [ ] Automated synthesis
        - [ ] Automated implementation
        - [ ] Automated bitstream generation
    - [ ] Reproducible build flow
    - [ ] Helper utilities
    - [ ] Quick Start Guide

- [ ] Documentation
    - [x] Repository overview
    - [x] Repository layout
    - [x] License
    - [ ] Architecture guide
    - [ ] Module documentation
    - [ ] Verification guide
    - [ ] Development guide

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

