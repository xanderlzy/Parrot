"""Synthesizes Parrot's start/stop clicks: ~70 ms soft sine glides with a smooth envelope."""
import math, struct, sys, wave

def blip(path, f0, f1, ms=70, rate=48000, gain=0.5):
    n = int(rate * ms / 1000)
    phase, frames = 0.0, bytearray()
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t
        phase += 2 * math.pi * f / rate
        env = math.sin(math.pi * min(1.0, t * 4)) if t < 0.25 else (1 - t) ** 2 / 0.5625
        overtone = 0.25 * math.sin(phase * 2)
        frames += struct.pack('<h', int(32767 * gain * env * (math.sin(phase) + overtone) / 1.25))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(bytes(frames))

out = sys.argv[1]
blip(f"{out}/start.wav", 880, 1320)
blip(f"{out}/stop.wav", 1320, 880)
