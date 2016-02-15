//*****************************************************************
// HeartBeat to Midi
// 
// Copyright Strawdog 2012
// www.foulab.org/projects/...etc
//

// if usemidi is not defined, will print on the serial, for debugging
#define USEMIDI

#define IND0 6
#define IND1 7
// Wire layout made it easier to source the LEDs from pin 5
#define DRIVER 5

#ifdef USEMIDI
  #define SERIALSPEED 31250
#else
  #define SERIALSPEED 9600
#endif



#define DELAYCOUNT 12
#define DELAYMAXINDEX 11 
// Every 5 bpm, from 45 to 200
#define MAXBPM 200
#define MINBPM  45
#define BPMSTEP  5
#define NBBPMLEVELS (MAXBPM-MINBPM)/BPMSTEP + 1

#define NOTE 0x1E

int state=0;

long lastNoteTime;
boolean soundOn=false;


volatile long theDelays[DELAYCOUNT];
volatile int counter=0;
volatile long lastTime=0;

long theWeights[DELAYCOUNT];
long currentDelay=1000000;
long lastBeatTime=0;
long nextBeatTime=1000000;
boolean freshData=false;

long precision=0;
long currentTime=0;
long beatCount=0;
long lowerBound=0;
long upperBound=1000000;
long allowableDelays[NBBPMLEVELS];
int currentBPM=0;
bool lastRejected=false;


// The interupt service request on the rising edge of the heartbeat
void isr() {
  long now=millis();
  long theDelay=now-lastTime;
  lastTime=now;
  // dont reject them all, or if the heart rate changes too rapidly, we will get stuck
  if(lastRejected || theDelay>lowerBound && theDelay < upperBound) {
     ++beatCount;
     lastRejected=false;
     theDelays[counter]=theDelay;
     counter=(counter==DELAYMAXINDEX) ? 0 : counter+1;
     digitalWrite(IND1,state);
     state=1-state;
     freshData=true;
  } 
  else {
    lastRejected=true;
  #ifndef USEMIDI
    Serial.println("Rejected ");
    Serial.print("now: ");
    Serial.print(now);
    Serial.print(" last: ");
    Serial.println(lastTime);
  #endif
  }
}

//  plays a MIDI note.  Doesn't check to see that
//  cmd is greater than 127, or that data values are  less than 127:
void noteOn(int cmd, int pitch, int velocity) {
  Serial.write(cmd);
  Serial.write(pitch);
  Serial.write(velocity);
}

void resetDelays() {
  lastTime=millis();
  for(int i=0;i<DELAYCOUNT;++i) {
    theDelays[i]=1000000;
  }
  beatCount=0;
  lowerBound=0;
  upperBound=1000000;
  freshData=true;
  lastRejected=false;
}

#ifdef USEMIDI
void emitBeat() {
  digitalWrite(IND0,LOW);
  noteOn(0x90, NOTE, 0x45);
  lastNoteTime=millis();
  soundOn=true;
}

void silenceBeat() {
  digitalWrite(IND0,HIGH);
  noteOn(0x90, NOTE, 0x00);
  soundOn=false; 
}
#else
void emitBeat() {
  digitalWrite(IND0,LOW);
  Serial.println("On");
  soundOn=true;
}

void silenceBeat() {
  digitalWrite(IND0,HIGH);
  Serial.println("Off");
  soundOn=false;
}
#endif

void computeDelay() {
        long delaySum=0;
        long denominator=0;
        int index=counter-1;
        int startindex=index;
        if(startindex==-1) startindex=DELAYMAXINDEX;
        for(int i=DELAYCOUNT;i>0;--i) {
          if(index==-1) index=DELAYMAXINDEX;
          delaySum+=theDelays[index];//*theWeights[i];
          denominator+=1;//theWeights[i];
          index--;
        }
        currentDelay= delaySum/denominator;
        
        if(beatCount>DELAYCOUNT) {
          lowerBound=currentDelay-currentDelay/5;
          upperBound=currentDelay+currentDelay/5;
          if(beatCount==DELAYCOUNT+1) {
            currentBPM=0;
            int currentDiff=abs(currentDelay-allowableDelays[0]);
            for(int index=1; index< NBBPMLEVELS;++index) {
              int thisDiff=abs(currentDelay-allowableDelays[index]);
              if(thisDiff<currentDiff) {
                currentDiff=thisDiff;
                currentBPM=index;
              }
            }
          } else {
            if(currentDelay>allowableDelays[currentBPM] && currentBPM>0) { 
              int currentDiff=currentDelay-allowableDelays[currentBPM];
              int diffBelow=abs(allowableDelays[currentBPM-1]-currentDelay);
              if(currentDiff-diffBelow > (allowableDelays[currentBPM-1]-allowableDelays[currentBPM])*4/5) {
                currentBPM=currentBPM-1;
              }
            } else if (currentDelay<allowableDelays[currentBPM] && currentBPM<(NBBPMLEVELS-1)) { 
              int currentDiff=allowableDelays[currentBPM]-currentDelay;
              int diffAbove=abs(allowableDelays[currentBPM+1]-currentDelay);
              if(currentDiff-diffAbove > (allowableDelays[currentBPM]-allowableDelays[currentBPM+1])*4/5) {
                currentBPM=currentBPM+1;
              }
            }
          }
        }
        nextBeatTime=lastBeatTime+allowableDelays[currentBPM];//currentDelay;
        #ifndef USEMIDI
           Serial.print(theDelays[startindex]);
           Serial.print(" ");
           Serial.print(currentDelay);
           Serial.print(" ");
           Serial.print(nextBeatTime);
           Serial.print(" ");
           Serial.print(currentBPM);
           Serial.print(" ");
           Serial.print(allowableDelays[currentBPM]);
           Serial.print(" ");
           Serial.println(precision);
        #endif
        freshData=false;
}

void setup() {
  resetDelays();
  for(int i=0;i<NBBPMLEVELS;++i) {
    allowableDelays[i]=60000/(MINBPM+i*BPMSTEP);
  }
  Serial.begin(SERIALSPEED);
  pinMode(2,INPUT);
  pinMode(DRIVER,OUTPUT);
  pinMode(IND0,OUTPUT);
  pinMode(IND1,OUTPUT);
  digitalWrite(DRIVER,HIGH);
  digitalWrite(IND0,HIGH);
  digitalWrite(IND1,LOW);
  for(int i=0;i<DELAYCOUNT;++i) {
    theWeights[i]=1;//i;//sqrt(i);
  }
  currentTime=millis();
  attachInterrupt(0,isr,RISING);
  #ifndef USEMIDI
    Serial.print("Initializing at ");
    Serial.println(currentTime);
  #endif
}

void loop() {
  long temp=millis();
  precision=temp-currentTime;
  currentTime=temp;
  if(currentTime>=nextBeatTime && beatCount>DELAYCOUNT) {
    lastBeatTime=currentTime;
    emitBeat();
    nextBeatTime=nextBeatTime+currentDelay;
    if(nextBeatTime<currentTime) {
      #ifndef USEMIDI
      Serial.println("Fell behind");
      #endif
      nextBeatTime=currentTime+currentDelay;
    }
  }
  if(soundOn && currentTime-lastBeatTime > 50) {
    silenceBeat();
  } 
  if(freshData) computeDelay();
  if(currentTime-lastTime > 4*currentDelay) {
    // If have missed two beats for sure, reset
    resetDelays();
  }
}
