// needs: rnnoise
// Noise suppression (RNNoise): typing — a key's click of noise with a thump, and its release 70 ms
// later, five keys a second, as loud as close to a microphone — goes through it in 20 ms frames, as a
// microphone captures them. A frame comes out as long as it
// went in, with how likely each 10 ms of it is speech; none of the typing is taken for speech, and it
// comes out at least 15 dB quieter. Speech goes on while two of three tens of milliseconds in a row are
// likely speech.
import * as denoise from "../lib";

const RATE = 48000;
const FRAME = 960;
/** A key every `KEY` samples (210 ms), its release `RELEASE` samples (70 ms) after; each a click of
 * `CLICK` samples (10 ms). */
const KEY = 10080;
const RELEASE = 3360;
const CLICK = 480;
const PEAK = 9000.0;

/** Noise in -1..1: a hash of the sample's number (of 31 bits, which multiply within 64). */
function noise(i: int): float {
  const a = ((i + 1) * 2654435761) & 0x7fffffff;
  const b = ((a ^ (a >> 15)) * 1274126177) & 0x7fffffff;
  const c = b ^ (b >> 13);
  return toFloat(c & 0xffff) / 32768.0 - 1.0;
}

/** A click `k` samples in, of peak `peak`: noise and a thump at 180 Hz, dying away. */
function click(i: int, k: int, peak: float): float {
  const env = Math.exp(-toFloat(k) / 60.0);
  return peak * env * (noise(i) + 0.5 * Math.sin((2.0 * Math.PI * 180.0 * toFloat(k)) / toFloat(RATE)));
}

/** Sample `i` of the typing. */
function typing(i: int): float {
  const k = i % KEY;
  if (k < CLICK) return click(i, k, PEAK);
  if (k >= RELEASE && k < RELEASE + CLICK) return click(i, k - RELEASE, PEAK / 2.0);
  return 0.0;
}

function rms(pcm: Int16Array): float {
  const sum = pcm.reduce((a, x) => a + toFloat(x) * toFloat(x), 0.0);
  return Math.sqrt(sum / toFloat(Math.max(pcm.length, 1)));
}

function main(): void {
  const d = denoise.denoiser();
  if (d === null) panic("no rnnoise");
  // Three seconds, frame after frame; the first 100 ms RNNoise learns the sound.
  const frames = range(0, (3 * RATE) / FRAME).map((f) =>
    Int16Array.from(range(f * FRAME, (f + 1) * FRAME).map((i) => toInt(Math.round(typing(i))))),
  );
  const out = frames.map((pcm) => denoise.denoise(d, pcm));
  console.log(
    "a frame comes out as long as it went in, a probability for each 10 ms:",
    out.every(([pcm, probs]) => pcm.length === FRAME && probs.length === 2),
  );
  // As the client judges: the frame's two tens of milliseconds and the two before.
  const probs = out.reduce((all: float[], [_, p]) => [...all, ...p], []);
  const speech = range(1, out.length).filter((f) => denoise.speaks(probs.slice(2 * f - 2, 2 * f + 2)));
  console.log("typing taken for speech:", speech.length, "frames");
  const db = (x: float, y: float) => (20.0 * Math.log(x / y)) / Math.log(10.0);
  const louder = frames.slice(5).map(rms).reduce((a, x) => a + x * x, 0.0);
  const quieter = out.slice(5).map(([pcm, _]) => rms(pcm)).reduce((a, x) => a + x * x, 0.0);
  const less = db(Math.sqrt(louder), Math.sqrt(quieter));
  console.log("typing at least 15 dB quieter:", less >= 15.0);
  console.log(
    "speech: two of three likely",
    denoise.speaks([0.9, 0.2, 0.8, 0.1]),
    denoise.speaks([0.9, 0.2, 0.1, 0.8]),
    denoise.speaks([0.1, 0.6, 0.7, 0.1]),
  );
  denoise.free(d);
}
