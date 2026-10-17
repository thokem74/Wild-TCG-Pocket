"""Generate original battle cues using only the Python standard library."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
random.seed(1986)


def write(name, duration, notes, noise=0.0):
    samples = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        beat = t % 0.25
        frequency = notes[int(t / 0.25) % len(notes)]
        envelope = min(t * 100, 1) * min((duration - t) * 30, 1)
        if duration < 3:
            envelope *= math.exp(-3 * t / duration)
        tone = (math.sin(2 * math.pi * frequency * t)
                + 0.25 * math.sin(4 * math.pi * frequency * t))
        if duration > 3:
            tone *= 0.4 + 0.6 * math.exp(-beat * 18)
            tone += 0.3 * math.sin(2 * math.pi * frequency / 2 * t)
        value = (tone * 0.28 + random.uniform(-1, 1) * noise) * envelope
        samples.append(struct.pack('<h', int(max(-0.95, min(0.95, value)) * 32767)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(b''.join(samples))


write('battle', 16, [164.81, 196, 246.94, 196, 146.83, 185, 220, 185])
for name, duration, notes, noise in [
    ('windup', .2, [180, 360], .05),
    ('flame', .34, [90, 60], .4), ('tide', .38, [220, 110], .22),
    ('gale', .3, [440, 660], .28), ('knockout', .5, [100, 55], .3),
    ('attach', .3, [440, 880], 0), ('heal', .45, [523, 659], 0),
    ('boost', .35, [330, 660], .03), ('draw', .2, [700], .08),
    ('deploy', .3, [220, 440], .04), ('retreat', .3, [660, 330], .06),
    ('turn', .35, [392, 523], 0), ('victory', 1.2, [523, 659, 784, 1046], 0),
    ('defeat', 1.2, [392, 349, 311, 261], 0), ('draw_result', .8, [440, 523, 440], 0),
]:
    write(name, duration, notes, noise)
