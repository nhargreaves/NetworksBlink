 #include <Timer.h>
 #include "BlinkToRadio.h"
 
module BlinkToRadioC {
  uses {
    interface Boot;
    interface SplitControl as RadioControl;

    interface Leds;
    interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;

    interface Packet;
    interface AMPacket;
    interface AMSendReceiveI;
  }
}

implementation {
  uint16_t counter = 0;
  bool received = TRUE;
  
  message_t sendMsgBuf;
  message_t* sendMsg = &sendMsgBuf; // initially points to sendMsgBuf

  BlinkToRadioMsg* ack;
  message_t msgAckBuf;
  message_t* sendAck = &msgAckBuf;
  
  message_t* pastMsg;
  BlinkToRadioMsg lastPacketBuf;
  BlinkToRadioMsg* lastPacket = &lastPacketBuf;


  event void Boot.booted() {
    call RadioControl.start();
  };

  event void RadioControl.startDone(error_t error) {
    if (error == SUCCESS) {
      call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
    }
  };

  event void RadioControl.stopDone(error_t error){};



  event void Timer0.fired() {

    if(received == TRUE){
  	  //send a data message
	  BlinkToRadioMsg* btrpkt;
	  
	  //set packet types for message
	  call AMPacket.setType(sendMsg, AM_BLINKTORADIO);
	  call AMPacket.setDestination(sendMsg, DEST_ECHO);
	  call AMPacket.setSource(sendMsg, TOS_NODE_ID);
	  call Packet.setPayloadLength(sendMsg, sizeof(BlinkToRadioMsg));

	  //get packet
	  btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(sendMsg, sizeof (BlinkToRadioMsg)));
	  counter++;
		
	  btrpkt->type = TYPE_DATA;
	  btrpkt->seq = counter%2;
	  btrpkt->nodeid = TOS_NODE_ID;
	  btrpkt->counter = counter;

	  //store message in case of resending
	  pastMsg = sendMsg;
	  //c function to copy message into pastmsg
	  memcpy(pastMsg, sendMsg, sizeof *sendMsg);
		
	  //call sendreceive
	  sendMsg = call AMSendReceiveI.send(sendMsg);
	  
	  //call timer1 to resend if timeout is reached (3000ms here)
	  call Timer1.startOneShot(TIMER_PERIOD_MILLI*3);
	  
	  //set received as false so new message can be taken
	  received = FALSE;

    }  
 

  }
  
  event void Timer1.fired(){
  
        //if acknowledgement not received
		if(received == FALSE){
		//call amsendreceive with old message
			sendMsg = call AMSendReceiveI.send(pastMsg);
			call Timer1.startOneShot(TIMER_PERIOD_MILLI*3);
		}
	}
	
	//commented out task for task 2
//  task void rapidSend() {
//    uint32_t i;
//    for (i = 0; i < 60; i++) {
//	  call Leds.led0Toggle(//);
//	  }
//  }


  event message_t* AMSendReceiveI.receive(message_t* msg) {
	
    uint8_t len = call Packet.payloadLength(msg);
	
    BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)(call Packet.getPayload(msg, len));
    call Leds.set(btrpkt->counter);
	
//    post rapidSend(); //commented out for task 2
	
	//if message is a data message
    if(btrpkt->type == TYPE_DATA){

	//set packet
	  call AMPacket.setType(sendAck, AM_BLINKTORADIO);
	  call AMPacket.setDestination(sendAck, DEST_ECHO);
	  call AMPacket.setSource(sendAck, TOS_NODE_ID);
	  call Packet.setPayloadLength(sendAck, sizeof(BlinkToRadioMsg));
		
	  ack = (BlinkToRadioMsg*)(call Packet.getPayload(sendAck, sizeof (BlinkToRadioMsg)));
	   
	  //set ack message
  	  ack->type = TYPE_ACK;
	  ack->seq = btrpkt->seq;
	  ack->counter = counter;	
	  ack->nodeid = btrpkt->nodeid;
		
	  //send acknowledgement
	  sendAck = call AMSendReceiveI.send(sendAck);
	  //set received to false for next message
	  received = FALSE;

    }

	//if message is acknowledgement
    else if(btrpkt->type == TYPE_ACK) {
	//set received to true
      received = TRUE;
    }

    return msg; // no need to make msg point to new buffer as msg is no longer needed
  }
}