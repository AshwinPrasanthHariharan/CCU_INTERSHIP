# 6G OTFS FPGA Baseband Design - Lab Notebook

**Intern:** Ashwin Prasanth Hariharan  
**Timeline:** May 18, 2026 – July 13, 2026 (8 Weeks)

Welcome to my digital lab notebook for the FPGA-based evaluation of 6G waveforms.  
This repository tracks my daily progress, code models, and RTL architecture implementations.

---

### 🔹 Week 0-1: Literature Review & Mathematical Modeling

*Focus: Mastering OTFS fundamentals and building the Python floating-point reference model.*

---

### **Day 1 (May 18): Foundations of 1D vs 2D Signals & understanding Matrix D**

#### **Objective:**

1. Revisit 1-D concepts of DFT and DTFT and how they translate to 2-D.
2. Understand the difference between DFT and OTFS.
3. Understand the Delay–Doppler information matrix ($D$).

##### 1. DFT (the frequency domain)

Let $\mathbf{x}[n]$ be a discrete-time signal:  
Then its DTFT $\mathbf{X}[e^{j\omega}]$ is given by

$$
\mathbf{X}(e^{j\omega}) = \sum_{n=-\infty}^{\infty} \mathbf{x}[n] e^{-j\omega n}
$$

##### 2. The Transition to the Discrete Fourier Transform (DFT)

Because digital hardware cannot compute or store an infinite, continuous frequency spectrum $X(e^{j\omega})$, the DFT samples the DTFT at $N$ evenly spaced discrete frequency bins ($\omega_k = \frac{2\pi k}{N}$).

For a finite-length vector $\mathbf{x}$ of length $M$, this operation simplifies into a clean matrix-vector multiplication:

$$
\mathbf{X} = \mathbf{W} \cdot \mathbf{x}
$$

Where $\mathbf{W}_M$ is an $M \times M$ square transformation matrix built using the standard symmetric twiddle factors:

$$
W_M = e^{-j\frac{2\pi}{M}}
$$

##### 3. Scaling 1-D DFT to 2-D DFT

When a signal varies across two separate dimensions simultaneously (like a 2D grid of pixels or spatial data), a standard 2-D DFT processes horizontal and vertical variations at the same time.

Mathematically, this is executed as a "matrix sandwich" by applying the 1-D DFT matrix twice. For an $M \times N$ matrix $\mathbf{D}$:

$$
\mathbf{X}_{2D} = \mathbf{W}_M \cdot \mathbf{D} \cdot \mathbf{W}_N
$$

- Multiplying by $\mathbf{W}_M$ from the **left** applies the 1-D transform down every individual **column**.
- Multiplying by $\mathbf{W}_N$ from the **right** applies the 1-D transform across every individual **row** (leveraging matrix symmetry where $\mathbf{W}^T = \mathbf{W}$).

##### 4. Understanding the Difference: Standard 2-D DFT vs. OTFS (ISFFT)

While a standard 2-D DFT runs a *forward* transform on both the rows and columns to map data completely from space to frequency, the OTFS transmitter relies on the **Inverse Symplectic Finite Fourier Transform (ISFFT)**.

The ISFFT converts your data from the Delay-Doppler domain into a Time-Frequency grid ($\mathbf{X}_{TF}$) using a hybrid matrix multiplication sandwich:

$$
\mathbf{X}_{TF} = \mathbf{W}_M \cdot \mathbf{D} \cdot \mathbf{W}_{inv, N}
$$

- **Left-Side Multiplication ($\mathbf{W}_M \cdot \mathbf{D}$):** Runs a forward 1-D DFT to transform the columns (moving the Delay domain into the Frequency domain).
- **Right-Side Multiplication ($\mathbf{D} \cdot \mathbf{W}_{inv, N}$):** Runs an *Inverse* 1-D DFT matrix ($\mathbf{W}_{inv}$, where the twiddle exponent flips to a positive sign: $e^{+j\frac{2\pi}{N}}$) to transform the rows (moving the Doppler domain into the Time domain).

##### 5. Deconstructing the Delay-Doppler Information Matrix ($\mathbf{D}$)

- **Physical Axes Mapping:** Matrix $\mathbf{D}$ is an $M \times N$ hardware storage layout. The $M$ rows correspond to discrete steps of **Time Delay** ($\tau$), which link directly to physical reflection distances. The $N$ columns correspond to discrete steps of **Doppler Shifts** ($\nu$), which link directly to user/reflector velocities.
- **The Elements:** The individual slots inside this grid are **not** raw binary bits. They hold **QAM symbols** (complex scalar coordinates like $1 + 1j$ or $-1 - 1j$).
- **The Frame Slicing Reality:** A massive data file (like a 42MB stream) cannot fit into a single matrix $\mathbf{D}$ at once. The file is sliced into separate chunks called **frames**. Each frame sequentially fills the $M \times N$ memory template, gets processed by the ISFFT engine, and streams out of the antenna pipeline.

##### 6. Isolating Column Vectors within the 2-D Grid Matrix

In digital hardware, an FPGA cannot compute a full 2-D matrix multiplication simultaneously without blowing up the resource budget. Physically, it processes the matrix **one column vector at a time**.

We can view the Delay-Doppler matrix $\mathbf{D}$ as a parallel array of $N$ independent column vectors standing side-by-side:

$$
\mathbf{D} = \begin{bmatrix} \mathbf{d}_0 & \mathbf{d}_1 & \mathbf{d}_2 & \dots & \mathbf{d}_{N-1} \end{bmatrix}
$$

An isolated vertical column vector $\mathbf{d}_n$ represents a single discrete Doppler bin containing all $M$ delay rows:

$$
\mathbf{d}_n = \begin{bmatrix} d_{0,n} \\ d_{1,n} \\ d_{2,n} \\ \vdots \\ d_{M-1,n} \end{bmatrix}
$$

When the transmitter calculates $\mathbf{W}_M \cdot \mathbf{D}$, it streams each column vector $\mathbf{d}_n$ through a single, pipelined 1-D FFT/IFFT core sequentially, storing the intermediate outputs in a RAM buffer to flip the matrix rows sideways for the next stage.

---

### **Day 2 (May 19): Foundational Understanding of The Algorithm**

#### **Objectives**

1. **Bitstream Ingestion & Allocation:** Understand how to parse a raw 1D serial bitstream into 4-bit nibbles and map them into complex coordinate scalars using a noise-resilient 16-QAM Gray Code assignment.
2. **Geometric Matrix Structural Framing:** Formulate the physical layout of the Delay-Doppler Matrix D, establishing how its rows map to environmental reflections (Delay/Distance) and columns map to target mobility parameters (Doppler/Velocity).
3. **Domain Transform Orchestration (ISFFT):** Execute the 2D "matrix transform sandwich" ($\mathbf{W}_M \cdot \mathbf{D} \cdot \mathbf{W}_N^{-1}$) to rotate abstract environmental coordinates into standard multi-carrier Time-Frequency coordinates ($\mathbf{X}_{TF}$).
4. **Hardware Stride Optimization Design:** Analyze memory-mapping bottlenecks associated with row-major block writes versus vertical column reads to plan high-throughput, stall-free BRAM transposition architectures.

<div align="center">
<img src="./assets/fig1.jpg" alt="OTFS Baseband Processing Block Diagram Pipeline" width="550"/>
<br/>
<b>Figure 1: OTFS Baseband Processing Block Diagram Pipeline</b>
<br/>
</div>

##### 1. Bitstream Ingestion & 16-QAM Gray Mapping

The input interface ingests a raw, flat 1D serial binary bitstream $\mathbf{b}$. The exact frame capacity required to perfectly populate a single transmission block is determined by the dimensions of the matrix grid and the modulation depth:

$$
\text{Total Bits Per Frame} = M \times N \times \log_2(M_{\text{QAM}})
$$

- **Data Partitioning:** For a 16-QAM architecture, the stream is parsed sequentially into discrete 4-bit segments (nibbles) $[b_0, b_1, b_2, b_3]$.

- **Gray-Coded Constellation Mapping:** The nibble is split into an In-Phase bit pair $(b_0b_1)$ and a Quadrature bit pair $(b_2b_3)$. They are mapped into physical coordinate scalars using a Gray code mapping rule. This arrangement ensures that adjacent spatial constellation coordinates differ by a Hamming distance of exactly 1 bit, drastically reducing bit-error rates (BER) if noise causes a received state to drift into an adjacent decision boundary:

$$
\text{Mapping Array: } \mathbf{00} \rightarrow -3, \quad \mathbf{01} \rightarrow -1, \quad \mathbf{11} \rightarrow +1, \quad \mathbf{10} \rightarrow +3
$$

- **Output Vector:** Each 4-bit block results in a complex coordinate point:

$$
s = s_I + j \cdot s_Q
$$

##### 2. Geometric Data Allocation in Matrix $\mathbf{D}$

The mapped complex QAM symbols are written row-by-row (**row-major mapping**) into local Block RAM allocation grids to construct the **Delay-Doppler Matrix $\mathbf{D} \in \mathbb{C}^{M \times N}$**:

$$
\mathbf{D} =
\begin{bmatrix}
D[0,0] & D[0,1] & \cdots & D[0,N-1] \\
D[1,0] & D[1,1] & \cdots & D[1,N-1] \\
\vdots & \vdots & \ddots & \vdots \\
D[M-1,0] & D[M-1,1] & \cdots & D[M-1,N-1]
\end{bmatrix}
$$

- **Physical Channel Properties:** Unlike standard multi-carrier modulations (like 4G/5G OFDM), Matrix $\mathbf{D}$ does not represent time or frequency yet. It represents the physical geometry of the wireless environment:

  - **Rows ($M$ Delay bins):** Represent physical propagation delays ($\tau$), corresponding directly to echo paths and target distances in the field.
  - **Columns ($N$ Doppler bins):** Represent physical frequency shifts ($\nu$), corresponding directly to target mobility and relative velocities.

##### 3. Domain Transformation via the ISFFT Sandwich

To prepare these environmental coordinates for physical transmission, the matrix must be rotated into the traditional time-frequency domain. This is achieved by computing the Inverse Symplectic Finite Fourier Transform (ISFFT):

$$
\mathbf{X}_{TF} = \mathbf{W}_M \cdot \mathbf{D} \cdot \mathbf{W}_N^{-1}
$$

- **The Transform Mechanics:**

  1. $\mathbf{W}_M \in \mathbb{C}^{M \times M}$ is a normalized forward DFT matrix multiplied from the **left**. This processes the data vertically down the columns, translating the **Delay axis into a Frequency Subcarrier axis**.

  2. $\mathbf{W}_N^{-1} \in \mathbb{C}^{N \times N}$ is a normalized inverse DFT matrix multiplied from the **right**. This processes the data horizontally across the rows, translating the **Doppler axis into a discrete Time Slot axis**.

- **Energy Conservation:** To guarantee mathematical stability and avoid numeric overflow during fixed-point RTL processing, the forward and inverse transform matrices are scale-normalized by $\frac{1}{\sqrt{M}}$ and $\frac{1}{\sqrt{N}}$ respectively, preserving Parseval's energy invariance:

$$
\|\mathbf{X}_{TF}\|_F^2 = \|\mathbf{D}\|_F^2
$$

##### 4. Hardware Memory Bottleneck Analysis & Stride Design

During design formulation, a critical hardware pipelining conflict was identified between Stage 1 and Stage 2:

- **The Conflict:** The incoming bitstream populates memory blocks sequentially in a row-major structure. However, the first stage of the 2D transform sandwich ($\mathbf{W}_M \cdot \mathbf{D}$) mandates reading data vectors vertically down column indices.

- **The Penalty:** Accessing a standard single-port BRAM row-by-row with an address stride of $N$ breaks the memory's natural sequential burst cycles. This creates severe address-generation delays and causes pipeline starvation stalls at the input registers of the 1D FFT core.

