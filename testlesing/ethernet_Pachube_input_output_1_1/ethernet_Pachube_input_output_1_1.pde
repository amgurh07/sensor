/* ==============================
 * This code, which assumes you're using the official Arduino Ethernet shield,
 * updates a Pachube feed with your analog-in values and grabs values from a Pachube
 * feed - basically it enables you to have both "local" and "remote" sensors.
 * 
 * Tested with Arduino 14
 *
 * Pachube is www.pachube.com - connect, tag and share real time sensor data
 * code by usman (www.haque.co.uk), may 2009
 * copy, distribute, whatever, as you like.
 *
 * v1.1 - added User-Agent & fixed HTTP parser for new Pachube headers
 * and check millis() for when it wraps around
 *
 * ===============================*/
#include <Ethernet.h>
#include <string.h>
#include <EthernetDHCP.h>
#undef int() // needed by arduino 0011 to allow use of stdio
#include <stdio.h> // for function sprintf

#define SHARE_FEED_ID              6273     // this is your Pachube feed ID that you want to share to
#define REMOTE_FEED_ID             256      // this is the ID of the remote Pachube feed that you want to connect to
#define REMOTE_FEED_DATASTREAMS    4        // make sure that remoteSensor array is big enough to fit all the remote data streams
#define UPDATE_INTERVAL            10000    // if the connection is good wait 10 seconds before updating again - should not be less than 5
#define RESET_INTERVAL             10000    // if connection fails/resets wait 10 seconds before trying again - should not be less than 5
#include <math.h>
#define PACHUBE_API_KEY            "dfcf842a7ceb31323adcd735e2b0af19b19dc972cdf53fe51eeea52f622394b1" // fill in your API key 

byte mac[] ={ 0x00, 0x1F, 0x16, 0x58, 0xEB, 0xA2 }; // make sure this is unique on your network
byte ip[] = { 192, 168, 0, 144   };                  // no DHCP so we set our own IP address
byte remoteServer[] = { 209,40,205,190 };            // pachube.com

float remoteSensor[REMOTE_FEED_DATASTREAMS];        // we know that feed 256 has floats - this might need changing for feeds without floats
const char* ip_to_str(const uint8_t*);              //DHCP 



void setup()
{
   Serial.begin(9600);
  
  //DHCP----------------------------------------------------------------------------
  Serial.println("Attempting to obtain a DHCP lease...");
  
  // Initiate a DHCP session. The argument is the MAC (hardware) address that
  // you want your Ethernet shield to use. This call will block until a DHCP
  // lease has been obtained. The request will be periodically resent until
  // a lease is granted, but if there is no DHCP server on the network or if
  // the server fails to respond, this call will block forever.
  // Thus, you can alternatively use polling mode to check whether a DHCP
  // lease has been obtained, so that you can react if the server does not
  // respond (see the PollingDHCP example).
  EthernetDHCP.begin(mac);

  // Since we're here, it means that we now have a DHCP lease, so we print
  // out some information.
  const byte* ipAddr = EthernetDHCP.ipAddress();
  const byte* gatewayAddr = EthernetDHCP.gatewayIpAddress();
  const byte* dnsAddr = EthernetDHCP.dnsIpAddress();
  
  Serial.println("A DHCP lease has been obtained.");

  Serial.print("My IP address is ");
  Serial.println(ip_to_str(ipAddr));
  
  Serial.print("Gateway IP address is ");
  Serial.println(ip_to_str(gatewayAddr));
  
  Serial.print("DNS IP address is ");
  Serial.println(ip_to_str(dnsAddr));
  //DHCP---------------------------------------------

  pinMode(3, OUTPUT);
  pinMode(5, OUTPUT);
  pinMode(6, OUTPUT);
 
}

void loop()
{

  // call 'pachube_in_out' at the beginning of the loop, handles timing, requesting
  // and reading. use serial monitor to view debug messages

  pachube_in_out();

  // then put your code here, you can access remote sensor values
  // by using the remoteSensor float array, e.g.: 

   Serial.println(int(Thermister(analogRead(0))));  // display Fahrenheit
    Serial.println("grader");
    delay(2000);

  // you can have code that is time sensitive (e.g. using 'delay'), but 
  // be aware that it will be affected by a short pause during connecting
  // to and reading from ethernet (approx. 0.5 to 1 sec).
  // e.g. this code should carry on flashing regularly, with brief pauses
  // every few seconds during Pachube update.

  digitalWrite(6, HIGH);
  delay(100);
  digitalWrite(6, LOW);
  delay(100);
  
  EthernetDHCP.maintain();

}

// Just a utility function to nicely format an IP address.
const char* ip_to_str(const uint8_t* ipAddr)
{
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
}
