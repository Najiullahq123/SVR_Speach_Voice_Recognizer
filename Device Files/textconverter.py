import os
import sys
import tempfile
import time
import speech_recognition as sr
import openai

print("Starting script...")

# Suppress ALSA error messages
try:
    devnull = os.open(os.devnull, os.O_WRONLY)
    os.dup2(devnull, 2)
    print("ALSA suppression set up successfully.")
except Exception as e:
    print(f"Error setting up ALSA suppression: {e}")

# Set your OpenAI API key
openai.api_key = "Your Open Ai Key"
print("OpenAI API key configured.")

# Define the audio file path (fixed .wav file in /home/pi)
help_audio_file = "/home/pi/helpaudio.wav"
if not os.path.exists(help_audio_file):
    print(f"Warning: {help_audio_file} not found. Generating fallback audio with espeak...")
    try:
        os.system("espeak 'Help is Coming' -s 150 -w /home/pi/helpaudio.wav")
        print(f"Created fallback audio file: {help_audio_file}")
    except Exception as e:
        print(f"Error creating fallback audio: {e}")
        sys.exit(1)
else:
    print(f"Using existing audio file: {help_audio_file}")

# List available microphones and dynamically select ReSpeaker
print("Available microphones:")
try:
    mic_list = sr.Microphone.list_microphone_names()
    for i, mic_name in enumerate(mic_list):
        print(f"{i}: {mic_name}")
    # Find ReSpeaker by name
    mic_index = None
    for i, mic_name in enumerate(mic_list):
        if "ReSpeaker" in mic_name or "UAC1.0" in mic_name:
            mic_index = i
            break
    if mic_index is None:
        print("Error: ReSpeaker microphone not found.")
        sys.exit(1)
    print(f"Selected ReSpeaker microphone at index {mic_index}: {mic_list[mic_index]}")
except Exception as e:
    print(f"Error listing microphones: {e}")
    sys.exit(1)

# Initialize microphone
try:
    recognizer = sr.Recognizer()
    mic = sr.Microphone(device_index=mic_index)
    print(f"Microphone initialized with index {mic_index}: {mic_list[mic_index]}")
except Exception as e:
    print(f"Error initializing microphone: {e}")
    sys.exit(1)

# Get ALSA playback devices and dynamically select MAX98357A
try:
    # Run aplay -l and parse output
    aplay_output = os.popen("aplay -l").read()
    playback_device = None
    for line in aplay_output.splitlines():
        if "MAX98357A" in line:
            # Extract card and device number (e.g., card 2: MAX98357A ... device 0)
            card_num = line.split("card ")[1].split(":")[0]
            device_num = line.split("device ")[1].split(":")[0]
            playback_device = f"plughw:{card_num},{device_num}"
            break
    if playback_device is None:
        print("Error: MAX98357A playback device not found. Falling back to plughw:2,0")
        playback_device = "plughw:2,0"
    print(f"Selected playback device: {playback_device}")
except Exception as e:
    print(f"Error detecting playback devices: {e}")
    playback_device = "plughw:2,0"  # Fallback
    print(f"Falling back to playback device: {playback_device}")

print("Ready! Speak into your ReSpeaker microphone...")

# Keyword to detect
KEYWORD = "help"

while True:
    with mic as source:
        print("Listening...")
        try:
            # Listen with a timeout and phrase limit
            audio = recognizer.listen(source, timeout=5, phrase_time_limit=8)
            print("Audio captured successfully.")
        except sr.WaitTimeoutError:
            print("No speech detected within timeout.")
            continue
        except Exception as e:
            print(f"Error capturing audio: {e}")
            continue

    try:
        # Save audio to temporary WAV file (required for Whisper)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            tmp.write(audio.get_wav_data())
            tmp_filename = tmp.name
        print(f"Audio saved to temporary file: {tmp_filename}")

        # Transcribe audio using Whisper with US English
        with open(tmp_filename, "rb") as f:
            transcript = openai.audio.transcriptions.create(
                model="whisper-1",
                file=f,
                language="en"
            )
        text = transcript.text.lower()
        print(f"You said: {text}")

        # Check for the keyword "help"
        if KEYWORD in text:
            print("Keyword 'help' detected!")
            # Play helpaudio.wav three times with 2-second gaps
            for i in range(3):
                try:
                    os.system(f"aplay -D {playback_device} {help_audio_file}")
                    print(f"Played helpaudio.wav ({i+1}/3)")
                    time.sleep(2)  # 2-second gap between plays
                except Exception as e:
                    print(f"Error playing audio: {e}")
        else:
            print("No 'help' keyword detected.")

        # Clean up temporary file
        os.remove(tmp_filename)
        print("Temporary file cleaned up.")

    except openai.error.OpenAIError as e:
        print(f"OpenAI API error: {e}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        # Restore stderr for error logging
        sys.stderr = sys.__stderr__