- **RTL Architecture Solution:** To ensure continuous, stall-free processing at full streaming hardware speeds, the system must implement a dual-bank **Ping-Pong Transposition Buffer**. While Bank 0 is being written to row-by-row by the QAM ingestion engine, Bank 1 is simultaneously read out column-by-column by the 1D FFT core. On the next frame boundary, their address routing lines swap instantly
---

### **Day 3 (May 20, 2026): Deep-Dive Architecture – The Heisenberg Transform Engine & Sinc Pulse-Shaping**

#### **Objectives:**

1. **Deconstruct the Heisenberg Transform Module:** Master the step-by-step hardware process of taking a static 2D Time-Frequency grid ($\mathbf{X}_{TF}$) and collapsing it column-by-column into a 1D timeline wave.
2. **Isolate Pulse-Shaping Physics:** Understand why instantaneous digital voltage jumps cause massive frequency noise (channel bleed) and how continuous interpolation filters resolve it.
3. **Formulate Sinc Orthogonality:** Analyze how the zero-crossing math of a sinc function allows overlapping pulses to travel together without causing Inter-Symbol Interference (ISI).

##### 1. Functional Mechanics of the Heisenberg Transform

The Heisenberg Transform is the operational core that acts as a multi-carrier wave synthesizer. It sits right at the output boundary of your digital processing pipeline. Its sole job is to read your 2D Time-Frequency data matrix ($\mathbf{X}_{TF}$) from memory and convert it into a single, flowing continuous stream of time-varying complex voltages $s(t)$ destined for the physical antenna wire.

The engine works chronologically, processing the matrix columns one by one from left to right (from Time Slot $n = 0$ to $N-1$):

<div align="center">
  <img src="./assets/fig2.jpg" alt="IFFT and Pulse Shaping Stage in Multi-carrier Modulator Architecture" width="500"/>
  <br/>
  <b>Figure 2: Pipelined Column-Streaming Multi-Carrier Generation Flow</b><br>
  (BPSK is used here not QAM)
</div>

- **Step A: Vertical Column Stride Extraction:** The engine isolates Column $n$ from the $\mathbf{X}_{TF}$ matrix. This vertical column contains $M$ unique complex values. Each row element $m$ represents a specific radio frequency lane (a subcarrier tone). The number itself tells the transmitter how to configure that specific subcarrier: its size controls the tone's volume (amplitude) and its complex angle controls where the wave begins its rotation (phase).

- **Step B: Multi-Carrier Mixing via 1D IFFT:** The extracted column is pushed directly through an $M$-point 1D IFFT processing block. The IFFT combines all $M$ frequency tones simultaneously. It scales each sine wave by its corresponding QAM vector instruction and mixes them together, outputting a block of $M$ discrete time-domain samples.

- **Step C: Mathematical Continuous-Time Superposition:** By summing the energy of all modulated subcarrier waves across every single time slot column, the Heisenberg engine yields the unified system equation:

$$
s(t) = \sum_{n=0}^{N-1} \sum_{m=0}^{M-1} X_{TF}[m, n] \cdot \text{g}_{tx}(t - nT) \cdot e^{j 2 \pi m \Delta f (t - nT)}
$$

Where $\text{g}_{tx}(t)$ represents the transmitted pulse-shaping filter window, $T$ represents the time slot duration ($1/\Delta f$), and $\Delta f$ defines the subcarrier spacing intervals.

##### 2. The Physics of Pulse-Shaping & Sinc Interlapping

When the IFFT block completes its mixing cycle, it outputs sharp, rigid digital numbers. If these numbers are driven straight out of the chip's pins to an antenna, they create steep "stair-step" voltage jumps.

- **The Problem:** Sudden, instantaneous voltage changes require an infinite acceleration of electrical current. In the physical universe, this sudden surge creates massive high-frequency noise that splatters across the radio spectrum, jamming nearby radio channels.

- **The Solution:** To fix this frequency bleed, the engine routes the streaming data through a **Pulse-Shaping Filter** using a **Sinc Function** ($\text{sinc}(x) = \frac{\sin(\pi x)}{\pi x}$). The filter acts as an interpolation tool, smoothing out the jagged digital edges so the resulting wave climbs and drops along a soft contour.

- **Enforcing Orthogonality:** As shown in Figure 2, packing smooth waves tightly together usually causes them to bleed into one another over time. However, the sinc pulse is uniquely engineered with a powerful mathematical trait: **its peak aligns perfectly with the exact zero-crossing points of all surrounding pulses.**

- When the receiver samples the timeline to read the red pulse, the blue and green waves are at exactly zero volts. This strict structural alignment allows the signals to overlap in time without corrupting each other, preserving total multi-carrier isolation without introducing Inter-Symbol Interference (ISI).
---

### **Day 4–5 (May 21–22, 2026): Unified Floating-Point OTFS Transmitter Notebook Execution & Hardware-Oriented Validation**

#### **Objectives**

1. Integrate all previously isolated OTFS transmitter stages into a single executable Python notebook.
2. Validate end-to-end signal flow from raw binary input to DAC-ready complex waveform generation.
3. Verify mathematical correctness of ISFFT-based domain transformation.
4. Analyze practical hardware implications of matrix streaming, FFT scheduling, and waveform synthesis.
5. Establish a trusted floating-point golden reference prior to RTL and fixed-point migration.

For the full, executable notebook (including the sinc interpolation visualization and all supporting code), see the Tx notebook: [scripts/python/Tx understanding.ipynb](scripts/python/Tx%20understanding.ipynb)

##### **Stage 1: System Specifications & Initialization Constants**

```python
import numpy as np
# STAGE 1: SYSTEM SPECIFICATIONS & INITIALIZATION CONSTANTS
M = 4               # Matrix Rows (Delay bins / Frequency subcarriers)
N = 4               # Matrix Columns (Doppler bins / Time slots)
Delta_f = 1000      # Subcarrier frequency spacing (1 kHz)
T = 1 / Delta_f     # Duration of a single useful time slot window (1 ms)
N_CP = 2            # Cyclic Prefix sample length per slot segment
samples_per_slot = M
oversampling_factor = 4  # Interpolation factor to simulate continuous analog voltage traces

print("--- 16-QAM OTFS HARDWARE VERIFICATION MODEL ---")
print(f"Grid Geometry: {M} Subcarriers x {N} Time Slots")
print(f"Subcarrier Bandwidth: {Delta_f} Hz | Useful Slot Boundary: {T*1000:.1f} ms\n")
```

- `M` and `N` define the size of the OTFS grid. Here the model uses a `4 x 4` frame so the transmitter is easy to verify step by step.
- `Delta_f` sets the subcarrier spacing. With `Delta_f = 1000 Hz`, the useful symbol duration becomes `T = 1 ms`, which keeps the time-frequency grid orthogonal.
- `N_CP` reserves cyclic-prefix samples so delayed echoes do not contaminate the next symbol interval.
- `samples_per_slot = M` makes each slot use `M` samples in this simplified hardware model.
- `oversampling_factor = 4` increases sample density so the waveform trace looks smoother and closer to a continuous analog signal.
- The `print()` lines are status checks that confirm the chosen grid geometry and timing before the rest of the pipeline executes.

##### **Stage 2: 16-QAM Gray Constellation Mapping & Geometric Matrix Loading**
```python
# STAGE 2: 16-QAM GRAY CONSTELLATION MAPPING & GEOMETRIC MATRIX LOADING
# Total bits required for a single transmission frame = M * N * 4 bits (16-QAM)
np.random.seed(42)  # Set static seed for reproducible RTL bit-matching
total_bits_needed = M * N * 4
raw_bitstream = np.random.randint(0, 2, total_bits_needed)

# 16-QAM Gray Code Lookup Map (Maps bit pairs to physical coordinate scales)
gray_lut = {(0,0): -3, (0,1): -1, (1,1): +1, (1,0): +3}
nibbles = raw_bitstream.reshape(M * N, 4)
qam_symbols = []

for nibble in nibbles:
    i_coordinate = gray_lut[(nibble[0], nibble[1])]
    q_coordinate = gray_lut[(nibble[2], nibble[3])]
    qam_symbols.append(complex(i_coordinate, q_coordinate))

# Pack complex symbols row-major into the spatial Delay-Doppler Matrix D
D = np.array(qam_symbols).reshape(M, N)
```
This block converts a raw binary stream into complex 16-QAM symbols and packs them into the Delay-Doppler matrix `D`.

- `np.random.seed(42)` fixes the random sequence so the generated bitstream is reproducible every time the notebook runs.
- `total_bits_needed = M * N * 4` computes the exact number of bits required for one full `M x N` frame, because each 16-QAM symbol carries 4 bits.
- `raw_bitstream = np.random.randint(0, 2, total_bits_needed)` creates the test input as a flat stream of `0` and `1` values.
- `gray_lut` defines the Gray-coded amplitude levels for each bit pair. Adjacent constellation points differ by only one bit, which helps reduce bit errors under noise.
- `nibbles = raw_bitstream.reshape(M * N, 4)` groups the serial stream into 4-bit chunks, one nibble per QAM symbol.
- The `for` loop maps the first two bits to the In-Phase coordinate and the last two bits to the Quadrature coordinate, then combines them into a complex value.
- `D = np.array(qam_symbols).reshape(M, N)` stores the symbols row-by-row into the `M x N` Delay-Doppler grid so the next ISFFT stage can transform the matrix into the time-frequency domain.
<div align="center">
  <img src="./assets/fig3(QAM-constallation).png" alt="16_QAM constellation" width="700"/>
  <br/>
  <b>Figure 3: Visualization of the 16-QAM DD Constellation</b><br>
</div>

##### **Stage 3: ISFFT Domain Transformation (The Matrix Operator Sandwich)**

```python
# STAGE 3: ISFFT DOMAIN TRANSFORMATION (THE MATRIX OPERATOR SANDWICH)
# =====================================================================
# Generate scale-normalized forward and inverse unitary transformation matrices
W_M = (1.0 / np.sqrt(M)) * np.fft.fft(np.eye(M))
W_N_inv = (1.0 / np.sqrt(N)) * np.fft.ifft(np.eye(N)) * N  # Normalized scaling factor
# Execute 2D matrix transformation to yield Time-Frequency Grid X_TF
X_TF = np.dot(np.dot(W_M, D), W_N_inv)
```

- `W_M` is the normalized forward DFT matrix. Multiplying it from the left transforms each Delay axis column into the Frequency/Subcarrier direction.
- `W_N_inv` is the normalized inverse DFT matrix. Multiplying it from the right transforms each Doppler axis row into the Time Slot direction.
- The scale factors `1 / sqrt(M)` and `1 / sqrt(N)` keep the transform unitary, which preserves energy and avoids artificial gain during verification.
- `X_TF = np.dot(np.dot(W_M, D), W_N_inv)` is the ISFFT sandwich itself. It converts the Delay-Doppler frame `D` into the Time-Frequency grid `X_TF` that the Heisenberg transmit stage consumes next.

###  Week 2: Environmental Distortions & Receiver-Side Understanding

*Focus: Characterize environmental channel distortions and build receiver-side prototypes and simulations.*

---

#### Goals

- Survey propagation effects: multipath, delay spread, Doppler, fading (Rayleigh/Rician), and noise models.
- Map receiver architecture: RF front-end, ADC, synchronization (CFO/TO), channel estimation, equalization, demodulation, decoding.
- Implement simulation scripts for AWGN, multipath taps, Rayleigh/Rician fading, and Doppler shifts.
- Prototype receiver algorithms: synchronization, LS/MMSE channel estimation, ZF/MMSE equalizers, symbol detection and demapping.
- Run experiments (BER/SER vs SNR, SNR thresholds, effect of delay/Doppler) and collect results.
- Deliver a short report and presentation summarizing findings and recommended RTL migration steps.

#### Deliverables

