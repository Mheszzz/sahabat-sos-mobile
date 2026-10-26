#!/usr/bin/env python3
import os
import math
import wave
import struct

def generate_siren_wav():
    target_dir = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res', 'raw')
    os.makedirs(target_dir, exist_ok=True)
    target_file = os.path.join(target_dir, 'siren.wav')

    sample_rate = 44100
    duration = 2.0  # seconds
    freq1, freq2 = 800.0, 1300.0
    num_samples = int(sample_rate * duration)

    with wave.open(target_file, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        phase = 0.0
        for i in range(num_samples):
            t = i / sample_rate
            # 3 Hz siren pitch modulation
            freq = (freq1 + freq2) / 2 + ((freq2 - freq1) / 2) * math.sin(2 * math.pi * 3.0 * t)
            phase += 2 * math.pi * freq / sample_rate
            val = int(28000 * math.sin(phase))
            wav_file.writeframes(struct.pack('<h', val))

    print(f"Generated siren audio: {target_file}")

if __name__ == '__main__':
    generate_siren_wav()
