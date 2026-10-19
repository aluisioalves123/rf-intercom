// RF push-to-talk intercom (nRF24L01+PA+LNA)
// The same sketch runs on both units.
// Board: select "Arduino Nano" or "LGT8F328" in the Arduino IDE.
// Library: RF24 (TMRh20)
//
// Wiring (intercom.kicad_pcb):
//   D2   push-to-talk button (to GND)
//   D7   nRF24 CE
//   D8   nRF24 CSN
//   D9   audio out (PWM) -> R7 -> volume pot -> PAM8403
//   A0   microphone (BC547 preamp output)
//   D11  MOSI, D12 MISO, D13 SCK (nRF24 SPI)

#include <SPI.h>
#include <RF24.h>

// ---------- pins ----------
const byte PTT_BUTTON_PIN = 2;
const byte RADIO_CE_PIN   = 7;
const byte RADIO_CSN_PIN  = 8;
const byte AUDIO_OUT_PIN  = 9;      // OC1A
const byte MIC_PIN        = A0;

// ---------- tuning ----------
const unsigned long SAMPLE_PERIOD_US = 125;   // 8000 samples per second
const byte RADIO_CHANNEL = 100;               // above the Wi-Fi channels
const int  MIC_GAIN = 4;                      // talker volume: 2 (quiet) to 8 (loud)
const byte PLAYBACK_START_THRESHOLD = 96;     // samples buffered before playback starts
const unsigned long RECEIVE_TIMEOUT_MS = 150; // silence that ends a transmission
const byte PACKET_SIZE = 32;                  // nRF24 maximum payload

const byte RADIO_ADDRESS[6] = "INTF1";

RF24 radio(RADIO_CE_PIN, RADIO_CSN_PIN);

// ---------- playback ring buffer (256 bytes, byte indices wrap around on their own) ----------
volatile byte playbackBuffer[256];
volatile byte playbackReadIndex = 0;
volatile byte playbackWriteIndex = 0;
volatile byte lastPlayedSample = 128;

// ---------- state ----------
bool isTalking = false;
bool isPlaying = false;
unsigned long nextSampleTimeUs = 0;
unsigned long lastPacketReceivedMs = 0;
long micDcLevelTimes64 = 512L << 6;   // slow average of the mic signal (x64), used to remove the DC offset
byte outgoingPacket[PACKET_SIZE];
byte outgoingPacketLength = 0;

bool lastRawButtonState = false;
unsigned long buttonChangedAtMs = 0;
const unsigned long BUTTON_DEBOUNCE_MS = 20;

// ================= audio output =================

void enableAudioPwm() {
  pinMode(AUDIO_OUT_PIN, OUTPUT);
  OCR1A = 128;
  TCCR1A = _BV(COM1A1) | _BV(WGM10);    // 8-bit fast PWM on D9
  TCCR1B = _BV(WGM12) | _BV(CS10);      // no prescaler
}

void releaseAudioPin() {
  TCCR1A &= ~_BV(COM1A1);               // disconnect PWM from the pin
  digitalWrite(AUDIO_OUT_PIN, LOW);
  pinMode(AUDIO_OUT_PIN, INPUT);        // floating pin: no idle hiss
}

void setupPlaybackTimer() {             // Timer2 interrupt at 8 kHz
  TCCR2A = _BV(WGM21);                  // CTC mode
#if (F_CPU / 8 / 8000) <= 256
  TCCR2B = _BV(CS21);                   // prescaler 8
  OCR2A = (F_CPU / 8 / 8000) - 1;
#else
  TCCR2B = _BV(CS21) | _BV(CS20);       // prescaler 32 (LGT at 32 MHz)
  OCR2A = (F_CPU / 32 / 8000) - 1;
#endif
  TIMSK2 = 0;                           // starts disabled
}

ISR(TIMER2_COMPA_vect) {
  if (playbackReadIndex != playbackWriteIndex) {
    lastPlayedSample = playbackBuffer[playbackReadIndex];
    playbackReadIndex++;
  }
  OCR1A = lastPlayedSample;
}

void startPlayback() {
  enableAudioPwm();
  TCNT2 = 0;
  TIMSK2 = _BV(OCIE2A);
  isPlaying = true;
}

void stopPlayback() {
  TIMSK2 = 0;
  releaseAudioPin();
  playbackReadIndex = playbackWriteIndex;
  lastPlayedSample = 128;
  isPlaying = false;
}