- `scripts/python/` simulation examples and small receiver notebooks.
- CSV/JSON experiment results and plotted BER/SER curves.
- Short written report and a 5–10 slide presentation.
---
### **Day 6 (May 25, 2026): The Physics of the Channel – Multipath, Delay, and Doppler**

#### Objectives

- Understand the physical mechanisms that destroy transmitted signals in a terrestrial environment.
- Define **Inter-Symbol Interference (ISI)** caused by Delay Spread.
- Define **Inter-Carrier Interference (ICI)** caused by Doppler Shifts.
- Establish the mathematical reality of the **Doubly Dispersive Channel**.

---

##### 1. Multipath Propagation & The Illusion of LoS

In a perfect vacuum, communication is a straight line: a direct **Line of Sight (LoS)**.

In a real environment (cities, terrain, indoors), the antenna radiates energy in all directions.

When this energy hits:

- Buildings
- Cars
- Ground
- Walls
- Metallic objects

it reflects and scatters.

The receiver therefore captures:

- Direct LoS signal
- Multiple reflected echoes

This phenomenon is called:

###### Multipath Propagation

Each reflected copy arrives with:

- Different delay
- Different amplitude
- Different phase

---

##### 2. Delay Spread and Inter-Symbol Interference (ISI)

Reflected echoes travel longer distances than the direct signal.

Since radio waves travel at the speed of light:

:contentReference[oaicite:0]{index=0}

Where:

- $\tau_i$ = delay of path $\mathbf{i}$
- $d_i$ = distance traveled
-  c = speed of light

---

###### Delay Spread

The difference between:

- First arriving path
- Last arriving echo

is called:

###### Delay Spread

---

###### Inter-Symbol Interference (ISI)

If transmission is fast enough:

- Echo of Symbol 1 overlaps with Symbol 2
- Voltages combine physically
- Receiver cannot separate symbols cleanly

This creates:

###### ISI (Inter-Symbol Interference)

---

###### Role of Cyclic Prefix (CP)

The Cyclic Prefix acts as:

- A guard interval
- Artificial time buffer

It allows delayed echoes to die out before the next symbol is processed.

---

##### 3. Mobility, Doppler Shift, and Inter-Carrier Interference (ICI)

If:

- Transmitter moves
- Receiver moves
- Reflectors move

then channel geometry changes continuously.

This creates:

###### Doppler Shift

---

###### Doppler Effect

Moving toward wavefronts:

- Frequency increases

Moving away:

- Frequency decreases

The Doppler shift is denoted by:


$\nu$

---

###### Inter-Carrier Interference (ICI)

OFDM and OTFS rely on:

- Strict subcarrier orthogonality

If Doppler is severe:

- Frequency grid shifts
- Orthogonality breaks
- Subcarriers leak into neighbors

This causes:

###### ICI (Inter-Carrier Interference)

---

##### 4. The Doubly Dispersive Channel

When both:

- Delay spread exists
- Doppler spread exists

the channel becomes:

##### Doubly Dispersive

The received signal is modeled as:

:contentReference[oaicite:1]{index=1}

Where:

- $h_i$ = fading/amplitude scaling
- $\tau_i$ = delay spread component
- $\nu_i$ = Doppler shift
- $n(t)$ = thermal noise

This equation mathematically models:

- ISI
- ICI
- Fading
- Noise

simultaneously.

---

##### Key Intuition

| Effect | Physical Cause | Result |
|---|---|---|
| Delay Spread | Multipath echoes | ISI |
| Doppler Spread | Mobility | ICI |
| Fading | Reflection/destructive interference | Signal attenuation |

---

### **Day 7 (May 26, 2026): Theoretical Receiver Architecture – Undoing the Damage**

#### Objectives

- Understand the OTFS receiver pipeline
- Learn Frame Synchronization
- Understand Pilot Symbols
- Compare ZF and MMSE Equalizers

---

##### 1. Reverse Signal Pipeline

The transmitter converted:

- Delay-Doppler matrix
→ Time-frequency signal
→ Time-domain waveform

The receiver performs the reverse operation.

---

###### Receiver Stages

**Step 1 — ADC & CP Removal**

The antenna receives:

$y(t)$

The receiver:

- Digitizes the analog waveform
- Removes the Cyclic Prefix

This removes the most corrupted ISI region.

---

**Step 2 — Wigner Transform (FFT)**

Receiver performs:

- M-point FFT

This reconstructs the:

##### Time-Frequency Grid

$X_{TF}$

---

 **Step 3 — Symplectic FFT (SFFT)**

Receiver transforms data back into:

##### Delay-Doppler Domain

using:

**SFFT**

The output is:


$\hat{D}$

But it is still distorted by the channel.

---

##### 2. Frame Synchronization

Receiver continuously listens to noisy samples.

Question:

***How does it know where a frame begins?***


##### Preamble-Based Synchronization

Transmitter sends a known sequence:

#### Preamble

Receiver performs:

#### Cross-Correlation

It slides a stored copy across incoming samples.

When alignment occurs:

- Correlation spikes sharply
- Spike index becomes frame start

This defines:

$t = 0$

---

##### 3. Channel Estimation

Receiver cannot reverse distortion unless it knows the channel.

---

###### Pilot Symbols

Transmitter inserts known QAM symbols into fixed grid locations.

Example:

$5 + 5j$

at known coordinates.

---

###### Estimation Logic

Receiver compares:

| Expected Pilot | Received Pilot |
|---|---|
| \(5+5j\) | \(2.5+1j\) |

Difference reveals:

- Amplitude attenuation
- Phase rotation
- Delay/Doppler effects

Receiver then estimates:

##### Channel Matrix

$\hat{H}$

---

##### 4. Equalization

Goal:

Recover original transmitted symbols.

---

##### Zero Forcing (ZF)

ZF computes:

:contentReference[oaicite:3]{index=3}

and applies the inverse directly.

---

###### Problem with ZF

If a channel coefficient is near zero:


$\frac{1}{\text{tiny number}}$

becomes huge.

This amplifies thermal noise severely.

ZF works poorly in deep fades.

---

##### MMSE Equalizer

MMSE improves equalization by considering:

- Channel distortion
- Signal-to-noise ratio (SNR)

It balances:

- Undoing distortion
- Avoiding noise amplification

Result:

- More stable recovery
- Better practical performance

---

##### Final Detection

After equalization:

- Complex constellation points are cleaned
- Receiver maps them to nearest QAM coordinates
- Bits are recovered

Example:

$16\text{-QAM}$

maps each symbol back to 4 bits.

---

##### Core Big Picture

| Block | Purpose |
|---|---|
| CP Removal | Reduce ISI |
| FFT | Recover frequency-domain grid |
| SFFT | Recover delay-doppler symbols |
| Synchronization | Detect frame start |
| Pilot Estimation | Learn channel |
| Equalizer | Undo channel distortion |
| QAM Detection | Recover bits |

---

###### OTFS Receiver Philosophy

The receiver is essentially solving:

> “Given a distorted electromagnetic mess,
> what was originally transmitted?”

OTFS succeeds because the Delay-Doppler representation remains more stable under mobility and multipath than conventional OFDM.

### **Day 8 (May 27, 2026): Complex Baseband Signals & I/Q Decomposition**

#### **Objectives**

1. Understand why modern communication systems use complex-valued signal representations.
2. Relate QAM constellation symbols to In-Phase (I) and Quadrature (Q) components.
3. Understand the mathematical meaning of complex baseband signals.
4. Visualize how information is encoded using amplitude and phase.

---

##### 1. From QAM Symbols to Complex Samples

After the OTFS transmitter completes the ISFFT and Heisenberg transform operations, the output exists as a stream of complex-valued samples:

$$
x[n] = I[n] + jQ[n]
$$

where:

- \(I[n]\) represents the In-Phase component.
- \(Q[n]\) represents the Quadrature component.

Each complex sample corresponds to a unique point in the QAM constellation and contains both amplitude and phase information.

Unlike an RF waveform, these samples exist entirely inside the digital processing chain and are therefore referred to as **complex baseband samples**.

---

##### 2. Orthogonal Basis Functions

Modern communication systems use two orthogonal carrier components:

$$
\cos(2\pi f_c t)
$$

and

$$
\sin(2\pi f_c t)
$$

These functions are orthogonal over a symbol interval:

$$
\int_0^T
\cos(2\pi f_c t)
\sin(2\pi f_c t)\,dt = 0
$$

Because of this orthogonality, two independent information streams can occupy the same frequency band without interfering with each other.

---

##### 3. Geometric Interpretation of a Complex Symbol

A QAM symbol may be represented as:

$$
s = I + jQ
$$

where:

- \(I\) determines the horizontal coordinate.
- \(Q\) determines the vertical coordinate.

The symbol magnitude is:

$$
|s| = \sqrt{I^2 + Q^2}
$$

and the phase is:

$$
\theta = \tan^{-1}\left(\frac{Q}{I}\right)
$$

Thus, every constellation point uniquely specifies a signal amplitude and phase.

---

##### Key Understanding

A QAM symbol is not a physical waveform.

It is a complex coordinate that stores amplitude and phase information digitally before RF modulation is performed.

---

### **Day 9 (May 28, 2026): RF Upconversion Using I/Q Modulation**

#### **Objectives**

1. Understand the transition from complex baseband signals to RF signals.
2. Study the mathematical model of quadrature modulation.
3. Generate a physically transmittable RF waveform from I/Q samples.
4. Visualize the role of carrier frequency translation.

---

##### 1. Why Upconversion Is Necessary

The OTFS transmitter generates information-bearing signals around DC (0 Hz).

These low-frequency signals cannot be efficiently radiated by practical antennas.

Therefore, the signal must be translated to a higher carrier frequency $f_c$ before transmission.

---

##### 2. I/Q Modulator Architecture

The RF waveform is generated using the In-Phase and Quadrature components:

$$s_{RF}(t) =I(t)\cos(2\pi f_c t) - Q(t)\sin(2\pi f_c t)$$

where:

- $I(t)$ modulates the cosine carrier.
- $Q(t)$ modulates the sine carrier.

The resulting waveform is real-valued and can be transmitted through an antenna.

---

##### 3. Simulation Activities

The following steps were performed:

- Extracted the real component as the I stream.
- Extracted the imaginary component as the Q stream.
- Generated sinusoidal carrier waveforms.
- Mixed the I branch with the cosine carrier.
- Mixed the Q branch with the sine carrier.
- Combined both branches to generate the final RF signal.

---
##### Simulation Results

The following simulation was performed to reconstruct a continuous-time complex baseband waveform from the discrete Heisenberg transform output and subsequently generate a real RF waveform suitable for transmission.

```python
import numpy as np

# =====================================================================
# COMPLEX BASEBAND INTERPOLATION AND RF UPCONVERSION
# =====================================================================

# Serialize the 2-D Heisenberg output into a single streaming frame
final_tx_signal = time_domain_slots.flatten(order='F')

# Preserve complex-valued I/Q samples
tx_complex_samples = np.asarray(final_tx_signal, dtype=complex)

# Continuous interpolation axis
t_analog = np.linspace(0, len(tx_complex_samples) - 1, 1000)

# Convert sample indices into physical time
Ts = 1.0 / (M * Delta_f)
t_seconds = t_analog * Ts

# Sinc interpolation of I and Q components
i_analog_wave = np.zeros_like(t_analog, dtype=float)
q_analog_wave = np.zeros_like(t_analog, dtype=float)

for n, symbol in enumerate(tx_complex_samples):

    sinc_basis = np.sinc(t_analog - n)

    i_analog_wave += symbol.real * sinc_basis
    q_analog_wave += symbol.imag * sinc_basis

# Reconstructed complex baseband signal
complex_baseband_wave = (
    i_analog_wave +
    1j * q_analog_wave
)

# RF upconversion
fc = 10000.0

rf_tx_signal = np.real(
    complex_baseband_wave *
    np.exp(1j * 2 * np.pi * fc * t_seconds)
)
```

