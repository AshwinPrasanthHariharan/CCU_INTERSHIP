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
├── pyhton/src/
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
| `python/src/`           | Python source code for the OTFS reference model implementation and fixed point quantization utilities.                 |
| `vivado/`        | Vivado project files used for FPGA synthesis, implementation, and project management.                                  |
| `README.md`      | Project Overview, Repository Structure and Onboarding Guide                                                            |
| `LICENSE.txt`    | Software license and copyright information.                                                                             |
| `pixi.toml`      | Pixi project configuration describing environments, dependencies, and development tasks.                                |
| `pixi.lock`      | Locked dependency versions to ensure a reproducible development environment.                                            |
| `pyproject.toml` | Python package configuration, build metadata, and project information.                                                  |

### Directory Organization

The repository is organized into independent components:

* **Python Reference Model ([`python/src/'](./python/src/))** implements the floating-point reference model and fixed-point utilities.
* **RTL Implementation ([`rtl/`](./rtl))** contains the hardware implementation, verification testbenches, and simulation vectors.
* **Development Utilities ([`scripts/`](./scripts/))** provide helper functions and automation for common development workflows.
* **Design Exploration ([`notebooks/`](./notebooks/))** contains notebooks used during algorithm development and validation.
* **FPGA Project ([`vivado/`](./vivado/))** contains the Vivado project used for synthesis and implementation.
* **Pixi Configuration ([`pixi.toml`](./pixi.toml))** defines the project's development environment, dependencies, tasks, and workspace configuration.
* **Python Project Configuration ([`pyproject.toml`](./pyproject.toml))** defines the Python package metadata, build system, and project configuration.


## Project Status & Roadmap 
This roadmap is intended to evolve alongside the project and should be  
updated as development progresses.

- [x] Python Reference Model
    - [x] Transmitter
        - [x] Modularization
    - [ ] Channel Model
        - [ ] Modularization
    - [ ] Receiver
        - [ ] Modularization
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
    - [ ] Bitstream generation
    - [x] FPGA programming
    - [ ] Hardware characterization
    - [ ] Performance evaluation

- [ ] Development Workflow
    - [x] Pixi environment
    - [x] Python packaging
    - [x] Icarus Verilog automation
    - [ ] Vivado Tcl integration
        - [ ] Source-only project generation
        - [ ] Automated synthesis
        - [ ] Automated implementation
        - [ ] Automated bitstream generation
    - [ ] Reproducible build flow
    - [x] Helper utilities
    - [x] Quick Start Guide

- [ ] Documentation
    - [x] Repository overview
    - [x] Repository layout
    - [x] License
    - [ ] Architecture guide
    - [ ] Module documentation
    - [ ] Verification guide
    - [x] Development guide

## Development Notes

### Vivado Tcl Integration

The long-term objective is to transition the project from a GUI-managed
Vivado workflow to a fully source-driven workflow. The repository should
contain only RTL sources, constraints, Tcl scripts, and documentation.
Generated project files should be recreated automatically, enabling
reproducible builds, cleaner version control, and future CI/CD support.

### Fixed-Point Quantization

The current RTL uses an initial fixed-point representation developed
during the internship. Future work should migrate each processing stage
to the recommended precision identified during the quantization
design-space exploration to improve numerical accuracy while minimizing
hardware resource utilization.

### RTL Receiver

The floating-point Python receiver serves as the architectural reference
for the receiver RTL implementation. New RTL modules should maintain
functional equivalence with the Python model and include corresponding
verification testbenches.

## Quick Start

### Platform Support

The project is developed and validated on Linux. Reproducibility of the
development, simulation, and verification workflow is guaranteed only on
Linux.

- **Linux:** Fully supported and recommended.
- **Windows:** The recommended workflow is to use WSL2 with a Linux
  distribution (e.g., Ubuntu). Contributions to support a native Windows
  development workflow are welcome.
- **macOS:** The Python reference model is expected to function, but the
  complete FPGA development workflow has not been validated. Native
  macOS support is currently unsupported.
- **Containerization:** Containerized development environments (e.g.,
  Docker or Dev Containers) are encouraged to improve portability and
  reproducibility across supported platforms. Contributions in this area
  are welcome.

### Prerequisites
Install the following software before setting up the development
environment.

#### Linux

- Git
- Pixi
- Icarus Verilog(optional, provided viva pixi)
- GTKWave (optional,also availabe via pixi)
- Xilinx Vivado (optional, for FPGA development)

#### Windows

The recommended workflow is to use **Windows Subsystem for Linux 2
(WSL2)** with a Linux distribution such as Ubuntu.

Before continuing, install and configure WSL2 by following the official
Microsoft installation guide:

- https://learn.microsoft.com/windows/wsl/install

Once WSL2 is installed, follow the Linux installation instructions from
within the WSL environment.

#### macOS

The Python reference model is expected to function; however, the FPGA
development workflow has not been validated. Native macOS support is
currently unsupported.

### Clone the Repository

#### 1. Configure Git Authentication

Choose one of the following authentication methods.

- **SSH (Recommended)**
  - https://docs.github.com/en/authentication/connecting-to-github-with-ssh

- **HTTPS**
  - https://docs.github.com/en/get-started/git-basics/about-remote-repositories

#### 2. Clone the Repository

Using **SSH** (recommended):

```bash
git clone git@github.com:<organization>/<repository>.git
```

Or using **HTTPS**:

```bash
git clone https://github.com/<organization>/<repository>.git
```

#### 3. Enter the Project Directory

```bash
cd <repository>
```

#### 4. Verify the Repository

```bash
git remote -v
git status
```
Expected output:

```text
On branch <default-branch>
Your branch is up to date with 'origin/<default-branch>'.

nothing to commit, working tree clean
```

### Create the Development Environment

The project uses **Pixi** for dependency and environment management.

#### 1. Install Pixi

Follow the official Pixi installation guide:

- https://pixi.sh/latest/

**Windows users:** Install Pixi from within **WSL2** using the Linux
installation instructions. Native Windows is not the recommended
development environment.

#### 2. Install the Project Environment

From the project root, create the development environment:

```bash
pixi install
```

#### 3. Enter the Development Environment

```bash
pixi shell
```

Upon entering the Pixi shell, the development environment is configured
automatically. This includes:

- Project dependencies
- Development tools
- Project scripts
- Vivado environment (if installed)

#### 4. Verify the Environment

```bash
isim --list
```

If the available testbenches are listed successfully, the development
environment has been configured correctly.


### Running Simulations

List all available testbenches:

```bash
isim --list
```

Run a simulation:

```bash
isim <testbench>
```

For example:

```bash
isim tb_qam_mapper
```

Generate and automatically open simulation waveforms:

```bash
isim tb_qam_mapper --waves
```

Remove intermediate compilation artifacts after the simulation
completes:

```bash
isim tb_qam_mapper --clean
```

The `--clean` option removes all generated build artifacts while
preserving waveform (`.vcd`) files for post-simulation analysis.

Display the available command-line options:

```bash
isim --help
```

> **Note:** Waveform viewing requires GTKWave to be installed.

### Launching the Vivado Project

The Vivado environment is configured automatically when entering the
Pixi shell, provided that Vivado has been installed correctly.

Launch the project:

```bash
vivado
```

The repository currently includes a Vivado project (`.xpr`) to simplify
development and onboarding.

To remove generated Vivado project artifacts while preserving the
project sources, use:

```bash
clean_vivado
```

This utility provides a temporary cleanup workflow. Future development
will replace the project-based workflow with a fully source-driven Tcl
flow capable of automatically recreating the Vivado project from the RTL
sources, constraints, and repository configuration.


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

