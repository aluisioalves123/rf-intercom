// Microphone test (electret + BC547 preamp) for the Serial Plotter
// Open Tools > Serial Plotter at 115200 baud.
// Every 20 ms it plots the lowest, highest and average reading on A0.
//   Silence: the three lines stay together near the middle.
//   Talking close to the mic: "min" and "max" spread apart.

const byte MIC_PIN = A0;
const unsigned long WINDOW_MS = 20;

void setup() {
  Serial.begin(115200);
#if defined(__LGT8F__)
  analogReadResolution(10);     // LGT: same 0 to 1023 scale as the Nano
#endif
}

void loop() {
  int lowestReading = 1023;
  int highestReading = 0;
  long readingSum = 0;
  int readingCount = 0;

  unsigned long windowStartMs = millis();
  while (millis() - windowStartMs < WINDOW_MS) {
    int reading = analogRead(MIC_PIN);
    if (reading < lowestReading) lowestReading = reading;
    if (reading > highestReading) highestReading = reading;
    readingSum += reading;
    readingCount++;
  }

  Serial.print(F("min:"));
  Serial.print(lowestReading);
  Serial.print(F(" max:"));
  Serial.print(highestReading);
  Serial.print(F(" average:"));
  Serial.print(readingSum / readingCount);
  Serial.print(F(" floor:0 ceiling:1023"));   // pins the plot scale
  Serial.println();
}