**Observations**

- The discrete complex samples produced by the Heisenberg transform were successfully reconstructed into continuous-time I(t) and Q(t) waveforms using sinc interpolation.
- The reconstructed baseband signal preserved both amplitude and phase information contained within the original OTFS symbols.
- Quadrature modulation shifted the signal from baseband to the desired carrier frequency of 10 kHz.
- The resulting waveform became a purely real-valued RF signal suitable for DAC generation and antenna transmission.
- The simulation verified the complete signal flow from complex baseband representation to physical RF waveform synthesis.

---

<div align="center">
<img src="./assets/fig4.png" width="850"/>

**Figure 8.1:** Complex baseband waveform showing the reconstructed In-Phase \(I(t)\) and Quadrature \(Q(t)\) components after sinc interpolation.
</div>

<div align="center">
<img src="./assets/fig5.png" width="850"/>

**Figure 9.1:** Real RF waveform generated through quadrature modulation of the complex baseband signal.
</div>

##### 4. Physical Interpretation

The I and Q branches independently control the amplitude and phase of the transmitted carrier.

Together they allow a single RF signal to carry complex information without requiring multiple frequency channels.

---

##### Key Understanding

Although OTFS processing relies heavily on complex arithmetic, the antenna ultimately transmits a single real-valued RF waveform generated through quadrature modulation.

---

### **Day 10 (May 29, 2026): Sinc Interpolation & Continuous-Time Waveform Reconstruction**

#### **Objectives**

1. Understand the difference between discrete-time samples and continuous-time signals.
2. Study pulse-shaping and interpolation techniques.
3. Investigate the orthogonality properties of sinc functions.
4. Reconstruct a continuous-time approximation of the transmitted waveform.

---

##### 1. Discrete Samples Versus Physical Signals

The Heisenberg transform produces a sequence of discrete-time samples:

$$x[0], x[1], x[2], \dots, x[N-1]$$

However, a real communication channel requires a continuously varying voltage waveform.

Therefore, the discrete samples must be reconstructed into a continuous signal before transmission.

---

##### 2. Ideal Sinc Interpolation

The ideal interpolation kernel is the sinc function:

$$
sinc(x) = \frac{\sin(\pi x)}{\pi x}
$$

Each transmitted sample generates a shifted sinc pulse.

The continuous waveform is obtained by summing all shifted sinc functions:

$$
x(t) = \sum_{n=-\infty}^{\infty} x[n] sinc \left( \frac{t-nT_s}{T_s}\right)
$$

where $T_s$ is the sampling interval.

---

##### 3. Orthogonality Property

A key property of the sinc function is:

$$
\sinc(n)=0 \qquad n \neq 0
$$

This means that every pulse reaches zero exactly at the sampling locations of neighboring symbols.

Consequently, symbols can overlap in time without creating Inter-Symbol Interference (ISI).

---

##### 4. Simulation Activities

The following investigations were performed:

- Applied sinc interpolation to generated OTFS baseband samples.
- Visualized discrete sample locations.
- Reconstructed a continuous-time waveform.
- Examined pulse overlap behavior.
- Verified zero-crossing properties of neighboring sinc pulses.

---
##### Simulation Results

The sinc interpolation process was visualized to verify reconstruction of the continuous-time waveform from discrete OTFS samples.

<div align="center">
<img src="./assets/fig6.png" width="900"/>

**Figure 10.1:** Sinc interpolation applied independently to the In-Phase and Quadrature sample streams. The markers indicate original discrete samples while the continuous curves represent the reconstructed waveform.
</div>

**Observations**

- Every transmitted sample generated a shifted sinc basis function.
- The superposition of all sinc functions reconstructed a smooth continuous-time waveform.
- Neighboring sinc pulses crossed zero at sampling locations, preserving symbol orthogonality.
- The reconstructed waveform matched the original sample values exactly at sampling instants.
- The simulation demonstrated the theoretical foundation of pulse shaping and waveform reconstruction used in digital communication systems.

---

##### 5. Relationship to the Heisenberg Transform

The Heisenberg transform produces discrete-time waveform samples.

Sinc interpolation provides a mathematical approximation of how those samples evolve into a smooth continuous-time signal suitable for RF transmission.

### **Day 11 (June 1, 2026): Cyclic Prefix Insertion & Multipath Channel Preparation**

#### **Objectives**

1. Understand why wireless communication systems require a Cyclic Prefix (CP).
2. Study how delayed echoes create Inter-Symbol Interference (ISI).
3. Learn how CP transforms a linear convolution channel into a circular convolution channel.
4. Implement Cyclic Prefix insertion in the OTFS transmit chain.
5. Prepare the transmitter waveform for upcoming multipath channel simulations.

---

##### 1. Why Multipath Creates a Problem

In a practical wireless environment, transmitted signals do not arrive at the receiver through a single path.

Instead, reflections from buildings, vehicles, terrain, and surrounding objects generate multiple delayed copies of the transmitted waveform.

The received signal can therefore be expressed as:

$$
r(t) = \sum_{i=0}^{L-1} h_i s(t-\tau_i)
$$

where:

- $h_i$ represents the gain of the $i^{th}$ path.
- $\tau_i$ represents the propagation delay.
- $L$ denotes the total number of propagation paths.

When these delayed copies extend beyond the symbol boundary, they overlap with subsequent symbols and create Inter-Symbol Interference (ISI).

---

##### 2. The Concept of the Cyclic Prefix

To protect transmitted symbols from delayed echoes, communication systems insert a guard interval before each transmitted block.

Instead of appending zeros, the final samples of the symbol are copied and placed at the beginning.

For a transmitted symbol:

$$
x[n] = [x_0,x_1,\dots,x_{N-1}]
$$

the Cyclic Prefix operation generates:

$$
x_{CP}[n] = [x_{N-N_{CP}},\dots,x_{N-1}, x_0,x_1,\dots,x_{N-1}]
$$

where $N_{CP}$ denotes the cyclic prefix length.

This additional interval absorbs delayed multipath components before they reach the useful symbol region.

---

##### 3. Why the Prefix Must Be Cyclic

The prefix is not arbitrary.

Copying the tail of the symbol preserves periodicity across the symbol boundary.

As a result, the receiver observes a circular convolution rather than a linear convolution.

This property is extremely important because FFT-based communication systems rely on circular convolution for efficient equalization and channel compensation.

Without a Cyclic Prefix:

$$
y[n] = h[n] * x[n]
$$

where \(*\) denotes linear convolution.

With a sufficiently long Cyclic Prefix:

$$
y[n] = h[n] \circledast x[n]
$$

where $ \circledast\ $ denotes circular convolution.

This allows the channel effects to be handled efficiently in the frequency domain.

---

##### 4. Cyclic Prefix in the OTFS Transmission Chain

The OTFS transmitter currently generates a sequence of time-domain symbols through the Heisenberg transform.

Before transmission, a Cyclic Prefix is added to each symbol independently.

The resulting processing chain becomes:

```text
Delay-Doppler Symbols
        ↓
      ISFFT
        ↓
 Time-Frequency Grid
        ↓
 Heisenberg Transform
        ↓
 Time-Domain Symbols
        ↓
 Cyclic Prefix Insertion
        ↓
   Channel Model
```

---

##### Simulation Results

The following simulation was performed to append a Cyclic Prefix to each transmitted OTFS symbol.

```python
import numpy as np

# ==========================================================
# CYCLIC PREFIX INSERTION
# ==========================================================

N_CP = 2

slots_with_cp = []

for slot in time_domain_slots.T:

    cp = slot[-N_CP:]

    slot_with_cp = np.concatenate([
        cp,
        slot
    ])

    slots_with_cp.append(slot_with_cp)

tx_with_cp = np.concatenate(slots_with_cp)
```

**Observations**

- The final $N_{CP}$ samples of each symbol were successfully copied to the front of the symbol.
- The useful information content remained unchanged.
- The overall symbol duration increased from \(N\) samples to \(N + N_{CP}\) samples.
- The generated waveform is now prepared for multipath channel simulations.
- The inserted guard interval will absorb delayed echoes generated by the channel.

---

<div align="center">
<img src="./assets/fig7.png" width="850"/>

**Figure 11.1:** Cyclic Prefix insertion process showing the final samples of a symbol copied to the beginning of the transmission block.
</div>

<div align="center">
<img src="./assets/fig9.png" width="950"/>

**Figure 11.2:** Discrete In-Phase and Quadrature sample streams illustrating Cyclic Prefix insertion. The colored payload samples correspond to the original OTFS symbol data, while the highlighted prefix samples represent copies of the final symbol samples inserted at the beginning of each transmission block.
</div>

<div align="center">
<img src="./assets/fig8.png" width="900"/>

**Figure 11.3:** RF waveform after Cyclic Prefix insertion. The transmitted waveform now contains guard intervals that extend the duration of each transmitted OTFS symbol while maintaining the original information-bearing waveform structure.
</div>

---

##### Key Understanding

The Cyclic Prefix does not increase data throughput or improve signal quality directly. Its primary purpose is to protect the useful symbol interval from delayed multipath echoes and enable efficient FFT-based processing at the receiver. This mechanism forms the foundation for studying multipath propagation, delay spread, and Inter-Symbol Interference in subsequent channel simulations.

### **Day 12(June 2, 2026): Delay–Doppler Channel Modeling & Individual Path Generation**

#### Objectives

1. Implement a realistic wireless propagation channel.
2. Simulate multipath delay spread.
3. Introduce Doppler shifts caused by mobility.
4. Generate individual channel paths for later RF combination.
5. Visualize the impact of delay and Doppler on complex baseband signals.

---

##### 1. Motivation

Until this stage, the transmitter produced an ideal RF waveform.

Real wireless channels introduce distortions due to:

- Reflections
- Scattering
- Mobility
- Relative motion

As a result, the receiver observes multiple delayed and frequency-shifted copies of the transmitted signal.

---

##### 2. Multipath Channel Model

The received signal consists of multiple propagation paths.

Each path is characterized by:

- Delay
- Doppler shift
- Path gain

For path \(i\):

$$r_i(t) = s(t-\tau_i) e^{j2\pi f_{D,i} t}$$

where

- $s(t)$ = transmitted signal
- $\tau_i$ = propagation delay
- $f_{D,i}$ = Doppler shift

---

##### 3. Channel Parameters

The following channel profile was implemented.

| Path | Delay (μs) | Doppler Shift (Hz) |
|--------|--------|--------|
| Path 1 | 0 | 0 |
| Path 2 | 250 | +350 |
| Path 3 | 625 | -200 |

These values emulate a receiver observing:

- Direct line-of-sight energy
- One positive-Doppler reflection
- One negative-Doppler reflection

---

##### 4. Delay Implementation

Each path was delayed independently.

The delay operation was implemented by shifting the waveform in time according to:

$$\tau_i = \frac{d_i}{c}$$

where:

- $d_i$ is path length
- $c$ is speed of light

The delayed copies begin later in the observation window and represent reflected signal arrivals.

---

##### 5. Doppler Implementation

After delaying the signal, Doppler shifts were applied through complex phase rotation.

$$e^{j2\pi f_{D,i}t}$$

Positive Doppler corresponds to approaching motion.

Negative Doppler corresponds to receding motion.


---
##### 6. Channel Model Implementation

To simulate a realistic wireless propagation environment, two reusable functions were developed.

The first function generates delayed replicas of the transmitted waveform on a common time axis. The second function applies Doppler-induced frequency shifts to each delayed path.

---

###### Fractional Delay Generation

The following function creates delayed versions of the transmitted complex waveform.

