; rpi3-power-supply-mk2.asm
; Author:  Matthew J. Wolf
; Date: 18-Aug-17, Info added 16-SEP-2019
;  
; This file is part of the Arpi3-power-supply-mk2.
; By Matthew J. Wolf <matthew.wolf@speciosus.net>
; Copyright 2019 Matthew J. Wolf
;
; The rpi3-power-supply-mk2 is distributed in the hope that
; it will be useful, but WITHOUT ANY WARRANTY; without even the implied
; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
; the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with the Audio-Switch-MK4.
; If not, see <http://www.gnu.org/licenses/>.
;
        processor 16F18313
        radix     dec
        include p16f18313.inc		

 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_HFINT1 & _CLKOUTEN_OFF &  _CSWEN_ON & _FCMEN_OFF
 __CONFIG _CONFIG2, _MCLRE_ON & _PWRTE_ON & _WDTE_OFF & _LPBOREN_ON & _BOREN_OFF & _BORV_HIGH & _PPS1WAY_OFF & _STVREN_OFF & _DEBUG_OFF
 ;__CONFIG _CONFIG2, _MCLRE_ON & _PWRTE_ON & _WDTE_OFF & _LPBOREN_OFF & _BOREN_OFF & _BORV_LOW & _PPS1WAY_OFF & _STVREN_OFF & _DEBUG_OFF
 __CONFIG _CONFIG3, _WRT_OFF & _LVP_ON
 __CONFIG _CONFIG4, _CP_OFF & _CPD_OFF
 
; Manifest Constants -------------------------------------------------
     
POWER_LED  equ			H'02'		; PORTA pin for power LED
RELAY	   equ			H'05'		; PORTA pin for relay 
PB_POWER   equ			H'04'		; PORTA pin for power on Button     

CURRENT	   equ			H'00'
            
; File Registers ------------------------------------------------------
			udata 0x0020
Buttons		res			1
State		res			1
Count		res			1		

; Registers for 1 second delay		
d1		res			1
d2		res			1
d3		res			1
		
;----------------------------------------------------------------------------------------
STARTUP 	org     	0x0000		; processor reset vector
 	  		;pagesel	Start   ; not needed on a 16f628a 
			clrf    	PCLATH		
  			goto		Start

;			org		0x0004	;place code at interrupt vector
;InterruptCode
;			retfie	

Start
	
; Configure 			
	clrf    INTCON            ; No interrupts for now

	banksel	OSCCON1		  ; Oscillator Control
	movlw	0x60		  ; NOSC HFINTOSC ( 1 Mhz )  	    
	movfw	OSCCON1		  ; NDIV - Dividion by 1

	banksel	PMD0
	movlw	0x43
	movfw	PMD0
	
	movlw	0x07
	movfw	PMD1
	
	movlw	0x60
	movfw	PMD2
	
	movlw	0x73
	movfw	PMD3
	
	movlw	0x22
	movfw	PMD4
	
	movlw	0x07
	movfw	PMD5
	
	banksel	OSCFRQ		  ; Internal Oscillator HFINTOSC to 4 Mhz
	movlw	0x03
	movfw	OSCFRQ	
		
	banksel CM1CON0		  ; Comparator
	movlw	0x96		  ; Hysteresis, inverted, enabled 
	movwf	CM1CON0
	
	banksel CM1CON1		  ; Comparator connected to C1IN0+ and C1IN0-
	movlw	0x00		  ; No interrupt
	movwf	CM1CON1
	
        banksel TRISA                   
	movlw	0x1B		  ; 4,1,0 rest output. 3 is high 
        movwf   TRISA             ;
	
	;ODCONA - Open-Drain
	;INLVLA - input threshold - 0- ttl, 1- schmitt trigger
	
	banksel SLRCONA		 ; SLRCONA - Slew Rate -0x00
	movlw	0x0
	movwf	SLRCONA
	
	banksel ANSELA
	movlw	0x03		  ; 0,1 analog input
	movwf	ANSELA
	
	banksel WPUA
	movlw	0x18		  ; 3,4 weak pull-up enabled
	movwf	WPUA

