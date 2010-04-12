char pachube_data[70];

boolean found_status_200 = false;
boolean found_session_id = false;
boolean found_CSV = false;
char *found;
unsigned int successes = 0;
unsigned int failures = 0;
boolean ready_to_update = true;
boolean reading_pachube = false;

boolean request_pause = false;
boolean found_content = false;

unsigned long last_connect;

int content_length;

double Thermister(double RawADC) {
   double Temp;
   Temp = log(((10240000/RawADC) - 10000));
   Temp = 1 / (0.001129148 + (0.000234125 * Temp) + (0.0000000876741 * Temp * Temp * Temp));
   Temp = Temp - 273.15;            // Convert Kelvin to Celcius
  
   return Temp;
}


double Thermistor(int RawADC) {
 // Inputs ADC Value from Thermistor and outputs Temperature in Celsius
 //  requires: include <math.h>
 // Utilizes the Steinhart-Hart Thermistor Equation:
 //    Temperature in Kelvin = 1 / {A + B[ln(R)] + C[ln(R)]^3}
 //    where A = 0.001129148, B = 0.000234125 and C = 8.76741E-08
 long Resistance;  double Temp2;  // Dual-Purpose variable to save space.
 Resistance=((10240000/RawADC) - 10000);  // Assuming a 10k Thermistor.  Calculation is actually: Resistance = (1024/ADC)
 Temp2 = log(Resistance); // Saving the Log(resistance) so not to calculate it 4 times later. // "Temp" means "Temporary" on this line.
 Temp2 = 1 / (0.001129148 + (0.000234125 * Temp2) + (0.0000000876741 * Temp2 * Temp2 * Temp2));   // Now it means both "Temporary" and "Temperature"
 Temp2 = Temp2 - 273.15;  // Convert Kelvin to Celsius                                         // Now it only means "Temperature"


 // Uncomment this line for the function to return Fahrenheit instead.
 //Temp = (Temp * 9.0)/ 5.0 + 32.0; // Convert to Fahrenheit
 return Temp2;  // Return the Temperature
}


void pachube_in_out(){

  if (millis() < last_connect) last_connect = millis();

  if (request_pause){
    if ((millis() - last_connect) > interval){
      ready_to_update = true;
      reading_pachube = false;
      request_pause = false;
      found_status_200 = false;
      found_session_id = false;
      found_CSV = false;

      //Serial.print("Ready to connect: ");
      //Serial.println(millis());
    }
  }

  if (ready_to_update){
    Serial.println("Connecting...");
    if (localClient.connect()) {

      // here we assign comma-separated values to 'data', which will update Pachube datastreams
      // we use all the analog-in values, but could of course use anything else millis(), digital
      // inputs, etc. . i also like to keep track of successful and failed connection
      // attempts, sometimes useful for determining whether there are major problems.
      int Verdi= Thermister(analogRead(0));
      int Verdi2= Thermister(analogRead(0));
      Serial.print(Verdi);
      Serial.print(Verdi);
      sprintf(pachube_data,"%d,%d,%d,%d,%d,%d,%d,%d",Verdi,Verdi2,analogRead(2),analogRead(3),analogRead(4),analogRead(5), successes + 1, failures);
      content_length = strlen(pachube_data);

      Serial.println("GET request to retrieve");

      localClient.print("GET /api/");
      localClient.print(REMOTE_FEED_ID);
      localClient.print(".csv HTTP/1.1\nHost: pachube.com\nX-PachubeApiKey: ");
      localClient.print(PACHUBE_API_KEY);
      localClient.print("\nUser-Agent: Arduino (Pachube In Out v1.1)");
      localClient.println("\n");

      //Serial.println("finished GET now PUT, to update");

      localClient.print("PUT /api/");
      localClient.print(SHARE_FEED_ID);
      localClient.print(".csv HTTP/1.1\nHost: pachube.com\nX-PachubeApiKey: ");
      localClient.print(PACHUBE_API_KEY);

      localClient.print("\nUser-Agent: Arduino (Pachube In Out v1.1)");
      localClient.print("\nContent-Type: text/csv\nContent-Length: ");
      localClient.print(content_length);
      localClient.print("\nConnection: close\n\n");
      localClient.print(pachube_data);



      localClient.print("\n");

      ready_to_update = false;
      reading_pachube = true;
      request_pause = false;
      interval = UPDATE_INTERVAL;

      // Serial.print("finished PUT: ");
      // Serial.println(millis());

    } 
    else {
      Serial.print("connection failed!");
      Serial.print(++failures);
      found_status_200 = false;
      found_session_id = false;
      found_CSV = false;
      ready_to_update = false;
      reading_pachube = false;
      request_pause = true;
      last_connect = millis();
      interval = RESET_INTERVAL;
      setupEthernet();
    }
  }

  while (reading_pachube){
    while (localClient.available()) {
      checkForResponse();
    } 

    if (!localClient.connected()) {
      disconnect_pachube();
    }
  } 
}

void disconnect_pachube(){
  Serial.println("disconnecting.\n=====\n\n");
  localClient.stop();
  ready_to_update = false;
  reading_pachube = false;
  request_pause = true;
  last_connect = millis();
  found_content = false;
  resetEthernetShield();
}


void checkForResponse(){  
  char c = localClient.read();
  //Serial.print(c);
  buff[pointer] = c;
  if (pointer < 64) pointer++;
  if (c == '\n') {
    found = strstr(buff, "200 OK");
    if (found != 0){
      found_status_200 = true; 
      //Serial.println("Status 200");
    }
    buff[pointer]=0;
    found_content = true;
    clean_buffer();    
  }

  if ((found_session_id) && (!found_CSV)){
    found = strstr(buff, "HTTP/1.1");
    if (found != 0){
      char csvLine[strlen(buff)-9];
      strncpy (csvLine,buff,strlen(buff)-9);

      //Serial.println("This is the retrieved CSV:");     
      //Serial.println("---");     
      //Serial.println(csvLine);
      //Serial.println("---");   
      Serial.println("\n--- updated: ");
      Serial.println(pachube_data);
      Serial.println("\n--- retrieved: ");
      char delims[] = ",";
      char *result = NULL;
      char * ptr;
      result = strtok_r( buff, delims, &ptr );
      int counter = 0;
      while( result != NULL ) {
        remoteSensor[counter++] = atof(result); 
        result = strtok_r( NULL, delims, &ptr );
      }  
      for (int i = 0; i < REMOTE_FEED_DATASTREAMS; i++){
        Serial.print( (int)remoteSensor[i]); // because we can't print floats
        Serial.print("\t");
      }

      found_CSV = true;

      Serial.print("\nsuccessful updates=");
      Serial.println(++successes);

    }
  }

  if (found_status_200){
    found = strstr(buff, "_id=");
    if (found != 0){
      clean_buffer();
      found_session_id = true; 
    }
  }
}