```python
def add_fractional_delays(signal, t_seconds, delays_us):
    """Generate delayed replicas of a complex waveform on a common extended time grid.

    Parameters
    ----------
    signal : np.ndarray
        Complex-valued waveform samples.
    t_seconds : np.ndarray
        Original time axis for the waveform.
    delays_us : list[float]
        Path delays in microseconds.

    Returns
    -------
    delayed_paths : list[np.ndarray]
        One delayed waveform per propagation path.
    t_extended : np.ndarray
        Common time axis extended to fit the longest delay.
    """

    signal = np.asarray(signal)
    t_seconds = np.asarray(t_seconds, dtype=float)
    delays_us = list(delays_us)

    if signal.ndim != 1:
        raise ValueError("signal must be a 1D waveform")

    if t_seconds.ndim != 1:
        raise ValueError("t_seconds must be a 1D time axis")

    if len(signal) != len(t_seconds):
        raise ValueError(
            "signal and t_seconds must have the same length"
        )

    if len(t_seconds) < 2:
        raise ValueError(
            "t_seconds must contain at least two samples"
        )

    tau_seconds = [
        delay_us * 1e-6
        for delay_us in delays_us
    ]

    max_delay = max(tau_seconds, default=0.0)

    dt = t_seconds[1] - t_seconds[0]

    t_extended = np.arange(
        0.0,
        t_seconds[-1] + max_delay + 0.5 * dt,
        dt
    )

    interp_real = lambda query_times: np.interp(
        query_times,
        t_seconds,
        np.real(signal),
        left=0.0,
        right=0.0
    )

    interp_imag = lambda query_times: np.interp(
        query_times,
        t_seconds,
        np.imag(signal),
        left=0.0,
        right=0.0
    )

    delayed_paths = []

    for tau in tau_seconds:

        shifted_times = t_extended - tau

        delayed_wave = (
            interp_real(shifted_times)
            +
            1j * interp_imag(shifted_times)
        )

        delayed_paths.append(delayed_wave)

    return delayed_paths, t_extended
```

---

###### Doppler Shift Application

After generating delayed replicas, Doppler shifts were applied independently to each path.

```python
def apply_doppler(
    delayed_paths,
    t_extended,
    dopplers_hz
):
    """Apply Doppler shifts to delayed complex paths."""

    delayed_paths = [
        np.asarray(path)
        for path in delayed_paths
    ]

    t_extended = np.asarray(
        t_extended,
        dtype=float
    )

    dopplers_hz = list(dopplers_hz)

    if len(delayed_paths) != len(dopplers_hz):
        raise ValueError(
            "delayed_paths and dopplers_hz "
            "must have the same length"
        )

    if t_extended.ndim != 1:
        raise ValueError(
            "t_extended must be a 1D time axis"
        )

    doppler_paths = []

    for path, fd in zip(
        delayed_paths,
        dopplers_hz
    ):

        doppler_path = (
            path *
            np.exp(
                1j *
                2 *
                np.pi *
                fd *
                t_extended
            )
        )

        doppler_paths.append(
            doppler_path
        )

    return doppler_paths
```

---

###### Channel Parameter Configuration

The simulation used the following propagation parameters.

```python
path_delays_us = [
    0,
    250,
    625
]

path_dopplers_hz = [
    0,
    350,
    -200
]
```

---

###### Channel Path Generation

```python
delayed_paths, t_extended = add_fractional_delays(
    complex_baseband_wave,
    t_seconds,
    path_delays_us
)

doppler_paths = apply_doppler(
    delayed_paths,
    t_extended,
    path_dopplers_hz
)
```

These generated paths represent the individual delay-Doppler components of the wireless channel and form the basis for the RF multipath synthesis performed in the following day.

---

##### Simulation Results

The generated channel paths are shown below.

<div align="center">

<img src="./assets/fig10.png" width="950"/>

**Figure 12.1:** Complex baseband representations of the three channel paths. Delays create shifted arrivals while Doppler shifts alter phase evolution.

</div>

---

##### Observations

- Path 1 arrives immediately.
- Path 2 begins after 250 μs.
- Path 3 begins after 625 μs.
- Positive Doppler causes accelerated phase rotation.
- Negative Doppler produces reverse phase evolution.
- The channel now contains both delay spread and Doppler spread.

---

##### Key Understanding

A wireless channel does not simply attenuate signals.

Instead, it generates multiple delayed and Doppler-shifted replicas that occupy different regions of the delay-Doppler plane.

This forms the foundation of OTFS channel modeling.

### **Day 13–14 (June 3-4, 2026): RF Multipath Synthesis, Receiver Downconversion & Complex Baseband Recovery**

#### **Objectives**

1. Combine all delayed and Doppler-shifted propagation paths into a single received RF waveform.
2. Visualize the RF-domain representation of individual propagation paths.
3. Study constructive and destructive interference caused by multipath propagation.
4. Implement receiver-side quadrature downconversion.
5. Recover the complex baseband signal from the received RF waveform.
6. Apply low-pass filtering to remove mixer image frequencies.
7. Downsample the recovered waveform for symbol-rate processing.
8. Prepare the signal for constellation regeneration and symbol recovery.

---

##### 1. RF Path Generation

The delayed and Doppler-shifted channel paths generated in the previous stage were converted into RF-domain waveforms.

Each path contains:

- Propagation delay
- Doppler shift
- Phase distortion
- Amplitude scaling

The RF representation of path $i$ can be expressed as

$$r_i(t)=g_is(t-\tau_i) e^{j2\pi f_{D,i}t}$$

where:

- $g_i$ is the path gain
- $\tau_i$ is the propagation delay
- $f_{D,i}$ is the Doppler shift

---

##### RF Path Visualization

Before combining the individual propagation paths, each RF path was visualized independently.

The simulated channel parameters were:

| Path | Delay (μs) | Doppler Shift (Hz) |
|--------|--------|--------|
| Path 1 | 0 | 0 |
| Path 2 | 250 | +350 |
| Path 3 | 625 | -200 |

---

##### Simulation Results

<div align="center">

<img src="./assets/fig11.png" width="950"/>

**Figure 13.1:** RF-domain representation of the three propagation paths after delay and Doppler application.

</div>

---

##### Observations

- Path 1 represents the direct line-of-sight component.
- Path 2 arrives 250 μs later and experiences a positive Doppler shift.
- Path 3 arrives 625 μs later and experiences a negative Doppler shift.
- Each path exhibits unique phase evolution due to Doppler modulation.
- These paths collectively form the wireless channel seen by the receiver.

---

##### 2. Multipath Signal Superposition

The receiver does not observe the individual paths separately.

Instead, all propagation paths arrive simultaneously and add together according to the principle of superposition.

The received signal is therefore

$$r(t) = \sum_{i=1}^{P} g_i s(t-\tau_i) e^{j2\pi f_{D,i}t}$$

where:

- $P$ is the number of propagation paths
- $g_i$ is the path gain
- $\tau_i$ is the delay
- $f_{D,i}$ is the Doppler frequency

---

##### Path Gain Assignment

To emulate realistic attenuation, gain coefficients were assigned to each path.

```python
rf_path_gains = np.linspace(
    1.0,
    0.5,
    len(rf_doppler_paths)
)
```

The direct path was assigned the highest gain while reflected paths experienced increasing attenuation.

---

##### Multipath Combination Function

```python
def combine_multipath_paths(paths, gains):

    rx_signal = np.zeros_like(
        paths[0],
        dtype=complex
    )

    for path, gain in zip(paths, gains):
        rx_signal += gain * path

    return rx_signal
```

---

##### Simulation Execution

```python
rf_rx_signal = combine_multipath_paths(
    rf_doppler_paths,
    rf_path_gains
)

rf_rx_signal = rf_rx_signal.real
```

---

##### Simulation Results

<div align="center">

<img src="./assets/fig12.png" width="950"/>

**Figure 13.2:** Combined RF received signal obtained after summing all delayed and Doppler-shifted propagation paths.

</div>

---

##### Observations

- Constructive interference generated large amplitude peaks.
- Destructive interference generated deep fading regions.
- Time-varying fading became clearly visible.
- The received waveform differs significantly from the transmitted RF waveform.
- Delay spread and Doppler spread jointly distort the signal.

---

##### 3. Receiver Quadrature Downconversion

The received RF waveform occupies a band centered around the carrier frequency \(f_c\).

To recover the transmitted information, the receiver performs quadrature downconversion.

The received signal is multiplied by a locally generated carrier:

$$r_{BB}(t) = r_{RF}(t) e^{-j2\pi f_c t}$$

This shifts the desired spectrum from the carrier frequency back to DC.

---

##### Downconversion Implementation

```python
rx_complex_mixed = (
    rf_rx_signal *
    np.exp(
        -1j *
        2 *
        np.pi *
        fc *
        t_extended
    )
)
```

---

##### 4. Low-Pass Filtering

The mixing operation generates two spectral components:

$$f_c-f_c = 0$$

and

$$f_c+f_c = 2f_c$$

The component near $2f_c$ contains no useful information and must be removed.

A low-pass filter was therefore applied to isolate the baseband spectrum.

---

##### Low-Pass Filter Implementation

```python
from scipy.signal import butter, filtfilt

cutoff_hz = 2000

b, a = butter(
    5,
    cutoff_hz /
    (0.5 * sample_rate)
)

rx_baseband_filtered = filtfilt(
    b,
    a,
    rx_complex_mixed
)
```

---

##### 5. Downsampling

The transmitted waveform was previously oversampled to approximate a continuous-time signal.

After filtering, the signal was returned to the original symbol-rate processing frequency.

```python
rx_downsampled = rx_baseband_filtered[
    ::oversampling_factor
]
```

This reduces computational complexity while preserving the transmitted information.

---

##### Simulation Results

<div align="center">

<img src="./assets/fig13.png" width="950"/>

**Figure 13.3:** Recovered complex baseband waveform after downconversion, low-pass filtering, and downsampling.

</div>

---

##### Observations

- The RF carrier was successfully removed.
- The complex envelope was recovered.
- I/Q information remained intact.
- Delay and Doppler distortions remained visible.
- The signal was successfully prepared for constellation regeneration.

---

##### Key Understanding

The receiver successfully reversed the RF upconversion process and recovered a complex baseband representation of the transmitted signal. Although the channel impairments remained present, the information-bearing waveform was preserved and prepared for symbol extraction and constellation reconstruction in the next stage.

### **Day 15 (June 5, 2026): OTFS Demodulation Pipeline & Receiver-Side Signal Recovery**

#### **Objectives**

1. Understand why demodulation is the most critical stage of the OTFS receiver.
2. Study the reverse processing chain used to recover transmitted information.
3. Understand the purpose of CP removal, Wigner transformation, and SFFT operations.
4. Analyze how OTFS converts channel distortion into a structured delay-Doppler representation.
5. Establish the theoretical foundation required before hardware implementation.

---

##### 1. Why Demodulation Matters

At the conclusion of the previous stage, the receiver had successfully recovered a complex baseband signal.

However, this waveform still contained:

- Multipath distortion
- Delay spread
- Doppler spread
- Fading effects
- Phase rotation

The received waveform no longer resembled the original transmitted symbol sequence.

Consequently, direct symbol detection would produce a large number of errors.

The purpose of the OTFS receiver is therefore not to prevent channel distortion but to reverse its effects and recover the original information symbols.

---

##### 2. The Misconception About OTFS

A common misunderstanding is that OTFS eliminates multipath and Doppler effects.

In reality, OTFS does not remove these impairments during transmission.

The wireless channel still produces

$$r(t)=\sum_{i=1}^{P}h_i s(t-\tau_i) e^{j2\pi \nu_i t} + n(t)$$

where:

- $h_i$ is the path gain
- $\tau_i$ is the path delay
- $\nu_i$ is the Doppler shift
- $n(t)$ is additive noise

The received waveform therefore remains heavily distorted.

The advantage of OTFS is that it provides a mathematical framework that allows these distortions to be represented and compensated efficiently in the delay-Doppler domain.

---

##### 3. Reverse Signal Processing Chain

The transmitter performed the following operations:

