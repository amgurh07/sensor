/*
 * CurrentCost Arduino Ethershield Pachube
 * Parses CurrentCost XML data and uploads to Pachube using Ethershield from Nuelectronics.
 * Copyright (C) 2009 Gavin Leake (gleake@gmail.com)
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */


//#define DEBUG

#ifdef DEBUG
#define DEBUG_PRINT(x) Serial.print(x)
#define DEBUG_PRINTLN(x) Serial.println(x)
#else
#define DEBUG_PRINT(x)
#define DEBUG_PRINTLN(x)
#endif

#include "etherShield.h"
#include <SoftwareSerial.h>
#include <string.h> // for strlen();

// Define the pins used for the software serial port.  Note that we won't
// actually be transmitting anything over the transmit pin.
#define rxPin 8
#define txPin 9

// LED onboard
#define ledPin 13

// Set up the serial port
SoftwareSerial softSerial = SoftwareSerial(rxPin, txPin);

// mac and ip have to be unique in your local area network.
static uint8_t my_mac[6] = {0x73,0x68,0x69,0x65,0x6c,0x64};
static uint8_t my_ip[4] = {10,0,0,2};
static uint16_t my_port = 6407; // should this be uint16? probably not

// destination server settings
static uint8_t dest_mac[6];
static uint8_t router_ip[4] = {10,0,0,1}; // router ip
static uint8_t dest_ip[4] = {209,40,205,190}; // www.pachube.com
static uint8_t dest_port = 80;

char pachube_feed_id[] = "999";
char pachube_feed_type[] = "csv";

enum CLIENT_STATE {
	IDLE, ARP_SENT, ARP_REPLY, SYN_SENT, SYN_REPLY, SYNACK_SENT, ESTABLISHED, FIN, FINACK
};

static CLIENT_STATE client_state;

static uint8_t client_data_ready = 0;

int syn_ack_timeout = 0;

int pass_counter = 0;

int port_counter = 0;

#define BUFFER_SIZE 500
static uint8_t esbuffer[BUFFER_SIZE+1];

static uint16_t plen;

EtherShield es=EtherShield();

#define pass_max 320
#define syn_ack_max 99

//char startMsg[] = "<msg>";
//char endMsg[] = "</msg>";
char startPwr[] = "<ch1><watts>";
char startTmpr[] = "<tmpr>";
char endChar = '<';

char readChar = 0xFF;

int sizePwr = sizeof(startPwr)-1;
int sizeTmpr = sizeof(startTmpr)-1;

int statePwr = sizePwr;
int stateTmpr = sizeTmpr;

int newstate = 0;

long PwrNum = 0;
unsigned long PwrCount = 0;
long PwrAvg = 0;
double TmprDouble = 0;
long TmprNum = 0;
unsigned long TmprCount = 0;
long TmprAvg = 0;
unsigned int PwrSize = 0;
unsigned int TmprSize = 0;
unsigned int DataSize = 0;

char Pwr[16] = "";
char Tmpr[16] = "";
char TmprBuffer[16] = "";
char PwrBuffer[64] = "";
char DataSizeBuffer[8] = "";

//int state = 0;
//int pos = 0;
//int stateMsg = 0;
//int posMsg = 0;

// cannot use watchdog, aruino bootloader takes too long on reset
//#include <avr/io.h> // watchdog req?
//#include <avr/wdt.h> // watchdog stuff

unsigned long currentMillis = 0;
unsigned long previousMillis = 0;
long intervalMillis = 60000;

void setup(void) {
  // Define pin modes for tx and rx pins
  pinMode(rxPin, INPUT);
  pinMode(txPin, OUTPUT);
  
  // Set the data rate for the SoftwareSerial port
  softSerial.begin(9650);

  // Set the data rate for the hardware serial port
  Serial.begin(19200);
  
  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);
  
  init_ethershield();
  
  //randomSeed(analogRead(0));
  
  //wdt_enable(WDTO_8S);
  
}

