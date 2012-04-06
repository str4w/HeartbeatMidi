// Measure timing of heartbeat pulses received
// output times, in microseconds, on serial port
// Uses interrupt service routine to quickly stock 
// the time in a queue.
//
// (c) 2012 strawdog3@gmail.com
//
// License:  An ye harm none, do as ye will
//
#define QUEUESIZE 32

unsigned long times[QUEUESIZE];
int head=0;
int tail=0;
boolean full=false;

void isr() {
  // put the current time in the queue
  times[head]=micros();
  head=head+1;
  if(head==QUEUESIZE) head=0;
  if(head==tail) full=true;
}

void setup() {
  Serial.begin(115200);
  attachInterrupt(0,isr,RISING);
}


void loop() {
  if(full) {
    // we screwed if this happens.
    Serial.println("#QUEUE FULL, DAMMIT");
    full=false;
  }  
  if(tail != head) {
    Serial.println(times[tail]);
    tail=(tail+1);
    if(tail==QUEUESIZE) tail=0;
  }
}
