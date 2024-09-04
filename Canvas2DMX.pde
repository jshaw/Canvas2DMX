//import dmxP512.*;
import processing.serial.*;

import com.jaysonh.dmx4artists.*;

DMXControl dmx;

C2D c2d;
//DmxP512 dmxOutput;
Serial myPort;
int numPixels = 4;
//int universeSize = numPixels * 3 + 3;
int universeSize = numPixels * 6;
 //int universeSize = 30;

boolean LANBOX=false;
String LANBOX_IP="192.168.1.77";

//boolean DMXPRO=true;
//String DMXPRO_PORT="COM4";//case matters ! on windows port must be upper cased.
//String DMXPRO_PORT="COM4";//case matters ! on windows port must be upper cased.
//String DMXPRO_PORT="/dev/cu.usbserial-EN378576";//case matters ! on windows port must be upper cased.
//String DMXPRO_PORT="/dev/cu.usbserial-B001N0ZB";//case matters ! on windows port must be upper cased.
//int DMXPRO_BAUDRATE=115000;
//int DMXPRO_BAUDRATE=128000;
//int DMXPRO_BAUDRATE=256000;


PGraphics pg;

boolean value = false;

void setup() {
  
  size(400, 400, JAVA2D);
  // size(245, 245, P2D);

  pg = createGraphics(400, 400, JAVA2D);
  
  //c2d = new C2D(this, "127.0.0.1", 7890);
  // c2d = new C2D(this);
  c2d = new C2D();
  c2d.setColorCorrection(2.5, 0.90, 0.90, 0.90);
  c2d.showLocations(true);
  //c2d.setLEDStripOrder("GRB");
  c2d.setLEDStripOrder("RGB");
  
  //dmxOutput = new DmxP512(this, universeSize, false);
  dmx = new DMXControl( 0, universeSize );
  
  printArray(Serial.list());
  
  //myPort = new Serial(this, DMXPRO_PORT, DMXPRO_BAUDRATE);
  
  //if(LANBOX){
  //  dmxOutput.setupLanbox(LANBOX_IP);
  //}
  
  //if(DMXPRO && myPort.available() > 0){
  //  dmxOutput.setupDmxPro(DMXPRO_PORT,DMXPRO_BAUDRATE);
  //}
  //if(DMXPRO){
  //  //dmxOutput.setupDmxPro(DMXPRO_PORT,DMXPRO_BAUDRATE);
  //}
   
}

void draw() {    
  //int nbChannel=180;
  //int nbChannel=1;  
  // background(255);  
  background(255);

  float bgR = constrain(mouseX, 0, 255);
  float bgG = constrain(mouseY, 0, 255);

  pg.beginDraw();
    // pg.background(125);
    // pg.background(200, 0, 0);
    // pg.background(bg, 0, 0);
    // pg.background(0, bg, 0);
    pg.background(bgR, bgG, 0);

    if (mousePressed == true) {
    //if(value){
      float tmp = constrain((bgR+bgG), 0, 255);
      pg.push();
        pg.fill(0,0,tmp);
        //pg.rect(width/2 - 25, height/2 - 25, 50, 50);
        pg.rect(mouseX - 25, mouseY - 25 , 50, 50);
      pg.pop();
    }
    
  pg.endDraw();

  c2d.sendImage(pg);
  
  // Currently using GRB LEDs
  //dmxOutput.set(nbChannel,0);
  //dmxOutput.set(nbChannel+1,0);
  //dmxOutput.set(nbChannel+2,255);

  byte[] pd = c2d.writePixels();

   //println("PD PD PD PD PD: ");
   //println(pd);
  if(pd.length > 1){
    // println(pd[0]);
     //byte byteValue = pd[0];
     //int value = (byteValue >= (byte) 0) ? (int) byteValue : 256 + (int) byteValue; 
     //println(value);

    // println(pd[1]);
    // println(pd[2]);
  }
  
  if(pd.length > 1){
    //dmx.sendValue(19, 255);
    //dmx.sendValue(20, 255);
    //dmx.sendValue(21, 255);
    //dmx.sendValue(22, 255);
    //dmx.sendValue(23, 0);
    //dmx.sendValue(24, 0);
    //dmx.sendValue(25, 0);
  
    //for(int i=1;i<=universeSize;i++){
      for(int i=1;i<universeSize;i+=6){
      //print("convertByte(pd[i]): ");
      print(pd[i]);
      print(": ");
      println(convertByte(pd[i]));
      //dmxOutput.set(i, convertByte(pd[i]));
      dmx.sendValue(i, 255);
      dmx.sendValue(i+1, convertByte(pd[i]));
      dmx.sendValue(i+2, convertByte(pd[i+1]));
      dmx.sendValue(i+3, convertByte(pd[i+2]));
      
      //dmx.sendValue(i, 200);
      //dmx.sendValue(i, pd[i]);
      println(i);
      //dmxOutput.set(i, 200);
    }
  }
  
  //for(int i=0;i<universeSize;i++){
  //  int value=(int)random(10)+((i%2==0)?mouseX:mouseY);
  //  //dmxOutput.set(i,constrain(value,0,255));
  //  dmx.sendValue(i,constrain(value,0,255));
  //  fill(value);
  //  rect(0,i*height/10,width,(i+10)*height/10);    
  //}

  //for(int i=0;i<nbChannel;i++){
  //  int value=(int)random(10)+((i%2==0)?mouseX:mouseY);
  //  dmxOutput.set(i,value);
  //  fill(value);
  //  rect(0,i*height/10,width,(i+10)*height/10);    
  //}
  
  // c2d.ledStrip(0, 60, 0, 0, 2, PI/2, false);
  c2d.ledStrip(0, numPixels+3, 200, 200, 5, PI, false);
  // c2d.ledStrip(61, 120, 0, 0, 2, PI, false);
  // c2d.ledStrip(121, 180, 50, 50, 2, PI, false);
  
  c2d.draw();

  pg = c2d.receiveImage();

  image(pg, 0, 0);
  
}

int convertByte(byte byteValue){
  return (byteValue >= (byte) 0) ? (int) byteValue : 256 + (int) byteValue; 
}

void mousePressed() {
  if (value) {
    value = false;
  } else {
    value = true;
  }
}