// short ~880 Hz beep when the button is pressed
void playTalkBeep() {
  enableAudioPwm();
  unsigned long startMs = millis();
  bool high = false;
  while (millis() - startMs < 120) {
    high = !high;
    OCR1A = high ? 60 : 0;
    delayMicroseconds(568);
  }
  releaseAudioPin();
}

// ================= modes =================

void enterTalkMode() {
  stopPlayback();
  radio.stopListening();
  outgoingPacketLength = 0;
}

void enterListenMode() {
  radio.txStandBy();
  radio.startListening();
}

// ================= microphone =================

byte readMicSample() {
  int raw = analogRead(MIC_PIN);                       // 0 to 1023
  micDcLevelTimes64 += raw - (micDcLevelTimes64 >> 6); // slow running average
  int sample = raw - (int)(micDcLevelTimes64 >> 6);    // keep only the varying part
  sample = (sample * MIC_GAIN) / 4 + 128;
  if (sample < 0) sample = 0;
  if (sample > 255) sample = 255;
  return (byte)sample;
}

// ================= setup and loop =================

void setup() {
  Serial.begin(115200);
  pinMode(PTT_BUTTON_PIN, INPUT_PULLUP);
  pinMode(10, OUTPUT);                  // D10 as output keeps the SPI in master mode
  releaseAudioPin();

#if defined(__LGT8F__)
  analogReadResolution(10);
#else
  ADCSRA = (ADCSRA & 0xF8) | 0x05;      // faster ADC (prescaler 32)
#endif

  if (!radio.begin()) {
    Serial.println(F("nRF24 not responding, check the wiring"));
    while (true) {}
  }
  radio.setChannel(RADIO_CHANNEL);
  radio.setDataRate(RF24_250KBPS);
  radio.setPALevel(RF24_PA_LOW);        // LOW is plenty inside a house (HIGH or MAX for longer range)
  radio.setAutoAck(false);
  radio.setCRCLength(RF24_CRC_16);
  radio.setPayloadSize(PACKET_SIZE);
  radio.openWritingPipe(RADIO_ADDRESS);
  radio.openReadingPipe(1, RADIO_ADDRESS);
  radio.startListening();

  setupPlaybackTimer();
  Serial.println(F("intercom ready"));
}

void loop() {
  // ---- push-to-talk button with debounce ----
  bool rawButtonPressed = (digitalRead(PTT_BUTTON_PIN) == LOW);
  if (rawButtonPressed != lastRawButtonState) {
    lastRawButtonState = rawButtonPressed;
    buttonChangedAtMs = millis();
  }
  bool buttonPressed = (millis() - buttonChangedAtMs > BUTTON_DEBOUNCE_MS) ? rawButtonPressed : isTalking;

  if (buttonPressed && !isTalking) {
    enterTalkMode();
    playTalkBeep();
    isTalking = true;
    nextSampleTimeUs = micros();
  } else if (!buttonPressed && isTalking) {
    isTalking = false;
    enterListenMode();
  }

  // ---- talking: sample the mic and send 32-byte packets ----
  if (isTalking) {
    if ((long)(micros() - nextSampleTimeUs) >= 0) {
      nextSampleTimeUs += SAMPLE_PERIOD_US;
      outgoingPacket[outgoingPacketLength++] = readMicSample();
      if (outgoingPacketLength == PACKET_SIZE) {
        radio.writeFast(outgoingPacket, PACKET_SIZE);
        outgoingPacketLength = 0;
      }
    }
    return;
  }

  // ---- listening: buffer what arrives and play it ----
  while (radio.available()) {
    byte freeSpace = 255 - (byte)(playbackWriteIndex - playbackReadIndex);
    if (freeSpace >= PACKET_SIZE) {
      byte incomingPacket[PACKET_SIZE];
      radio.read(incomingPacket, PACKET_SIZE);
      for (byte i = 0; i < PACKET_SIZE; i++) {
        playbackBuffer[playbackWriteIndex] = incomingPacket[i];
        playbackWriteIndex++;
      }
    } else {
      break;                            // buffer full, read it on the next pass
    }
    lastPacketReceivedMs = millis();
  }

  byte bufferedSamples = (byte)(playbackWriteIndex - playbackReadIndex);
  if (!isPlaying && bufferedSamples >= PLAYBACK_START_THRESHOLD) {
    startPlayback();
  }
  if (isPlaying && bufferedSamples == 0 && millis() - lastPacketReceivedMs > RECEIVE_TIMEOUT_MS) {
    stopPlayback();
  }
}
