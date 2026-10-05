// rnnoise: noise suppression for XQ — RNNoise, Xiph's recurrent network, called through `declare
// library`. It takes keyboards, fans and the street out of speech, 10 ms at a time, and says how likely
// each 10 ms are speech, so that a microphone may send only while someone speaks. The library is built
// from the sources of a release (https://github.com/xiph/rnnoise/releases): librnnoise.so on Linux,
// rnnoise.dll on PATH or next to the program on Windows. Without it `denoiser()` gives none.
import * as ffi from "std/ffi";

declare library "rnnoise" {
  function rnnoise_create(model: Pointer | null): Pointer;
  function rnnoise_process_frame(st: Pointer, inout out: Float32Array, input: Float32Array): f32;
  function rnnoise_destroy(st: Pointer): void;
}

/** Samples RNNoise takes at a time: 10 ms at 48 kHz. */
export const FRAME = 480;
/** Ten milliseconds are likely speech over this. */
export const SPEECH = 0.5;
/** How much later the sound comes out than it went in, µs: RNNoise judges each 10 ms by the 10 ms after
 * them too, and its frames overlap. */
export const DELAY = 20000;

export type Denoiser = { st: Pointer };

/** A suppressor, if the library is there. */
export function denoiser(): Denoiser | null {
  if (!ffi.loads("rnnoise")) return null;
  return { st: rnnoise_create(null) };
}

/** Frame `pcm` (a whole number of 10 ms) with the noise taken out, and how likely each 10 ms of it is
 * speech. Samples go in and come out at the scale of 16 bits, as RNNoise takes them. */
export function denoise(d: Denoiser, pcm: Int16Array): [Int16Array, float[]] {
  const parts = range(0, pcm.length / FRAME).map((k): [float, Float32Array] => {
    const input = Float32Array.from(pcm.subarray(k * FRAME, (k + 1) * FRAME));
    return rnnoise_process_frame(d.st, new Float32Array(FRAME), input);
  });
  // Clipped: a sample past 16 bits would wrap round to the other end, a crack.
  const out = range(0, parts.length).reduce(
    (all: Int16Array, k) =>
      all.set(
        Int16Array.from(parts[k][1], (x) => Math.max(-32768.0, Math.min(32767.0, x))),
        k * FRAME,
      ),
    new Int16Array(pcm.length),
  );
  return [out, parts.map(([p, _]) => p)];
}

/** Whether speech goes on: two of three tens of milliseconds in a row likely speech, of those of the
 * frame and the two before it (`probs`, oldest first) — a keystroke alone sometimes looks like speech for
 * ten milliseconds, speech never stops at that. */
export function speaks(probs: float[]): bool {
  return range(0, Math.max(0, probs.length - 2)).some((i) =>
    probs.slice(i, i + 3).filter((p) => p >= SPEECH).length >= 2,
  );
}

export function free(d: Denoiser): void {
  rnnoise_destroy(d.st);
}
