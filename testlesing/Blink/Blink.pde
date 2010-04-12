int potentiometerPin = 0;
int ledPin = 9;
int val = 0;

void setup(){
Serial.begin(9600);
}

void loop(){
val = analogRead(potentiometerPin);
Serial.println(val);
delay(1000);

}
