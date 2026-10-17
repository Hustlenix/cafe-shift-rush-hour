"""Author tiny original counter cues with oscillators; no external audio assets."""
from pathlib import Path
import math
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets/original'
CUES = {
    'arrival': [659, 880], 'walkout': [330, 247, 196],
    'prepare': [440, 554], 'perfect': [784, 988, 1175],
    'lunch': [392, 392, 523, 659], 'vip': [523, 659, 784, 1047],
    'challenge': [659, 784, 659, 988], 'failure': [392, 330, 262, 196],
}
for name, notes in CUES.items():
    samples = []
    for frequency in notes:
        duration = .105 if name != 'failure' else .17
        for i in range(int(22050 * duration)):
            t = i / 22050
            envelope = min(1, t / .009) * (1 - t / duration) ** 2
            tone = math.sin(math.tau * frequency * t) + .18 * math.sin(math.tau * frequency * 2 * t)
            samples.append(int(6000 * envelope * tone))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, 22050, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print(f'Authored {len(CUES)} feedback cues')
