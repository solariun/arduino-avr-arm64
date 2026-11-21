// Exercises the parts of the toolchain Arduino relies on: C++ (templates,
// lambdas, virtuals, new/delete), LTO, float math, PROGMEM, ISRs, and the
// libraries bundled with the arduino:avr core.
#include <EEPROM.h>
#include <SPI.h>
#include <SoftwareSerial.h>
#include <Wire.h>
#include <avr/pgmspace.h>

SoftwareSerial soft(10, 11);
const char banner[] PROGMEM = "arduino-avr-arm64 feature test";
volatile uint16_t ticks;

ISR(TIMER2_COMPA_vect) { ticks++; }

template <typename T> T clampv(T v, T lo, T hi) { return v < lo ? lo : v > hi ? hi : v; }

struct Shape { virtual float area() const = 0; virtual ~Shape() {} };
struct Circle : Shape { float r; explicit Circle(float r) : r(r) {} float area() const override { return 3.14159f * r * r; } };

void setup() {
  Serial.begin(115200);
  soft.begin(9600);
  Wire.begin();
  SPI.begin();
  TCCR2A = _BV(WGM21); TCCR2B = _BV(CS22); OCR2A = 249; TIMSK2 = _BV(OCIE2A);

  Serial.println(reinterpret_cast<const __FlashStringHelper *>(banner));
  Shape *s = new Circle(2.5f);
  Serial.print(F("area=")); Serial.println(s->area(), 3);
  delete s;
  auto sq = [](long x) { return x * x; };
  Serial.print(F("sq=")); Serial.println(sq(clampv<long>(12345, 0, 1000)));
  Serial.print(F("sin=")); Serial.println(sin(1.0), 5);
  String msg = String("eeprom[0]=") + EEPROM.read(0);
  Serial.println(msg);
}

void loop() {
  Serial.print(F("ticks=")); Serial.println(ticks);
  delay(1000);
}