void loop(void) {
  
  readChar = softSerial.read();
  
  if (readChar > 31) {
    //stateTmpr = parseData2(stateTmpr, sizeTmpr, startTmpr, readChar);
    stateTmpr = parseDataTmpr(stateTmpr, readChar);
    if (stateTmpr < 0) {
       //Serial.print(readChar);
       Tmpr[abs(stateTmpr)-1] = readChar;
    }
    //statePwr = parseData2(statePwr, sizePwr, startPwr, readChar);
    statePwr = parseDataPwr(statePwr, readChar);
    if (statePwr < 0) {
       //Serial.print(readChar);
       Pwr[abs(statePwr)-1] = readChar;
    }
  } else if (readChar == 13) {
    
    digitalWrite(ledPin, HIGH);
    
    PwrNum = atol(Pwr);
    if ((PwrNum > 0) && (PwrNum < 100000)) {
      PwrAvg = ((PwrAvg*PwrCount)+(PwrNum*10))/(PwrCount+1);
      PwrCount++; // should this be millis?
    }
    TmprDouble = strtod(Tmpr,NULL);
    TmprNum = long(TmprDouble*10);
    if ((TmprNum < 100*10) && (TmprNum > 10)) {
      TmprAvg = ((TmprAvg*TmprCount)+(TmprNum*10))/(TmprCount+1);
      TmprCount++;
    }

    Serial.flush();
      DEBUG_PRINT("Pwr: ");
      DEBUG_PRINT(PwrNum);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(PwrCount);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(PwrAvg);
      DEBUG_PRINT(" Tmpr: ");
      DEBUG_PRINT(TmprNum);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(TmprCount);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(TmprAvg);
      //DEBUG_PRINT(" ");
      //DEBUG_PRINT(availableMemory());
      //DEBUG_PRINT(" ");
      //DEBUG_PRINT(millis());
      DEBUG_PRINTLN(".");
    Serial.flush();
      
    // not necessary using, overwrite onset
    //for (int i=0; i<sizeof(Pwr); i++) Pwr[i] = '\0';
    //for (int i=0; i<sizeof(Tmpr); i++) Tmpr[i] = '\0';    
    // if reseting required use this instead
    memset(Pwr,255,sizeof(Pwr));
    memset(Tmpr,255,sizeof(Tmpr));
    
    digitalWrite(ledPin, LOW);
    
  }
  
  //wdt_reset();
  
  currentMillis = millis();
  if ((currentMillis - previousMillis > intervalMillis) && (PwrCount > 0)) {
    previousMillis = currentMillis; // remember the last time
    
    digitalWrite(ledPin, HIGH);
    
    PwrAvg = PwrAvg/10;
    ltoa(PwrAvg, PwrBuffer, 10);
    PwrSize = strlen(PwrBuffer);    
    PwrBuffer[PwrSize] = ',';
    TmprAvg = TmprAvg/10;
    ltoa(TmprAvg, TmprBuffer, 10);
    TmprSize = strlen(TmprBuffer);    
    TmprBuffer[TmprSize] = TmprBuffer[TmprSize-1];
    TmprBuffer[TmprSize-1] = '.';
    DataSize = PwrSize+TmprSize+2;
    itoa(DataSize, DataSizeBuffer, 10);
    
    Serial.flush();
      DEBUG_PRINT("AvgPwr: ");
      DEBUG_PRINT(PwrAvg);
      DEBUG_PRINT("=");
      DEBUG_PRINT(PwrSize);
      DEBUG_PRINT(" AvgTmpr: ");
      DEBUG_PRINT(TmprBuffer);
      DEBUG_PRINT("=");
      DEBUG_PRINT(TmprSize);
      DEBUG_PRINT(" Buffer: ");
      DEBUG_PRINT(PwrBuffer);
      DEBUG_PRINT(TmprBuffer);
      DEBUG_PRINT("=");
      DEBUG_PRINT(DataSize);
      DEBUG_PRINTLN(".");
    Serial.flush();
      
    //wdt_reset();
    
    syn_ack_timeout = 0;
    pass_counter = 0;
    client_data_ready = 1;
    my_port = 6407+port_counter;
    DEBUG_PRINTLN("Sending Data...");
    while ((client_data_ready!=0) && (pass_counter < pass_max)) {
      client_process();
      pass_counter++;
      DEBUG_PRINT(client_state);
      DEBUG_PRINT(" ");
      if (esbuffer[ETH_TYPE_L_P] == ETHTYPE_ARP_L_V) DEBUG_PRINT("ARP");
      else if (esbuffer[IP_PROTO_P] == IP_PROTO_TCP_V) DEBUG_PRINT("TCP");
      else if (esbuffer[IP_PROTO_P] == IP_PROTO_UDP_V) DEBUG_PRINT("UDP");
      else if (esbuffer[IP_PROTO_P] == IP_PROTO_ICMP_V) DEBUG_PRINT("ICMP");
      else DEBUG_PRINT("UNKNOWN");
      DEBUG_PRINT(" ");
      DEBUG_PRINT(plen);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(syn_ack_timeout);
      DEBUG_PRINT(" ");
      DEBUG_PRINT(pass_counter);
      DEBUG_PRINT(" ");
      DEBUG_PRINTLN(my_port);
      
      /*
      if (esbuffer[IP_PROTO_P]==IP_PROTO_TCP_V) {
        int dat_p=es.ES_get_tcp_data_pointer();
        int dat_l=es.ES_tcp_get_dlength(esbuffer);
        
        Serial.print(dat_p,DEC);
        Serial.print(" ");
        Serial.print(dat_l,DEC);
        Serial.print(" ");
        Serial.print(esbuffer[TCP_DATA_P],DEC);
        Serial.print(" ");
        Serial.print(esbuffer[TCP_HEADER_LEN_P],DEC);
        Serial.print(" ");
        Serial.print(esbuffer[TCP_WINDOWSIZE_H_P],DEC);
        Serial.print(" ");
        Serial.println(esbuffer[TCP_WINDOWSIZE_L_P],DEC);

        Serial.println("");
        Serial.println("");        
        for(int i=0; i < (esbuffer[TCP_WINDOWSIZE_H_P]*esbuffer[TCP_WINDOWSIZE_L_P]); i++) {
          Serial.print(esbuffer[i]);
        }
        Serial.println("");
        Serial.println("");
        Serial.println("");

      }
      */
      
    }
    
    port_counter++;
    if (port_counter > 9) port_counter = 0;
    
    PwrCount = 0;
    TmprCount = 0;
    client_data_ready = 0;
    client_state = IDLE;
    
    DEBUG_PRINTLN("...Complete.");
    
    // not necessary because itoa overwrites full buffer
    //for (int i=0; i<sizeof(TmprBuffer); i++) TmprBuffer[i] = '\0';
    //for (int i=0; i<sizeof(PwrBuffer); i++) PwrBuffer[i] = '\0';
    memset(PwrBuffer,0,sizeof(PwrBuffer));
    memset(TmprBuffer,0,sizeof(TmprBuffer));
    
    digitalWrite(ledPin, LOW);
    
  }
  
  //wdt_reset();
  
}

