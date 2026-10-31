# PianissimoPi

A headless Raspberry Pi box that turns a USB MIDI keyboard (a Nektar SE49) into a grand piano. Plug the keyboard into the Pi, plug speakers or headphones into the Pi's audio output, power it on, and play. No screen or computer needed.

## Why a Raspberry Pi and not an Arduino

A good grand piano sound is hundreds of megabytes of recorded samples, mixed live across dozens of notes at once. An Arduino has a few kilobytes of RAM and no USB host port for the keyboard, so it can't do this. A Pi runs [FluidSynth](https://www.fluidsynth.org/), a sample-based synth, with the free [Salamander Grand Piano](https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html) (a Yamaha C5, sampled at 16 velocity layers).

## Hardware

| Part | Notes |
|---|---|
| Raspberry Pi 4 (2 GB+) or Pi 5 | The piano soundfont is loaded into RAM. A Pi 3 works with lower `POLYPHONY`. |
| microSD card, 16 GB+ | Flash Raspberry Pi OS **Lite** (64-bit) with Raspberry Pi Imager. Turn on SSH and Wi-Fi in the Imager settings. |
| Official power supply | Undervoltage causes audio dropouts. |
| Audio output (pick one) | **USB audio interface or USB DAC**: simplest and sounds good. **HiFiBerry DAC+ / DAC2 HAT**: clean and compact. **Pi 4 headphone jack**: works for testing but is noisy. The Pi 5 has no analog jack. |
| Nektar SE49 + USB cable | It's USB class-compliant and is powered by the Pi. |

## Install

On the Pi:

```bash
git clone <this repo> pianissimopi && cd pianissimopi
```

```bash
sudo ./install.sh
```

The installer:
1. Installs FluidSynth and ALSA tools.
2. Downloads the Salamander Grand Piano SF2 (about 310 MB). If the download fails, it uses the FluidR3 GM piano instead.
3. Installs a `pianissimopi` systemd service that starts the synth at boot.
4. Adds a udev rule so the keyboard connects whenever it's plugged in, including after the Pi has booted.

## Uninstall

```bash
sudo ./uninstall.sh
```

This stops the synth, restores the CPU's normal speed setting, and removes the scripts, services, udev rule, and service user. It keeps your settings and the piano samples so a reinstall is quick. To remove those as well:

```bash
sudo ./uninstall.sh --purge
```

FluidSynth itself stays installed; the script prints the command to remove it.

## Choose the audio output

List the sound cards:

```bash
aplay -l
```

Each card shows up as a line like:

```
card 1: Device [USB Audio Device], device 0: USB Audio [USB Audio]
```

The card's name is the word after `card 1:`, here `Device`. ALSA needs it written as `plughw:CARD=Device`; a bare `Device` gives an "Unknown PCM" error. Only one program can use the card at a time, so stop PianissimoPi first if it's running (otherwise you get "Device or resource busy"), then test:

```bash
sudo systemctl stop pianissimopi
```

```bash
speaker-test -D plughw:CARD=Device -c2 -t wav
```

You should hear "front left, front right" (Ctrl+C to stop). If it's silent, run `alsamixer -c Device` and make sure the output isn't muted (press `M`) or at zero.

Set `AUDIO_DEVICE` in `/etc/pianissimopi.conf` to the same value, for example `plughw:CARD=Device` for a USB sound card like the Sabrent or `plughw:CARD=sndrpihifiberry` for a HiFiBerry. Then restart:

```bash
sudo systemctl restart pianissimopi
```

For a HiFiBerry HAT, also add its overlay to `/boot/firmware/config.txt` (for example `dtoverlay=hifiberry-dacplus`) and reboot.

## Settings

All settings are in `/etc/pianissimopi.conf`:

- **Latency**: `PERIOD_SIZE` × `PERIODS` / `SAMPLE_RATE`. The default is about 4 ms. If you hear clicks or crackles, raise `PERIOD_SIZE` to 128 (about 8 ms) or 256.
- **Volume**: `GAIN`. Raise it carefully; loud chords with the pedal down can clip.
- **Reverb**: `REVERB`, `ROOM_SIZE`, `REVERB_LEVEL`.
- **Voices**: `POLYPHONY`. Lower it if a Pi 3 struggles.
- **CPU speed**: `CPU_GOVERNOR=performance` keeps the CPU at full speed while the synth runs, because the Pi's normal speed changes can cause clicks. The original setting comes back when the synth stops. Full speed makes the Pi run warmer, so use a heatsink or a case with a fan. Set `CPU_GOVERNOR=` (empty) to leave the CPU alone.
- **Which keyboard**: `MIDI_MATCH=SE49` connects only devices whose name contains "SE49". Leave it empty to connect any keyboard.

The SE49's sustain pedal input (CC64) and velocity work without any setup. To change how hard you have to play, set the SE49's velocity curve on the keyboard itself (see its manual).

## Troubleshooting

```bash
journalctl -u pianissimopi -u pianissimopi-connect -f
```

```bash
aconnect -l
```

- **No sound, but the keyboard is connected**: wrong `AUDIO_DEVICE`. Stop the synth (`sudo systemctl stop pianissimopi`), then test the output with `speaker-test -D plughw:CARD=<name> -c2 -t wav`, using the card name from `aplay -l`.
- **"Device or resource busy"**: another program has the sound card open, usually PianissimoPi itself. `sudo fuser -v /dev/snd/*` shows which one.
- **Keyboard not connected**: check it appears in `aconnect -i`. If its name doesn't contain "SE49", fix `MIDI_MATCH`. Reconnect by hand with `sudo /usr/local/bin/pianissimopi-connect`.
- **Crackles**: raise `PERIOD_SIZE`, check the power supply (`vcgencmd get_throttled` should print `0x0`), and lower `POLYPHONY`. Check that the CPU is at full speed: `cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor` should print `performance`.

## Extras

The synth listens for FluidSynth shell commands on TCP port 9800, so you can adjust it live. For example, `echo "gain 0.8" | nc localhost 9800`, or `prog 0 <n>` to switch to another preset in the soundfont. Block that port on untrusted networks.

## Files

```
install.sh                            installer (run on the Pi)
uninstall.sh                          removes everything install.sh added
bin/pianissimopi-synth                starts FluidSynth with the settings from the config file
bin/pianissimopi-connect              connects MIDI keyboards to the synth
bin/pianissimopi-cpu                  sets the CPU governor while the synth runs, then restores it
config/pianissimopi.conf              default settings, copied to /etc/pianissimopi.conf
systemd/pianissimopi.service          runs the synth at boot
systemd/pianissimopi-connect.service  connects keyboards (started by the udev rule)
udev/90-pianissimopi-midi.rules       reconnects when a keyboard is plugged in
```
