;
;
; Created: 1/13/2018 3:53:07 PM
; Author : Ayman
;
;

.equ freq = 16000000
.equ r_buad = 9600
.equ buad = (freq/(16*r_buad)-1)

.def temp1 = r16
.def temp2 = r17
.def temp3 = r18
.def rx_data = r19
.def tx_data = r20

.org 0x00
	rjmp init

init:

	;*** I/O Ports Setup ***;
	ldi temp1,(1 << PORTD2)|(1 << PORTD3)|(1 << PORTD4)|(1 << PORTD5)|(1 << PORTD6)|(1 << PORTD7)
	out DDRD,temp1

	
	;*** ADC Setup ***;
	// Get the temperture reading
	ldi temp1, (1 << REFS0) | (1 << MUX0) | (1 << MUX2) 
	sts ADMUX,temp1
	// Enable the ADC in Single Conversion Mode and with prescaler 128
	ldi temp1, (1 << ADEN)|(1 << ADPS0)|(1 << ADPS1)|(1 << ADPS2)
	sts ADCSRA, temp1

	// Disable digital input buffer
	ldi temp1, (1 << ADC5D)
	sts DIDR0, temp1

	;*** USART Setup ***;
	// Set baud rate to UBRR0
	ldi temp1,(buad >> 8)
	sts UBRR0H, temp1
	ldi temp1,(buad)
	sts UBRR0L, temp1
	// Enable receiver 
	ldi temp1, (1<<RXEN0)|(1<<TXEN0)
	sts UCSR0B,temp1
	// Set frame format: 8 bit data
	ldi temp1, (3<<UCSZ00)
	sts UCSR0C,temp1

	;*** PWM Setup ***;
	//First Counter For PIN 5,6
	//SET TO PWM MODE 1
	ldi temp1, (1 << COM0A1)|(1 << COM0B1)|(1 << WGM00)|(1 << WGM01)
	out TCCR0A,temp1; 
	//SET PRESCALER/DIVIDER TO /1024        
	ldi temp1,(5 << CS00)    
	out TCCR0B,temp1


loop:
	// Check for new data in the serial port
	inc tx_data
	lds temp1, UCSR0A		// Load the USART Control Register Data
	sbrc temp1, RXC0		// Check if the receive is completed
	rjmp read_data			// Move the Robot
	rjmp loop

write_data:
	sbrs temp1, UDRE0		// Check if the transmit buffer flag is empty
	rjmp write_data			// keep looping until the register is empty
	
	ldi temp1,(1 << ADSC)|(1 << ADEN)|(1 << ADPS0)|(1 << ADPS1)|(1 << ADPS2)	// START ADC Converter
	sts ADCSRA,temp1	
adc_delay:
	ldi temp1,ADCSRA		// Delay Until Conversion is finshed
	sbrs temp1,ADIF
	rjmp adc_delay
	lds tx_data,ADCL		// The Value From the ADC, only the low byte
	lds temp2,ADCH
	sts UDR0,tx_data		// send the data 
	ldi temp1,(0 << ADSC)|(1 << ADEN)|(1 << ADPS0)|(1 << ADPS1)|(1 << ADPS2)	// STOP ADC Converter
	sts ADCSRA,temp1
	rjmp loop
	
read_data:
	lds rx_data, UDR0		// Load the recevied data into the register	
	cpi rx_data,0xF0		// Compare the value recevied with 240d
	brsh write_data			// Branch if equal or higher to write 	
	
	sbrc rx_data,4			// Check for 1 in 4th bit position
	rjmp move_forward		// jump to move_forward subroutine
	sbrc rx_data,5			// Check for 1 in 5th bit position
	rjmp move_backward		// jump to move_backward subroutine
	sbrc rx_data,6			// Check for 1 in 6th bit position
	rjmp turn_right			// jump to turn_right subroutine
	sbrc rx_data,7			// Check for 1 in 7th bit position
	rjmp turn_left			// jump to turn_left subroutine
	
	rjmp stop				// If none of the cases match then stop


process:
	mov temp1,rx_data		// Copy the data temp1eroy
	andi temp1,0x0F			// Mask out only the fisrt 4 bits
	ldi temp2,16			// Load the number 16 in the temp2 register
	mul temp1,temp2			// Multiply the sent number by 16
	movw r25:r24,r1:r0		// Copy the result into another register
	sbiw r25:r24,1			// Subtract 1 from the result 
	mov temp1,r0			// Copy the lower byte tempreroy
	out OCR0A,temp1			// Enable pwm on pin 6 
	out OCR0B,temp1			// Enable pwm on pin 5 
	ret

stop:
	rcall process
	ldi temp1,(0 << PORTD2)|(0 << PORTD3)|(0 << PORTD4)|(0 << PORTD7)
	out PORTD,temp1
	rjmp loop
	
move_forward:
	rcall process
	ldi temp1,(1 << PORTD2)|(1 << PORTD3)|(0 << PORTD4)|(0 << PORTD7)
	out PORTD,temp1
	rjmp loop
	
	
move_backward:
	rcall process
	ldi temp1,(0 << PORTD2)|(0 << PORTD3)|(1 << PORTD4)|(1 << PORTD7)
	out PORTD,temp1
	rjmp loop

turn_right:
	rcall process
	ldi temp1,(1 << PORTD2)|(0 << PORTD3)|(1 << PORTD4)|(0 << PORTD7)
	out PORTD,temp1
	rjmp loop

turn_left:
	rcall process
	ldi temp1,(0 << PORTD2)|(1 << PORTD3)|(0 << PORTD4)|(1 << PORTD7)
	out PORTD,temp1
	rjmp loop