uint16_t gen_client_request(uint8_t *esbuffer ) {
	
	uint16_t reqlen;
	
	reqlen = es.ES_fill_tcp_data_p(esbuffer, 0, PSTR ("PUT /api/"));
	//reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR (PACHUBE_FEED_ID));
	for(byte i=0; pachube_feed_id[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=pachube_feed_id[i];
		reqlen++;
	}
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR ("."));
	for(byte i=0; pachube_feed_type[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=pachube_feed_type[i];
		reqlen++;
	}
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR (" HTTP/1.1\nHost: www.pachube.com\nX-PachubeApiKey: "));
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR ("API_KEY_HERE"));
	/*
	for(byte i=0; pachube_api_key[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=pachube_api_key[i];
		reqlen++;
	}
	*/
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR ("\nContent-Type: text/csv\nContent-Length: "));
	//reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR (DataSize));
	for(byte i=0; DataSizeBuffer[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=DataSizeBuffer[i];
		reqlen++;
	}
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR ("\nConnection: close\n\n"));
	//reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR (DataBuffer));
	for(byte i=0; PwrBuffer[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=PwrBuffer[i];
		reqlen++;
	}
	for(byte i=0; TmprBuffer[i]!='\0'; i++) {
		esbuffer[TCP_DATA_P+reqlen]=TmprBuffer[i];
		reqlen++;
	}
	reqlen = es.ES_fill_tcp_data_p(esbuffer, reqlen, PSTR ("\n"));
	
	return reqlen;
	
}

int parseData2(int oldstate, int size, char *start, char chr) {
  newstate = oldstate;
  if (newstate > 0) {
    if (chr == start[size-newstate]) {
      newstate--;
    } else {
      newstate = size;
    }
  } else if (newstate <= 0) {
    newstate--;
    if (chr == endChar) {
      newstate = size;
    }
  }
  return newstate;
}

int parseDataTmpr(int oldstate, char chr) {
  newstate = oldstate;
  if (newstate > 0) {
    if (chr == startTmpr[sizeTmpr-newstate]) {
      newstate--;
    } else {
      newstate = sizeTmpr;
    }
  } else if (newstate <= 0) {
    newstate--;
    if (chr == endChar) {
      newstate = sizeTmpr;
    }
  }
  return newstate;
}

int parseDataPwr(int oldstate, char chr) {
  newstate = oldstate;
  if (newstate > 0) {
    if (chr == startPwr[sizePwr-newstate]) {
      newstate--;
    } else {
      newstate = sizePwr;
    }
  } else if (newstate <= 0) {
    newstate--;
    if (chr == endChar) {
      newstate = sizePwr;
    }
  }
  return newstate;
}