;Init -------------------------------------------------------------------
	
	banksel	PORTA
	clrf	PORTA
	clrf 	Buttons		  ; Clear File Registers	
	clrf	State
	
	bsf	State,PB_POWER	  ;Initialize button state as up.
	
	; Power restore after power loss.
	; - Nice idea but the current drops below threshold wile caps drain.
	; inital Power is on - delay at start 

Loop	
	
	call	Power	
	call	Current_Check
	
	goto	Loop

; Subroutines ------------------------------------------------------------
Power
	    banksel		PORTA
	    movf		PORTA,W		    ; Get inputs
	    movwf		Buttons

	    ; Check button state
	    btfss		State,PB_POWER	    ; Was button down?
	    goto		PB_POWER_wasDown    ; Yes

PB_POWER_wasUp
	    btfsc		Buttons,PB_POWER    ; Is button still up?
	    return				    ; Was up and still up, do nothing
	    bcf			State,PB_POWER	    ; Was up, remember now down
	    return

PB_POWER_wasDown
	    btfss		Buttons,PB_POWER    ; If it is still down
	    return				    ; Was down and still down, do nothing
	    bsf			State,PB_POWER	    ; remember released

            btfss		State,POWER_LED     ; Skip if BS ON; go if off
            goto		POWER_On

            btfsc		State,POWER_LED     ; Skip if BS OFF; go if on
            goto		POWER_Off

            return
	    
Current_Check  
	    banksel		CM1CON0
	    btfsc		CM1CON0,C1OUT
	    goto		Current_High
	    
	    btfss		CM1CON0,C1OUT
	    goto		Current_Low
	   
	    return
	    
Current_High
	    banksel		State		    ; Current was high and 
	    btfsc		State,CURRENT	    ; is still high
	    return
	     
	    btfss		State,CURRENT	    ; We are off, turn on
	    goto		Current_POWER_On
	      
	    return

Current_Low
	    banksel		State
	    btfss		State,CURRENT	    ; All ready off	 
	    return
	    
	    btfsc		State,CURRENT	    ; Was trigger it high 
            goto		Current_POWER_Off   ; now low turn off   
	    	    
	    return

Current_POWER_On
	    banksel		State
	    bsf			State,CURRENT	    ; set on
	    goto		POWER_On
	    
	    return
	    
Current_POWER_Off
	    banksel		State
	    bcf			State,CURRENT	    ; clear
	    goto		POWER_Off
	    
	    return
POWER_On
            banksel		PORTA

            bsf			PORTA,POWER_LED	    ; LED on
            bsf			State,POWER_LED
	    
	    bsf			PORTA,RELAY	    ; Relay Closed
	    bsf			State,RELAY 
	    
	    call		POWER_Delay    
	    
            return
POWER_Off
            banksel		PORTA

            bcf			PORTA,POWER_LED	    ; LED off
            bcf			State,POWER_LED
 
	    bcf			PORTA,RELAY	    ; Relay open
            bcf			State,RELAY	    
	    
            return

POWER_Delay
	    banksel		Count
	    movlw		D'2'		    ; Delay for 5 seconds ???
	    movwf		Count
	    	    
	    call		Delay
	    decf		Count,F
	    movf		Count,W
	    iorlw		0x00
	    btfsc		STATUS,Z	    ; go: Count 0 exit
	    return
	    goto $-6			    
	     
	    return
	    	    
Delay
; Generated from: 
;http://www.piclist.com/techref/piclist/codegen/delay.htm?key=delay+routine&from
; 4mhz - 1 sec delay	    
; 999997 cycles
	    
	banksel d1				
	movlw	0x08
	movwf	d1
	movlw	0x2F
	movwf	d2
	movlw	0x03
	movwf	d3
Delay_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	$+2
	decfsz	d3, f
	goto	Delay_0

			;3 cycles
	goto	$+1
	nop
	
	return
	
        end	