```text
Bits
 ↓
16-QAM Mapping
 ↓
Delay-Doppler Grid
 ↓
ISFFT
 ↓
Heisenberg Transform
 ↓
RF Upconversion
 ↓
Wireless Channel
```

The receiver performs the reverse sequence:

```text
Received RF Signal
 ↓
Downconversion
 ↓
Complex Baseband
 ↓
CP Removal
 ↓
Wigner Transform
 ↓
Time-Frequency Grid
 ↓
SFFT
 ↓
Delay-Doppler Grid
 ↓
Equalization
 ↓
QAM Detection
 ↓
Recovered Bits
```

The receiver therefore acts as the inverse of the transmitter.

---

##### 4. Cyclic Prefix Removal

The first processing stage removes the cyclic prefix introduced at the transmitter.

The cyclic prefix absorbed delayed echoes produced by multipath propagation.

After reception, the guard interval no longer contains useful information and is discarded.

This operation restores the original symbol boundaries required for transform-domain processing.

---

##### 5. Wigner Transform

Following CP removal, the receiver applies an FFT operation.

This stage converts the received time-domain waveform into a time-frequency representation.

The resulting grid corresponds to the transmitted OTFS frame after propagation through the wireless channel.

Unlike the delay-Doppler grid used at the transmitter, this representation now contains channel-induced distortion.

---

##### 6. Symplectic Finite Fourier Transform (SFFT)

The most important receiver operation is the Symplectic Finite Fourier Transform.

The SFFT performs the inverse operation of the transmitter ISFFT.

Mathematically,

$$\hat{D} = W_M^{-1} X_{TF} W_N$$

where:

- $X_{TF}$ is the received time-frequency grid
- $\hat{D}$ is the recovered delay-Doppler grid

This transformation maps the received signal back into the natural coordinate system of the wireless channel.

---

##### 7. Why OTFS Uses Delay-Doppler Processing

The physical wireless environment naturally operates in terms of:

- Delay
- Doppler

Every propagation path can be described by:

- How late it arrives
- How much frequency shift it experiences

In the delay-Doppler domain, channel effects often appear as a small number of dominant coefficients rather than a large dense interference pattern.

This sparsity makes channel estimation and equalization significantly more manageable.

---

##### 8. Equalization & Symbol Recovery

Once the delay-Doppler grid is recovered, the receiver estimates the channel and compensates for its effects.

The equalized symbols are then mapped back to the nearest valid QAM constellation locations.

The resulting symbols are converted back into binary data.

This final stage completes the communication process.

---

##### Why Demodulation Is The Most Important Step

The transmitter simply prepares the signal for transmission.

The wireless channel subsequently introduces:

- Delay spread
- Doppler spread
- Multipath fading
- Phase distortion

Without the receiver-side demodulation chain, these impairments remain embedded within the waveform.

The purpose of demodulation is therefore to convert a distorted electromagnetic signal back into structured digital information.

The effectiveness of OTFS is determined not by how the signal is transmitted, but by how effectively the receiver can reconstruct the original delay-Doppler information after propagation through the channel.

---

##### Key Understanding

The strength of OTFS does not lie in preventing multipath propagation or Doppler distortion. These impairments remain present throughout transmission.

Instead, OTFS enables the receiver to transform a complicated doubly-dispersive wireless channel into a structured delay-Doppler representation that can be estimated, equalized, and decoded efficiently.

The demodulation process is therefore the most important stage of the OTFS receiver because it is responsible for converting a distorted electromagnetic waveform back into usable digital information.

---

##### Conclusion

This session consolidated the complete OTFS receiver pipeline and established the theoretical framework required for receiver implementation. Understanding the role of demodulation is critical before transitioning toward FPGA-oriented architecture studies, hardware mapping strategies, and OTFS accelerator design.

Future work will focus on studying OTFS hardware architectures, FPGA implementation techniques, and accelerator design methodologies required for real-time deployment.

---

### Day 16 (June 8, 2026): Wireless Propagation Physics and the Motivation for Reconfigurable Intelligent Surfaces

#### Objectives

* Understand the physical limitations of wireless propagation.
* Study free-space electromagnetic wave propagation.
* Examine free-space path loss and the inverse-square law.
* Understand the Friis transmission equation.
* Investigate Line-of-Sight (LOS) and Non-Line-of-Sight (NLOS) communication.
* Study reflection, diffraction, and scattering mechanisms.
* Understand multipath propagation.
* Establish the physical motivation behind Reconfigurable Intelligent Surfaces (RIS).

---

##### 1. Introduction

Modern wireless communication systems—including WiFi, 5G, Massive MIMO, OTFS, and future 6G technologies—rely on the transmission of electromagnetic waves through free space.

Regardless of the sophistication of signal processing algorithms, wireless performance is fundamentally constrained by electromagnetic propagation. A major challenge is that electromagnetic energy naturally spreads as it propagates, causing only a tiny fraction of the transmitted power to reach the intended receiver.

This observation forms the primary motivation behind Reconfigurable Intelligent Surfaces (RIS).

---

##### 2. Free-Space Propagation

When a transmitter radiates electromagnetic energy, the energy spreads outward in all directions.

For an ideal isotropic radiator, the transmitted power is distributed uniformly over the surface of a sphere.

The surface area of a sphere of radius $d$ is

$$A_{sphere}=4\pi d^2$$
Since the same transmitted power is distributed over an increasingly larger area, the power density decreases with distance.

The received power can be approximated by

$$P_r=P_t\frac{A_e}{4\pi d^2}$$

where:

* $P_t$ = transmitted power
* $P_r$ = received power
* $A_e$ = effective aperture of the receiving antenna
* $d$ = propagation distance

This relationship demonstrates the inverse-square law:

$$P_r\propto \frac{1}{d^2}$$

---

##### 3. Numerical Example

For a carrier frequency of approximately 3 GHz:

$$\lambda = 0.1;m$$

and an effective receiving area

$$A_e=\left(\frac{\lambda}{4}\right)^2$$

the received power fractions become:

###### At 1 m

$$\frac{P_r}{P_t}\approx0.005%$$

or approximately

$$-43;dB$$

###### At 10 m

$$
\frac{P_r}{P_t}\approx0.00005%
$$

or approximately

$$
-63;dB
$$

Even under ideal free-space conditions, more than 99.999% of the transmitted power is lost.

This highlights one of the fundamental difficulties of wireless communication.

---

##### 4. Propagation Challenges

In practical wireless environments, the situation is significantly worse than free-space propagation.

Signals encounter:

* Walls
* Buildings
* Vehicles
* Furniture
* Human bodies

These objects introduce attenuation and create multiple propagation paths.

A single wall can introduce losses exceeding

$$
20;dB
$$

which corresponds to approximately a 100-fold reduction in received power.

---

##### 5. Line-of-Sight and Non-Line-of-Sight Communication

###### Line-of-Sight (LOS)

In LOS communication, a direct path exists between the transmitter and receiver.

The received signal can be represented as

$$
r(t)=\alpha s(t-\tau)
$$

where:

* $\alpha$ is the attenuation coefficient
* $\tau$ is the propagation delay

LOS links generally provide the strongest received signal.

###### Non-Line-of-Sight (NLOS)

In many practical situations, the direct path is blocked.

Communication then depends on indirect propagation mechanisms such as:

* Reflection
* Diffraction
* Scattering

NLOS links typically experience significantly higher path loss and lower reliability.

---

##### 6. Reflection

Reflection occurs when an electromagnetic wave encounters a smooth surface.

Examples include:

* Building facades
* Glass walls
* Metal structures

The reflected wave follows the law of reflection:

$$
\theta_i=\theta_r
$$

where:

* $\theta_i$ = angle of incidence
* $\theta_r$ = angle of reflection

Reflections often provide alternative communication paths when the direct path is blocked.

---

##### 7. Diffraction

Diffraction allows electromagnetic waves to bend around edges and obstacles.

This phenomenon enables communication even when a direct optical path is unavailable.

Without diffraction, wireless coverage behind buildings and corners would be severely limited.

---

##### 8. Scattering

Scattering occurs when the dimensions of surface irregularities become comparable to the signal wavelength.

Instead of producing a single reflected wave, the incident energy is redistributed into multiple directions.

Examples include:

* Rough walls
* Vegetation
* Human bodies
* Urban clutter

Scattering contributes significantly to multipath propagation.

---

##### 9. Multipath Propagation

Because of reflections, diffraction, and scattering, multiple copies of the transmitted signal may arrive at the receiver.

A multipath channel can be modeled as

$$
r(t)=
\sum_{i=1}^{L}
\alpha_i s(t-\tau_i)
$$

where:

* $L$ = number of propagation paths
* $\alpha_i$ = attenuation of the $i^{th}$ path
* $\tau_i$ = delay of the $i^{th}$ path

Each path experiences different attenuation and delay, causing constructive and destructive interference.

Multipath propagation forms the basis of modern wireless channel models and later motivates the signal-processing framework used for RIS systems.

---

##### 10. Motivation for Reconfigurable Intelligent Surfaces

Traditional wireless systems treat the propagation environment as uncontrollable.

Walls and objects reflect signals in unpredictable directions, often causing severe signal degradation.

Reconfigurable Intelligent Surfaces introduce a new paradigm by making the environment programmable.

An RIS consists of a large number of controllable reflecting elements whose electromagnetic properties can be adjusted electronically.

Instead of relying on random reflections, the RIS can intentionally redirect energy toward desired users.

Potential benefits include:

* Improved indoor coverage
* Reduced shadow fading
* Enhanced signal strength
* Better spectral efficiency
* Increased energy efficiency

The RIS effectively transforms the wireless environment from a passive obstacle into an active component of the communication system.

---

##### Daily Outcome

* Understood the physical limitations of wireless propagation.
* Studied free-space path loss and the inverse-square law.
* Examined practical propagation losses in wireless systems.
* Learned the distinction between LOS and NLOS communication.
* Investigated reflection, diffraction, and scattering mechanisms.
* Developed the multipath channel model.
* Established the fundamental motivation behind Reconfigurable Intelligent Surfaces.
* Prepared the foundation for developing mathematical signal-processing models of RIS-assisted wireless communication.

---

### Day 17 (June 9, 2026): Signal Processing Foundations for RIS Systems

#### Objectives

* Model wireless communication channels as Linear Time-Invariant (LTI) systems.
* Understand convolution and impulse response representations.
* Develop the multipath channel model.
* Study frequency-domain channel representations.
* Learn complex baseband signal modeling.
* Understand pulse amplitude modulation (PAM).
* Study pulse shaping and the Nyquist criterion.
* Investigate matched filtering and receiver sampling.
* Develop the discrete-time communication model.
* Introduce the end-to-end RIS channel model.

---

#### 1. Introduction

In the previous session, wireless propagation was studied from a physical perspective. Electromagnetic waves experience attenuation, reflection, diffraction, and scattering as they travel through the environment.

To design communication systems and RIS-assisted wireless links, a mathematical model of the wireless channel is required. Rather than describing every electromagnetic interaction individually, communication theory models the wireless channel as a signal-processing system.

This signal-processing framework forms the basis for modern wireless technologies including OFDM, Massive MIMO, OTFS, and RIS-assisted communications.

---

#### 2. Communication Channels as LTI Systems

A wireless communication channel can be modeled as a Linear Time-Invariant (LTI) system.

The transmitted signal is denoted by

$$
x(t)
$$

and the received signal is

$$
y(t)
$$

The relationship between them is given by convolution:

$$
y(t)=h(t)*x(t)
$$

or equivalently,

$$
y(t)=\int_{-\infty}^{\infty}h(\tau)x(t-\tau)d\tau
$$

where

$$
h(t)
$$

is the channel impulse response.

The impulse response completely characterizes the wireless channel.

---

#### 3. Physical Meaning of the Impulse Response

Consider transmitting an ideal impulse:

$$
\delta(t)
$$

through the channel.

The received signal becomes