int availableMemory() {
  int size = 1024;
  byte *availableMemoryBuffer;

  while ((availableMemoryBuffer = (byte *) malloc(--size)) == NULL)
    ;

  free(availableMemoryBuffer);

  return size;
}

//*****************************************************************************
//
// Standard NUElectronics EtherShield Functions, No Changes Necessary
//
//*****************************************************************************

void init_ethershield() {

	//initialize enc28j60
	es.ES_enc28j60Init(my_mac);
	es.ES_enc28j60clkout(2); // change clkout from 6.25MHz to 12.5MHz
	delay(10);
	
	/* Magjack leds configuration, see enc28j60 datasheet, page 11 */
	// LEDA=greed LEDB=yellow
		// 0x880 is PHLCON LEDB=on, LEDA=on
		// enc28j60PhyWrite(PHLCON,0b0000 1000 1000 00 00);
		es.ES_enc28j60PhyWrite(PHLCON,0x880);
		delay(500);
		// 0x990 is PHLCON LEDB=off, LEDA=off
		// enc28j60PhyWrite(PHLCON,0b0000 1001 1001 00 00);
		es.ES_enc28j60PhyWrite(PHLCON,0x990);
		delay(500);
		// 0x880 is PHLCON LEDB=on, LEDA=on
		// enc28j60PhyWrite(PHLCON,0b0000 1000 1000 00 00);
		es.ES_enc28j60PhyWrite(PHLCON,0x880);
		delay(500);
		// 0x990 is PHLCON LEDB=off, LEDA=off
		// enc28j60PhyWrite(PHLCON,0b0000 1001 1001 00 00);
		es.ES_enc28j60PhyWrite(PHLCON,0x990);
		delay(500);
		// 0x476 is PHLCON LEDA=links status, LEDB=receive/transmit
		// enc28j60PhyWrite(PHLCON,0b0000 0100 0111 01 10);
		es.ES_enc28j60PhyWrite(PHLCON,0x476);
		delay(100);
	
	//init the ethernet/ip layer:
	es.ES_init_ip_arp_udp_tcp(my_mac,my_ip,80);
	
	// intialize varible;
	syn_ack_timeout = 0;
	client_data_ready = 0;
	client_state = IDLE;
	
}

