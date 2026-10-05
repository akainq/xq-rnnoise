# rnnoise

Noise suppression for [XQ](https://akainq.github.io/xq/) with [RNNoise](https://github.com/xiph/rnnoise), Xiph's
recurrent network: it takes keyboards, fans and the street out of speech, 10 ms at a time, and says how likely each
10 ms are speech — so that a microphone may send only while someone speaks.

```bash
xq add rnnoise
```

```ts
import * as rnnoise from "rnnoise";

function main(): void {
  const d = rnnoise.denoiser();
  if (d === null) {
    console.log("no RNNoise here");
    return;
  }
  // 20 ms of 48 kHz: two of RNNoise's frames.
  const [clean, likely] = rnnoise.denoise(d, new Int16Array(960));
  console.log(`${clean.length} samples, speech: ${rnnoise.speaks(likely)}`);
  rnnoise.free(d);
}
```

## Functions

| Function | What it does |
|---|---|
| `FRAME`, `SPEECH`, `DELAY` | 480 samples a frame (10 ms at 48 kHz); a frame is likely speech over 0.5; the sound comes out 20 ms later than it went in, µs |
| `denoiser(): Denoiser \| null` | a suppressor, if the library is there |
| `denoise(d: Denoiser, pcm: Int16Array): [Int16Array, float[]]` | samples of 48 kHz (a whole number of frames) with the noise taken out, and how likely each frame of them is speech, 0 to 1 |
| `speaks(probs: float[]): bool` | whether speech goes on: two of three frames in a row likely speech, of `probs`, oldest first — a keystroke alone sometimes looks like speech for 10 ms, speech never stops at that |
| `free(d: Denoiser)` | the suppressor's memory back to the library |

## The library

The package calls RNNoise through `declare library "rnnoise"`. It is built from the sources of a release
([xiph/rnnoise](https://github.com/xiph/rnnoise/releases), 0.2 with its model): `librnnoise.so` on Linux, in a
directory the loader searches (`/usr/local/lib`, then `ldconfig`), `rnnoise.dll` on Windows, on `PATH` or next to
the program. Without it `denoiser()` gives `null`.

## Tests

```bash
xq test
```

Typing — a key's click of noise with a thump, and its release 70 ms later, five keys a second, as loud as close to a
microphone — goes through in 20 ms frames: it comes out at least 15 dB quieter and is never taken for speech, though
RNNoise takes some of its 10 ms for speech. Without the library the test is skipped.

## License

MIT OR Apache-2.0, at your option: [LICENSE-MIT](LICENSE-MIT), [LICENSE-APACHE](LICENSE-APACHE). RNNoise itself is
Xiph's, under the BSD license.