$$
h(t)
$$

Therefore, the impulse response describes how the channel reacts to the simplest possible input.

Every reflection, propagation delay, attenuation factor, and scattering mechanism is embedded within

$$
h(t)
$$

making it a complete description of the communication channel.

---

#### 4. Single-Path Wireless Channel

Suppose only one propagation path exists between the transmitter and receiver.

The channel impulse response can be modeled as

$$
h(t)=\rho\delta(t-\tau)
$$

where:

* $\rho$ = attenuation coefficient
* $\tau$ = propagation delay

Substituting into the convolution equation gives

$$
y(t)=\rho x(t-\tau)
$$

The channel simply delays and attenuates the transmitted waveform.

---

#### 5. Multipath Channel Model

In practical wireless systems, signals propagate through multiple paths due to reflection, diffraction, and scattering.

The channel impulse response becomes

$$
h(t)=
\sum_{i=1}^{L}
\rho_i\delta(t-\tau_i)
$$

where:

* $L$ = number of propagation paths
* $\rho_i$ = gain of the $i^{th}$ path
* $\tau_i$ = delay of the $i^{th}$ path

This is the fundamental multipath channel model used throughout wireless communications.

---

#### 6. Received Signal Under Multipath Propagation

Substituting the multipath impulse response into the convolution equation yields

$$
y(t)=
\sum_{i=1}^{L}
\rho_i x(t-\tau_i)
$$

The receiver therefore observes multiple delayed and attenuated copies of the transmitted signal.

Each copy arrives with different amplitude and phase.

---

#### 7. Constructive and Destructive Interference

The multiple signal copies combine at the receiver.

When their phases align:

##### Constructive Interference

The signal components add together and strengthen the received signal.

When their phases oppose each other:

##### Destructive Interference

The signal components cancel each other and reduce the received signal strength.

This phenomenon leads to fading, one of the most significant challenges in wireless communication.

---

#### 8. Frequency-Domain Channel Representation

Communication systems are often analyzed in the frequency domain.

Applying the Fourier Transform to the convolution equation gives

$$
Y(f)=H(f)X(f)
$$

where

$$
H(f)=\mathcal{F}{h(t)}
$$

is the channel frequency response.

The frequency response describes how different frequency components are modified by the wireless channel.

---

#### 9. Complex Baseband Representation

Wireless signals are physically transmitted at radio frequencies.

A passband signal can be expressed as
$$
x_{PB}(t) = \text{Re}\left\{x(t)e^{j2\pi f_c t}\right\}
$$
where:

* $x(t)$ = complex baseband signal
* $f_c$ = carrier frequency

The complex baseband representation allows communication systems to process signals without explicitly handling GHz-frequency carriers.

This greatly simplifies analysis and implementation.

---

#### 10. Baseband Equivalent Channel

The passband channel can similarly be converted into a baseband representation.

Instead of analyzing carrier-frequency oscillations directly, communication systems operate on the slowly varying complex envelope.

This forms the basis of modern digital communication theory.

---

#### 11. Pulse Amplitude Modulation (PAM)

Digital information is represented as a sequence of symbols:

$$
x[0],x[1],x[2],...
$$

Since wireless channels transmit continuous-time waveforms, these discrete symbols must be converted into a continuous signal.

Pulse Amplitude Modulation (PAM) performs this conversion:

$$x(t) = \sum_m x[m]p\left(t-\frac{m}{B}\right)$$

where:

* $x[m]$ = transmitted symbols
* $p(t)$ = pulse shape
* $B$ = symbol rate

Each symbol scales a shifted copy of the pulse shape.

The transmitted waveform is the sum of all pulse contributions.

---

#### 12. Pulse Shaping

Pulse shaping controls the spectral characteristics of the transmitted signal.

Without pulse shaping:

* Bandwidth becomes excessive.
* Neighboring symbols interfere.
* Receiver performance degrades.

Pulse shaping allows communication systems to:

* Limit occupied bandwidth.
* Improve symbol detection.
* Reduce interference.

---

#### 13. Sinc Pulse and Nyquist Criterion

An ideal pulse shape is the sinc pulse:

$$
p(t)=B,\text{sinc}(Bt)
$$

This pulse satisfies the Nyquist criterion:

$$
p(kT)=0
\quad
\text{for}
\quad
k\neq0
$$

where

$$
T=\frac{1}{B}
$$

is the symbol period.

The Nyquist criterion ensures that symbols can be recovered without interference from neighboring symbols.

---

#### 14. Inter-Symbol Interference (ISI)

If the pulse shape does not satisfy the Nyquist criterion, neighboring symbols overlap.

The sampled signal becomes

$$
y[k] = x[k] + \text{ISI}
$$

where ISI denotes Inter-Symbol Interference.

ISI significantly degrades communication performance and motivates careful pulse-shaping design.

---

#### 15. Matched Filtering

At the receiver, the incoming signal is filtered using a matched filter:

$$
z(t)=p(t)*y(t)
$$

The matched filter:

* Maximizes signal-to-noise ratio (SNR).
* Collects signal energy.
* Improves detection performance.

Matched filtering is a fundamental component of digital communication receivers.

---

#### 16. Sampling and Symbol Recovery

After matched filtering, the receiver samples the signal at symbol intervals:

$$
z[k]=z(kT)
$$

where

$$
T=\frac{1}{B}
$$

is the symbol period.

This operation converts the received waveform back into discrete symbols suitable for digital processing.

---

#### 17. Noise Model

Practical communication systems are affected by thermal and electronic noise.

The received signal is modeled as

$$
y(t)=h(t)*x(t)+w(t)
$$

where

$$
w(t)
$$

represents additive white Gaussian noise (AWGN).

After filtering and sampling, the noise becomes

$$
n[k]\sim CN(0,N_0)
$$

where:

* $CN$ denotes a complex Gaussian distribution.
* $N_0$ is the noise power.

---

#### 18. Narrowband Channel Approximation

For narrowband communication systems, the channel can often be approximated as

$$
h(t)\approx C\delta(t-\tau)
$$

where

$$
C
$$

is a complex channel coefficient.

This approximation greatly simplifies analysis.

---

#### 19. Final Discrete-Time Communication Model

Combining pulse shaping, propagation, matched filtering, and sampling results in the discrete-time communication model

$$
z[k]=Cx[k]+n[k]
$$

This compact equation forms the foundation of most modern wireless communication systems.

---

#### 20. RIS End-to-End Channel Model

For RIS-assisted communication, the received channel contains both a direct path and RIS-assisted paths.

The end-to-end impulse response can be expressed as

$$
h_{RIS}(t) = h_d(t) + \sum_{n=1}^{N}\left(b_n*\vartheta_n*a_n\right)(t)
$$

where:

* $h_d(t)$ = direct channel
* $a_n(t)$ = transmitter-to-RIS channel
* $\vartheta_n(t)$ = RIS element response
* $b_n(t)$ = RIS-to-receiver channel

This model establishes RIS as a controllable component within the wireless propagation environment.

---

#### Daily Outcome

* Modeled wireless channels as LTI systems.
* Derived convolution-based channel representations.
* Developed the multipath wireless channel model.
* Studied frequency-domain channel analysis.
* Learned complex baseband signal representation.
* Understood pulse amplitude modulation and pulse shaping.
* Investigated the Nyquist criterion and ISI.
* Studied matched filtering and receiver sampling.
* Derived the discrete-time communication model.
* Introduced the end-to-end RIS channel model used in RIS-assisted communication systems.

---

### Day 18 (June 10, 2026): RIS Hardware Fundamentals and End-to-End Channel Modeling

#### Objectives

* Understand how an RIS physically manipulates electromagnetic waves.
* Study the structure of RIS unit cells.
* Investigate tunable impedance and reflection coefficients.
* Understand voltage-controlled phase shifting.
* Develop the end-to-end RIS channel model.
* Derive the narrowband RIS communication model.
* Connect electromagnetic behavior to communication-theoretic channel models.

---

#### 1. Introduction

Previous sessions established the fundamentals of wireless propagation and signal-processing-based channel modeling.

The next step is understanding how a Reconfigurable Intelligent Surface (RIS) physically interacts with electromagnetic waves and how this interaction is incorporated into communication system models.

An RIS acts as a programmable electromagnetic boundary capable of modifying the phase, amplitude, and direction of reflected waves.

Unlike conventional reflectors, RIS elements can be electronically controlled, allowing the propagation environment itself to become part of the communication system.

---

#### 2. Structure of a Reconfigurable Intelligent Surface

An RIS consists of a large array of sub-wavelength electromagnetic elements known as unit cells.

Each unit cell typically contains:

* Metallic patch
* Dielectric substrate
* Tunable electronic component
* Control circuitry

The dimensions of each element are generally much smaller than the operating wavelength.

Because the elements are sub-wavelength in size, the RIS can approximate a programmable electromagnetic surface.

A practical RIS may contain hundreds or thousands of such elements.

---

#### 3. RIS Unit Cell Operation

Consider an electromagnetic wave incident upon an RIS element.

Unlike a conventional reflector, the RIS element modifies the reflected signal according to its electrical configuration.

By electronically changing the element's impedance, the phase and amplitude of the reflected signal can be controlled.

This allows the RIS to steer electromagnetic energy toward desired directions.

---

#### 4. Reflection Coefficient

The interaction between an electromagnetic wave and an RIS element is characterized by the reflection coefficient.

The reflection coefficient is given by

$$\Gamma = \frac{Z(V)-Z_0}{Z(V)+Z_0}$$

where

* $Z(V)$ = voltage-controlled impedance of the RIS element
* $Z_0$ = free-space impedance
* $\Gamma$ = complex reflection coefficient

The reflection coefficient determines:

* reflected amplitude
* reflected phase

The RIS controller adjusts the voltage applied to each element to modify $Z(V)$.

---

#### 5. Varactor Diodes and Tunable Impedance

Modern RIS implementations frequently employ varactor diodes.

A varactor diode behaves as a voltage-controlled capacitor.

Changing the bias voltage modifies the effective capacitance of the RIS element.

Consequently,

$$
V \rightarrow C(V) \rightarrow Z(V) \rightarrow \Gamma
$$

This chain allows software control of electromagnetic reflections.

---

#### 6. Voltage-Controlled Phase Shifting

The reflection coefficient is complex:

$$
\Gamma = |\Gamma|e^{j\phi}
$$

where

* $|\Gamma|$ = reflection magnitude
* $\phi$ = reflection phase

Changing the bias voltage alters the reflection phase.

This phase shift is the fundamental mechanism enabling RIS beamforming.

Each RIS element can therefore impose a controllable phase delay on the reflected wave.

---

#### 7. RIS as a Programmable Reflector

Consider an incoming wave:

$$
s(t)
$$

Each RIS element reflects a modified version:

$$
\Gamma_n s(t)
$$

where

$$
\Gamma_n = |\Gamma_n|e^{j\phi_n}
$$

is the reflection coefficient of the $n^{th}$ element.

The total reflected field becomes

$$
E_r=\sum_{n=1}^{N} \Gamma_n E_n
$$

where

$$
E_n
$$

represents the incident field at the $n^{th}$ element.

The RIS controller adjusts

$$
\phi_n
$$

to manipulate the resulting reflected beam.

---

#### 8. End-to-End RIS Channel Model

The RIS-assisted communication channel consists of three components:

1. Direct transmitter-to-receiver path
2. Transmitter-to-RIS path
3. RIS-to-receiver path

The complete impulse response can be represented as

$$
h_{RIS}(t) = h_d(t) + \sum_{n=1}^{N} \left(b_n\vartheta_n*a_n\right)(t)
$$

where

* $h_d(t)$ = direct channel
* $a_n(t)$ = transmitter-to-RIS channel
* $\vartheta_n(t)$ = RIS element response
* $b_n(t)$ = RIS-to-receiver channel

---

#### 9. Physical Interpretation of the Cascaded Model