void client_process(void){

	uint8_t i;
	
	if(client_data_ready==0)return; // nothing to send
	
	if(client_state==IDLE){ // initialize ARP
	
		es.ES_make_arp_request(esbuffer,router_ip);
		
		client_state=ARP_SENT;
		return;
		
	}
	
	if(client_state==ARP_SENT){
	
		plen=es.ES_enc28j60PacketReceive(BUFFER_SIZE,esbuffer);
		
		// destination ip address was found on network
		if(plen!=0){
			if(es.ES_arp_packet_is_myreply_arp(esbuffer)){
				// save dest mac
				for(i=0;i<6;i++){
					dest_mac[i]=esbuffer[ETH_SRC_MAC+i];
				}
				client_state=ARP_REPLY;
				syn_ack_timeout=0;
				return;
			}
		}
		
		delay(10);
		syn_ack_timeout++;
		
		if(syn_ack_timeout>syn_ack_max){ //timeout, server ip not found
			client_state=IDLE;
			client_data_ready=0;
			syn_ack_timeout=0;
			return;
		}
		
	}
	
	// send SYN packet to initial connection
	if(client_state==ARP_REPLY){
	
		es.ES_tcp_client_send_packet(
			esbuffer,
			dest_port,
			my_port,
			TCP_FLAG_SYN_V, // flag
			1, // (bool)maximum segment size
			1, // (bool)clear sequence ack number
			0, // 0=use old seq, seqack : 1=new seq,seqack no data : new seq,seqack with data
			0, // tcp data length
			dest_mac,
			dest_ip
		);
		
		client_state=SYN_SENT;
		return;
		
	}
	
	// get new packet
	if(client_state==SYN_SENT){
	
		plen=es.ES_enc28j60PacketReceive(BUFFER_SIZE,esbuffer);
		
		// new packet found
		if(plen!=0){
			// accept ip packet only
			if(es.ES_eth_type_is_ip_and_my_ip(esbuffer,plen)){
				// check SYNACK flag, after AVR send SYN server response by send SYNACK to AVR
				if(esbuffer[TCP_FLAGS_P]==(TCP_FLAG_SYN_V|TCP_FLAG_ACK_V)){
					client_state=SYN_REPLY;
					syn_ack_timeout=0;
					return;
				}
			}
		}
		
		delay(10);
		syn_ack_timeout++;
		
		if(syn_ack_timeout>syn_ack_max){ //timeout, no syn recieved
			client_state=IDLE;
			client_data_ready=0;
			syn_ack_timeout=0;
			return;
		}
		
	}
	
	if(client_state==SYN_REPLY){
	
		// send ACK to answer SYNACK
		es.ES_tcp_client_send_packet(
			esbuffer,
			dest_port,
			my_port,
			TCP_FLAG_ACK_V, // flag
			0, // (bool)maximum segment size
			0, // (bool)clear sequence ack number
			1, // 0=use old seq, seqack : 1=new seq,seqack no data : new seq,seqack with data
			0, // tcp data length
			dest_mac,
			dest_ip
		);
		
		client_state=SYNACK_SENT;
		return;
		
	}
	
	if(client_state==SYNACK_SENT){
	
		// setup http request to server
		plen=gen_client_request(esbuffer);
		
		// send http request packet
		// send packet with PSHACK
		es.ES_tcp_client_send_packet(
			esbuffer,
			dest_port, // destination port
			my_port, // source port
			TCP_FLAG_ACK_V|TCP_FLAG_PUSH_V, // flag
			0, // (bool)maximum segment size
			0, // (bool)clear sequence ack number
			0, // 0=use old seq, seqack : 1=new seq,seqack no data : >1 new seq,seqack with data
			plen, // tcp data length
			dest_mac,
			dest_ip
		);
		
		client_state=ESTABLISHED;
		return;
		
	}
	
	if(client_state==ESTABLISHED){
	
		plen=es.ES_enc28j60PacketReceive(BUFFER_SIZE,esbuffer);
		
		if(plen!=0){
			/*
			if (esbuffer[IP_PROTO_P]==IP_PROTO_TCP_V) {
			
				for(i=0;i<15;i++){
					Serial.print(esbuffer[TCP_DATA_P+i]);
				} // at 54 for 15
				Serial.println(".");
				
				return;
				
			}
			*/
			
			// accept ip packet only
			if(es.ES_eth_type_is_ip_and_my_ip(esbuffer,plen)){
				// after AVR send http request to server, server response by send data with PSHACK to AVR
				if(esbuffer[TCP_FLAGS_P]==(TCP_FLAG_ACK_V|TCP_FLAG_PUSH_V)){
				
					plen=es.ES_tcp_get_dlength((uint8_t*)&esbuffer);
					
					// send ACK to answer PSHACK from server
					es.ES_tcp_client_send_packet(
						esbuffer,
						dest_port, // destination port
						my_port, // source port
						TCP_FLAG_ACK_V, // flag
						0, // (bool)maximum segment size
						0, // (bool)clear sequence ack number
						plen, // 0=use old seq, seqack : 1=new seq,seqack no data : >1 new seq,seqack with data
						0, // tcp data length
						dest_mac,
						dest_ip
					);
					
					client_state=FIN;
					syn_ack_timeout=0;
					return;
					
				}
			}
			
		}
		
		delay(10);
		syn_ack_timeout++;
		
		if(syn_ack_timeout>syn_ack_max){ //fin timeout
			client_state=IDLE;
			client_data_ready=0;
			syn_ack_timeout=0;
			return;
		}
		
	}
	
	if(client_state==FIN){
	
		// send FINACK to disconnect from web server
		es.ES_tcp_client_send_packet(
			esbuffer,
			dest_port, // destination port
			my_port, // source port
			TCP_FLAG_FIN_V|TCP_FLAG_ACK_V, // flag
			0, // (bool)maximum segment size
			0, // (bool)clear sequence ack number
			0, // 0=use old seq, seqack : 1=new seq,seqack no data : >1 new seq,seqack with data
			0,
			dest_mac,
			dest_ip
		);
		
		client_state=FINACK;
		return;
		
	}
	
	if(client_state==FINACK){
	
		plen=es.ES_enc28j60PacketReceive(BUFFER_SIZE,esbuffer);
		
		// answer FINACK from web server with ACK to web server
		if(esbuffer[TCP_FLAGS_P]==(TCP_FLAG_ACK_V|TCP_FLAG_FIN_V)){
			// send ACK with seqack = 1
			es.ES_tcp_client_send_packet(
				esbuffer,
				dest_port, // destination port
				my_port, // source port
				TCP_FLAG_ACK_V, // flag
				0, // (bool)maximum segment size
				0, // (bool)clear sequence ack number
				1, // 0=use old seq, seqack : 1=new seq,seqack no data : >1 new seq,seqack with data
				0,
				dest_mac,
				dest_ip
			);
			
			client_state=IDLE; // return to IDLE state
			client_data_ready=0; // client data sent
			
		}
		
	}
	
}