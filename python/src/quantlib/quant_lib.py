"""
Quantization helper library for notebook-based fixed-point emulation.
Place this file in `scripts/python/` and import from your notebooks.
"""

from typing import Tuple, Dict, Iterable, Callable, List
import numpy as np


def quantize(x: np.ndarray, F: int, bits: int) -> np.ndarray:
    """Quantize a floating-point array to signed integer representation.

    Args:
        x: input float array
        F: number of fractional bits
        bits: total bits for signed representation (including sign)

    Returns:
        q: np.int64 ndarray of quantized values
    """
    scale = 1 << F
    q_raw = np.round(x * scale).astype(np.int64)
    minv = -(1 << (bits - 1))
    maxv = (1 << (bits - 1)) - 1
    q = np.clip(q_raw, minv, maxv)
    return q


def dequantize(q: np.ndarray, F: int) -> np.ndarray:
    """Convert integer quantized values back to floating point."""
    return q.astype(np.float32) / (1 << F)


def quantize_complex(x: np.ndarray, F: int, bits: int) -> Tuple[np.ndarray, np.ndarray, np.ndarray, Dict]:
    """Quantize a complex-valued floating array into integer real/imag parts.

    Args:
        x: complex-valued ndarray (float real+imag)
        F: fractional bits for fixed-point scaling
        bits: total signed bitwidth for stored integers

    Returns:
        q_re: np.ndarray of int64 quantized real parts
        q_im: np.ndarray of int64 quantized imag parts
        deq: np.ndarray of complex float dequantized values
        stats: dict with keys {'rmse', 'clip_real', 'clip_im', 're_stats', 'im_stats'}
    """
    if not np.iscomplexobj(x):
        raise ValueError("quantize_complex expects a complex-valued ndarray")

    re = x.real.astype(np.float32)
    im = x.imag.astype(np.float32)

    scale = 1 << F
    minv = -(1 << (bits - 1))
    maxv = (1 << (bits - 1)) - 1

    # Quantize real and imag separately, while also counting true saturation events.
    q_re_raw = np.round(re * scale).astype(np.int64)
    q_im_raw = np.round(im * scale).astype(np.int64)
    clip_real = int(np.sum((q_re_raw < minv) | (q_re_raw > maxv)))
    clip_im = int(np.sum((q_im_raw < minv) | (q_im_raw > maxv)))
    q_re = np.clip(q_re_raw, minv, maxv)
    q_im = np.clip(q_im_raw, minv, maxv)

    # Dequantize back to float complex
    deq_re = dequantize(q_re, F)
    deq_im = dequantize(q_im, F)
    deq = deq_re + 1j * deq_im

    # Compute statistics
    rmse = float(np.sqrt(np.mean(np.abs(x - deq) ** 2)))
    stats = {
        "rmse": rmse,
        "clip_real": clip_real,
        "clip_im": clip_im,
        "re_stats": compute_stats(re),
        "im_stats": compute_stats(im),
    }

    return q_re, q_im, deq, stats


def saturating_add(a: np.ndarray, b: np.ndarray, bits: int) -> np.ndarray:
    """Elementwise saturating add of two integer arrays with given bitwidth."""
    s = a.astype(np.int64) + b.astype(np.int64)
    minv = -(1 << (bits - 1))
    maxv = (1 << (bits - 1)) - 1
    s = np.clip(s, minv, maxv)
    return s.astype(np.int64)


def saturating_mul(a: np.ndarray, b: np.ndarray, out_bits: int) -> np.ndarray:
    """Elementwise multiply with saturation to out_bits signed width.

    Note: inputs should already be in integer domain (scaled by some F).
    The caller must account for the resulting scaling (sum of fractional bits).
    """
    p = a.astype(np.int64) * b.astype(np.int64)
    minv = -(1 << (out_bits - 1))
    maxv = (1 << (out_bits - 1)) - 1
    p = np.clip(p, minv, maxv)
    return p.astype(np.int64)


def compute_stats(x: np.ndarray) -> Dict[str, float]:
    """Compute basic statistics for a floating-point array."""
    return {
        "min": float(np.min(x)),
        "max": float(np.max(x)),
        "rms": float(np.sqrt(np.mean(np.square(x)))),
        "ptp": float(np.ptp(x)),
    }


def histogram(x: np.ndarray, bins: int = 100) -> Tuple[np.ndarray, np.ndarray]:
    """Return histogram counts and bin edges for `x`."""
    counts, edges = np.histogram(x, bins=bins)
    return counts, edges


def sweep_fractional_bits(
    x: np.ndarray,
    bits: int,
    F_candidates: Iterable[int],
    metric: Callable[[np.ndarray, np.ndarray], float] = None,
) -> List[Dict]:
    """Sweep fractional bit choices for `x` and return error metrics vs original float.

    Args:
        x: original floating point signal
        bits: total bits for signed representation
        F_candidates: iterable of fractional-bit choices to try
        metric: function(original, dequant) -> error metric (default RMSE)

    Returns:
        list of dicts with fields {F, q, deq, metric}
    """
    if metric is None:
        def metric(a, b):
            return float(np.sqrt(np.mean((a - b) ** 2)))

    results = []
    for F in F_candidates:
        q = quantize(x, F, bits)
        deq = dequantize(q, F)
        m = metric(x, deq)
        results.append({"F": int(F), "bits": int(bits), "rmse": m, "deq": deq, "q": q})
    return results


def save_hls_coeffs(coeffs: np.ndarray, filename: str, fmt: str = "hex", F: int = 0, bits: int = 16):
    """Save coefficient array in a simple HLS-friendly format (hex or csv).

    If `F>0` the coeffs are quantized using fixed-point scaling before export.
    """
    if F > 0:
        q = quantize(coeffs, F, bits)
    else:
        q = coeffs.astype(np.int64)

    with open(filename, "w") as f:
        if fmt == "hex":
            for val in q.flatten():
                # Convert to two's complement fixed width hex
                mask = (1 << bits) - 1
                hexval = format(int(val) & mask, "0{}x".format((bits + 3) // 4))
                f.write(hexval + "\n")
        elif fmt == "csv":
            np.savetxt(f, q.flatten(), fmt="%d", delimiter=",")
        else:
            raise ValueError("Unsupported format: " + fmt)


if __name__ == "__main__":
    # quick smoke test
    import numpy as _np
    _np.random.seed(0)
    x = (_np.random.randn(1024) * 0.1).astype(_np.float32)
    F = 12
    bits = 16
    q = quantize(x, F, bits)
    deq = dequantize(q, F)
    print("RMSE:", float(_np.sqrt(_np.mean((x - deq) ** 2))))
