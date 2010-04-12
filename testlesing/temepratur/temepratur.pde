#include <math.h>

int pin12=12;
int pin13=13;
int teller=0;

double Thermister(double RawADC) {
   double Temp;
   Temp = log(((10240000/RawADC) - 10000));
   Temp = 1 / (0.001129148 + (0.000234125 * Temp) + (0.0000000876741 * Temp * Temp * Temp));
   Temp = Temp - 273.15;            // Convert Kelvin to Celcius
  
   return Temp;
}

void setup() {
      pinMode(pin12,OUTPUT);
      pinMode(pin13,OUTPUT);    
     Serial.begin(19200);
}

void loop() {
  
  digitalWrite(pin12,HIGH);
  digitalWrite(pin13,LOW);
  Serial.println(int(Thermister(analogRead(0))));  // display Fahrenheit
  Serial.println("grader");
  delay(2000);
  
  digitalWrite(pin12,LOW);
  digitalWrite(pin13,HIGH);
  Serial.println(int(Thermister(analogRead(0))));  // display Fahrenheit
  Serial.println("grader");
  delay(2000);
  
 
  
   
   
}

