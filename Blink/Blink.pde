
int pin3= 3;
int pin5= 5;
int teller;

void setup() {
  pinMode(pin3,OUTPUT);
  pinMode(pin5,OUTPUT);
  Serial.begin(9600);
}

void loop() {
  for(teller=0; teller<255; teller++){
    analogWrite(pin3,teller);
    analogWrite(pin5,LOW);
    delay(10);
  }
  
  for(teller=0; teller<255; teller++){
    analogWrite(pin5,teller);
    analogWrite(pin3,LOW);
    delay(10);
  }
}
