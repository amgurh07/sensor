#include <Ethernet.h>

byte mac[] = { 0x00, 0x1F, 0x16, 0x58, 0xEB, 0xA3 };
byte ip[] = { 128, 39, 61, 228 };
byte server[] = { 64, 233, 187, 99 }; // Google
byte gateway[ ] = { 128, 39, 61, 1 };

byte subnet[ ] = { 255, 255, 252, 0 };

Client client(server, 80);

void setup()
{
  Ethernet.begin(mac, ip);
  Serial.begin(9600);
  
  delay(1000);
  
  Serial.println("connecting...");
  
  if (client.connect()) {
    Serial.println("connected");
    client.println("GET /search?q=arduino HTTP/1.0");
    client.println();
  } else {
    Serial.println("connection failed");
  }
}

void loop()
{
  if (client.available()) {
    char c = client.read();
    Serial.print(c);
  }
  
  if (!client.connected()) {
    Serial.println();
    Serial.println("disconnecting.");
    client.stop();
    for(;;)
      ;
  }
}
