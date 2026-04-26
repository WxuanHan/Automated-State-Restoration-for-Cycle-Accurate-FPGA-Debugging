#include "xil_exception.h"
#include "xparameters.h"
#include "netif/xadapter.h"
#include "lwip/err.h"
#include "lwip/udp.h"
#include "xgpiops.h"


// This structure is used to define the interrupt handler parameters
typedef struct {
	void *udp; // Pointer to the UDP packet
	void *dev; // Pointer to the device initiated the interrupt
	void *ipaddr_s, *ipaddr_d;
} IntrPar;



// Interrupt handler to send data

void udp_recv_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p, ip_addr_t *addr, u16_t port);
void print_ip(char *msg, struct ip_addr *ip);
// missing declaration in lwIP
void lwip_init();

struct netif *netif, server_netif; 				//variables for network interfaces
struct ip_addr ipaddr_s, ipaddr_d, netmask, gw; //IP addresses storage
struct udp_pcb *udp; 							//a pointer to a UDP header structure

// the MAC address of the board. this should be unique per board
unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x03 };

IntrPar par1;				// a variable that will be passed to the interrupt handler
IntrPar *par = &par1;

int setupUdp ()
{
	par1.dev = NULL; 			//the interrupt controller and the GPIO variables

	///////////////////////////// Initialize network interface and IP protocol //////////////
	netif = &server_netif; 		//store a pointer for the network interface used later instead of using the variable itself


	IP4_ADDR(&ipaddr_s, 192, 168, 1, 10); 	//local ip address, Change it to the Ip of your Computer
	IP4_ADDR(&ipaddr_d, 192, 168, 1, 11); 	//remote ip address
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 192, 168, 1, 1);


	xil_printf("------------------------------------------------------\n\r");
	print_ip("Board  IP: ", &ipaddr_s);
	print_ip("Server IP: ", &ipaddr_d);
	print_ip("Netmask:   ", &netmask);
	print_ip("Gateway:   ", &gw);

	// initialize the light weight IP library
	lwip_init();

	if (!xemac_add(netif, &ipaddr_s, &netmask, &gw, mac_ethernet_address, XPAR_XEMACPS_0_BASEADDR)) {
		xil_printf("Error adding N/W interface\n\r");
		return -1;
	} else {
		xil_printf("Network Interface Added!\n\r");
	}

	netif_set_default(netif); 	// set the registered MAC interface as the default interface
	netif_set_up(netif); 		// specify that the network is up

	/////////////////////////////////// Prepare UDP Protocol////////////////////////
	if(NULL == (udp = udp_new())) 	//initialize the UDP header
		xil_printf("Problems initializing UDB!\n\r");
	else
		xil_printf("UDP Header Initialized!\n\r");


	par1.udp = udp; 				// fill out the UDP pointer of the interrupt handler input argument
	par1.ipaddr_s = &ipaddr_s;
	par1.ipaddr_d = &ipaddr_d;

	//initialize the local binding process on port 10024
	if(ERR_OK != udp_bind(udp,&ipaddr_s,10024))	{
		xil_printf("Problems binding address!\n\r");
		return -1;
	} else {
		xil_printf("Address Binding Successful!\n\r");
	}
	// we will use port 10024 for communication using UDB protocol
	// the previous function call initializes the connection and binding process

	//register the function recv_callback as the call back for incoming functions
	udp_recv(udp,(udp_recv_fn)udp_recv_callback,NULL);

	//this function will be called to process incoming package
	IntrPar *par = &par1;

	if(ERR_OK != udp_connect(par->udp,par->ipaddr_d,10024)) {	//connect to the remote board on port 10024
		xil_printf("Problems connecting to destination address!\n\r");
		return -1;
	} else {
		xil_printf("UDP connected! \n\r");
	}
	return 0;
}



/*

void ethernetSendData (int *data, int size)
{
	int i;
//	struct pbuf *p = pbuf_alloc(PBUF_RAW, size*sizeof(int), PBUF_POOL);
	struct pbuf *p = pbuf_alloc(PBUF_RAW, size*sizeof(int), PBUF_REF);
//	xil_printf("\r\nvalue pointed by address is  %d",  *data);
	p->payload = data;
//	p->payload = &data;
//	if(ERR_OK == udp_send(par->udp,p))
		udp_send(par->udp,p);
		xil_printf("\r\n %d", *(int *)(p->payload)); 	// send the buffer using the UDP protocol
		for (i=0;i<10000;i++)
		{
			}

	pbuf_free(p);
}

*/

void ethernetSendData (int *data, int size)
{
	int i;
//	struct pbuf *p = pbuf_alloc(PBUF_RAW, size*sizeof(int), PBUF_POOL);
	struct pbuf *p = pbuf_alloc(PBUF_RAW, size*sizeof(int), PBUF_REF);
//	xil_printf("\r\nvalue pointed by address is  %d",  *data);
	p->payload = data;
//	p->payload = &data;
//	if(ERR_OK == udp_send(par->udp,p))
		udp_send(par->udp,p);
		xil_printf("\r\n %d", *(int *)(p->payload)); 	// send the buffer using the UDP protocol


	pbuf_free(p);
}



void ethernetSendAck ()
{	int i;
	int ack = 10;
	struct pbuf *p = pbuf_alloc(PBUF_RAW, sizeof(int), PBUF_REF);
	p->payload = &ack;
	if(ERR_OK == udp_send(par->udp,p))
			xil_printf("\r\nSuccefully sent ACK %d", *(int *)(p->payload)); 	// send the buffer using the UDP protocol

	for (i=0;i<10000000;i++){}
	pbuf_free(p);
}

void init_arr (int *data, int size)
{
	int var;
	for (var = 0; var < size; ++var)
	{
		data[var] = var;
	}
}

// These functions are used to print out IP address information
void print_ip(char *msg, struct ip_addr *ip) {
	xil_printf(msg) ;
	xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

// Call back function for the incoming UDP packet (when data is received)
void udp_recv_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p, ip_addr_t *addr, u16_t port) {

	print_ip("\r\nI got something from: ", addr);

	int *data = (int *)p->payload; 		//pointer to packet data

	//XGpio_DiscreteWrite(led,1,data[0]); //display the first byte on the LEDs
	printf("%d\n\r",data[0]);								//from the other board
	printf("%d\n\r",data[1]);
	printf("%d\n\r",data[2]);
	printf("%d\n\r",data[3]);
	printf("%d\n\r",data[4]);

	pbuf_free(p); 						//free the buffer
	return;
}