The RIS-assisted signal experiences three sequential systems:

##### Stage 1

Transmitter → RIS

$$
a_n(t)
$$

---

##### Stage 2

RIS Processing

$$
\vartheta_n(t)
$$

---

##### Stage 3

RIS → Receiver

$$
b_n(t)
$$

Since these systems operate sequentially, their combined effect is represented by convolution.

The RIS therefore appears as a cascaded communication channel.

---

#### 10. Narrowband Approximation

For many communication systems, the signal bandwidth is sufficiently small that channel variations across frequency can be neglected.

Under this assumption,

$$
h(t) \approx C\delta(t-\tau)
$$

where

* $C$ = complex channel coefficient
* $\tau$ = propagation delay

This approximation greatly simplifies RIS analysis.

---

#### 11. Narrowband RIS Communication Model

Under the narrowband assumption, the received signal becomes

$$
y=\left(h_d + \sum_{n=1}^{N} g_n\theta_n f_n \right)x+n
$$

where

* $h_d$ = direct channel coefficient
* $f_n$ = transmitter-to-RIS channel
* $g_n$ = RIS-to-receiver channel
* $\theta_n$ = RIS phase control coefficient
* $n$ = noise

This equation is one of the most important models in RIS communication theory.

---

#### 12. Meaning of RIS Phase Control

The parameter

$$
\theta_n = e^{j\phi_n}
$$

represents the programmable phase shift introduced by the RIS.

By selecting

$$
\phi_n
$$

appropriately, all reflected signals can be forced to arrive at the receiver with aligned phases.

This leads to constructive interference and significant signal enhancement.

---

#### 13. Transition Toward Beamforming

The narrowband RIS model reveals that communication performance depends strongly on the selected phase shifts

$$
\theta_1,\theta_2,\ldots,\theta_N
$$

The next step is determining how these phase shifts should be chosen to maximize received signal power.

This leads directly to RIS beamforming and optimization.

---

#### Daily Outcome

* Studied the physical structure of RIS hardware.
* Investigated tunable impedance and reflection coefficients.
* Learned how varactor diodes enable programmable reflections.
* Understood voltage-controlled phase shifting.
* Developed the cascaded RIS channel model.
* Derived the narrowband RIS communication model.
* Established the mathematical foundation for RIS beamforming and optimization.

---

### Day 19 (June 11, 2026): RIS Beamforming, Coherent Combining, and Passive Beamforming Gain

#### Objectives

- Understand how RIS controls signal propagation.
- Study coherent combining and phase alignment.
- Derive optimal RIS phase shifts.
- Understand passive beamforming.
- Investigate RIS power scaling laws.
- Derive the famous \(N^2\) gain.
- Formulate RIS optimization problems.

---

#### 1. Introduction

The narrowband RIS communication model derived previously is

$$
y= \left(h_d + \sum_{n=1}^{N} g_n\theta_nf_n \right)x + n $$

where:

- $h_d$ = direct channel
- $f_n$ = transmitter-to-RIS channel
- $g_n$ = RIS-to-receiver channel
- $\theta_n$ = RIS phase control coefficient

The primary goal of RIS beamforming is to select the phase shifts

$$
\theta_1,\theta_2,\ldots,\theta_N
$$

such that all reflected signals combine constructively at the receiver.

---

#### 2. Random Reflections vs Controlled Reflections

Without RIS control, reflected signals arrive with random phases.

The received reflected field is

$$
\sum_{n=1}^{N} g_nf_n
$$

Because phases are random:

- Some components add constructively.
- Some components cancel each other.

As a result, much of the reflected energy is wasted.

---

#### 3. Principle of Coherent Combining

Each reflected contribution can be written as

$$
g_n f_n = |g_n f_n|e^{j\phi_n}
$$

where

$$
\phi_n = \angle g_n + \angle f_n
$$

represents the total propagation phase.

The RIS can introduce an additional phase shift

$$
\theta_n=e^{-j\phi_n}
$$

so that

$$
g_n\theta_nf_n = |g_n||f_n|
$$

becomes purely real and positive.

All reflected components now arrive in phase.

---

#### 4. Optimal RIS Phase Design

The optimal RIS phase shift is

$$
\theta_n = e^{-j(\angle g_n+\angle f_n)}
$$

Substituting into the received signal model gives

$$
y=\left(h_d + \sum_{n=1}^{N} |g_n||f_n|\right)x+n
$$

All reflected paths now contribute constructively.

---

#### 5. Passive Beamforming

Traditional phased arrays employ:

- RF chains
- Mixers
- DACs
- Power amplifiers

RIS elements do not generate new signals.

Instead, they manipulate existing electromagnetic waves.

Therefore RIS performs

##### Passive Beamforming

Advantages:

- Very low power consumption
- No RF chains
- Low hardware complexity
- Scalable implementation

---

#### 6. Received Signal Enhancement

Assume each RIS element contributes approximately

$$
a
$$

units of signal amplitude.

The total received amplitude becomes

$$
A_{total} = Na
$$

Consequently,

$$
P_r = |A_{total}|^2
$$

giving

$$
P_r = N^2a^2
$$

Therefore

$$
P_r \propto N^2
$$

---

#### 7. RIS Gain Scaling Law

This result is known as the RIS quadratic power scaling law.

##### Conventional Reflection

Random phases:

$$
P_r \propto N
$$

##### RIS Reflection

Phase-aligned reflections:

$$
P_r \propto N^2
$$

This quadratic scaling is one of the major theoretical motivations for large RIS deployments.

---

#### 8. Beam Steering

The RIS can shape the reflected wavefront.

By selecting different phase distributions

$$
\theta_n
$$

across the surface, energy can be focused toward specific users.

This process is analogous to phased-array beamforming.

RIS therefore acts as a programmable electromagnetic mirror.

---

#### 9. RIS Optimization Problem

The general RIS optimization problem is

$$
\max_{\theta_n} \left| h_d+ \sum_{n=1}^{N} g_n\theta_nf_n \right|^2
$$

subject to

$$
|\theta_n|=1
$$

The constraint arises because RIS elements mainly control phase rather than amplification.

---

#### 10. Practical Considerations

The ideal model assumes:

- Continuous phase control
- Perfect channel knowledge
- Lossless reflections

Practical RIS hardware introduces:

- Quantized phase shifts
- Reflection losses
- Mutual coupling
- Channel estimation errors

These effects reduce achievable gain.

---

#### Daily Outcome

- Understood coherent combining.
- Derived optimal RIS phase shifts.
- Studied passive beamforming.
- Derived RIS power scaling laws.
- Explained the origin of the \(N^2\) gain.
- Formulated RIS optimization problems.
- Investigated practical hardware limitations.

---

### Day 20 (June 12, 2026): Spatial Channel Structure, Channel Estimation, and Future RIS Systems

#### Objectives

- Understand spatial channel structure.
- Study array response vectors.
- Investigate low-rank channel models.
- Understand RIS channel estimation challenges.
- Learn parameter reduction techniques.
- Study RIS limitations.
- Explore RIS applications in OTFS and 6G systems.

---

#### 1. Introduction

Large RIS deployments may contain hundreds or thousands of reflecting elements.

Estimating every channel coefficient individually becomes computationally expensive.

Fortunately, wireless channels possess geometric and spatial structure that can be exploited.

Understanding this structure is essential for practical RIS systems.

---

#### 2. Spatial Channel Structure

Wireless propagation is not completely random.

Signals often arrive from a small number of dominant directions.

These dominant paths create spatial correlation across antenna arrays and RIS elements.

Consequently, the channel can often be represented using a small number of parameters.

---

#### 3. Array Response Vectors

Consider a Uniform Linear Array (ULA).

The steering vector is

$$
a(\theta) = \begin{bmatrix} 1\\
e^{jkd\sin\theta}\\
e^{j2kd\sin\theta}\\
\vdots\\
e^{j(M-1)kd\sin\theta}
\end{bmatrix}
$$

where

- $M$ = number of antennas
- $d$ = antenna spacing
- $k=\frac{2\pi}{\lambda}$

This vector describes how a signal arriving from angle

$$
\theta
$$

appears across the array.

---

#### 4. Geometric Channel Representation

Many wireless channels can be represented as

$$
H = \sum_{\ell=1}^{L} \alpha_\ell a_r(\theta_\ell) a_t^H(\phi_\ell)
$$

where

- $L$ = number of dominant paths
- $\alpha_\ell$ = path gain
- $a_r$ = receive steering vector
- $a_t$ = transmit steering vector

---

### 5. Low-Rank Channel Models

Typically

$$
L \ll M,N
$$

where:

- $M$ = transmitter antennas
- $N$ = RIS elements

The channel therefore possesses a low-rank structure.

Instead of estimating thousands of coefficients, only a small number of physical parameters must be estimated.

---

#### 6. RIS Channel Estimation Challenge

The RIS-assisted channel contains:

- Direct channel
- TX-RIS channel
- RIS-RX channel

For large RIS arrays, the number of unknown parameters becomes extremely large.

For example:

$$
N=1000
$$

may require estimation of thousands of channel coefficients.

This remains one of the largest challenges in RIS communication systems.

---

### 7. Parameter Reduction Techniques

Several approaches exploit channel structure:

##### Sparsity-Based Methods

Only dominant paths are estimated.

##### Geometric Models

Angles and path gains are estimated instead of full matrices.

##### Compressed Sensing

Sparse recovery algorithms reduce pilot overhead.

##### Low-Rank Approximation

Channel matrices are represented using a small number of basis vectors.

---

#### 8. Practical RIS Limitations

Despite its advantages, RIS technology faces several practical challenges.

##### Reflection Losses

Not all incident energy is reflected.

##### Quantized Phase Control

Many RIS elements provide only:

- 1-bit control
- 2-bit control
- 3-bit control

rather than continuous phase adjustment.

##### Mutual Coupling

Neighboring elements interact electromagnetically.

##### Channel Estimation

Accurate CSI acquisition remains difficult.

---

#### 9. RIS vs Massive MIMO

##### Massive MIMO

Advantages:

- Active beamforming
- High performance
- Mature technology

Disadvantages:

- High power consumption
- Expensive RF chains

---

##### RIS

Advantages:

- Passive operation
- Low power consumption
- Low hardware complexity

Disadvantages:

- Limited control capability
- CSI acquisition challenges

Future wireless systems may combine RIS and Massive MIMO.

---

#### 10. RIS and OTFS

RIS technology is highly relevant for OTFS systems.

OTFS operates in the Delay-Doppler domain and is designed for:

- High mobility
- Time-varying channels
- Future 6G applications

Potential combinations include:

- RIS-assisted OTFS
- High-speed railway communication
- UAV communication
- Vehicular communication
- Satellite communication

RIS can improve propagation conditions while OTFS improves robustness against mobility.

---

#### 11. RIS and 6G Networks

Future applications include:

- Smart radio environments
- Intelligent wireless propagation
- Joint communication and sensing
- Holographic MIMO
- AI-assisted RIS optimization
- Energy-efficient communication systems

The long-term vision is to transform the wireless environment into a programmable communication resource.

---

#### 12. Overall Lecture Summary

The complete RIS signal-processing framework consists of:

1. Wireless propagation physics.
2. Signal and system modeling.
3. RIS hardware fundamentals.
4. End-to-end RIS channel models.
5. Beamforming and coherent combining.
6. Channel optimization.
7. Spatial channel structure.
8. Channel estimation.
9. Future 6G applications.

RIS transforms the communication environment from a passive obstacle into an active and controllable component of the wireless system.

---

#### Daily Outcome

- Studied spatial channel structure.
- Learned array response modeling.
- Investigated low-rank channel representations.
- Understood RIS channel estimation challenges.
- Examined practical RIS limitations.
- Compared RIS and Massive MIMO.
- Explored RIS-assisted OTFS systems.
- Completed the study of the RIS signal-processing lecture.

---
