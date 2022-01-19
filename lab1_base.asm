;LCD program which writes my student number(84372515) and name(Bennett Galamaga)
;Adapted from provided LCD test program

$NOLIST
$MODLP51
$LIST

org 0000H
    ljmp myprogram

; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7
LCD_LEFT equ p2.0 ;For scrolling the LCD to the left
LCD_RIGHT equ p2.3 ; For scrolling the LCD to the right

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
    push AR0
    mov R0, #177
    ;mov R0, #1 ;For testing
L0:
    nop
    nop
    djnz R0, L0 ; 1+1+3 cycles->5*45.21123ns*177=40us
    pop AR0
    ret

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
WaitmilliSec:
    push AR0
    push AR1
L3: mov R1, #45
L2: mov R0, #166
L1: djnz R0, L1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, L2 ; 22.51519us*45=1.013ms
    djnz R2, L3 ; number of millisecons to wait passed in R2
    pop AR1
    pop AR0
    ret
    
;---------------------------------;
; Toggles the LCD's 'E' pin       ;
;---------------------------------;
LCD_pulse:
    setb LCD_E
    lcall Wait40uSec
    clr LCD_E
    ret

;---------------------------------;
; Writes data to LCD              ;
;---------------------------------;
WriteData:
    setb LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes command to LCD           ;
;---------------------------------;
WriteCommand:
    clr LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
    ; Write high 4 bits first
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse

    ; Write low 4 bits next
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
    lcall LCD_pulse
    ret

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
    clr LCD_E   ; Resting state of LCD's enable is zero
    ; clr LCD_RW  ; Not used, pin tied to GND

    ; After power on, wait for the LCD start up time before initializing
    ; NOTE: the preprogrammed power-on delay of 16 ms on the AT89LP51RC2
    ; seems to be enough.  That is why these two lines are commented out.
    ; Also, commenting these two lines improves simulation time in Multisim.
    ; mov R2, #40
    ; lcall WaitmilliSec

    ; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x32 ; change to 4-bit mode
    lcall WriteCommand

    ; Configure the LCD
    mov a, #0x20
    lcall WriteCommand
    mov a, #0x0c
    lcall WriteCommand
    mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand

    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    lcall WaitmilliSec
    ret

;---------------------------------;
; Main loop.  Initialize stack,   ;
; ports, LCD, and displays        ;
; letters on the LCD              ;
;---------------------------------;
myprogram:
    mov SP, #7FH
    lcall LCD_4BIT
	;mov dptr, #name
	mov dptr, #test_string
	;Store the start address of the string into two registers for checking 
	;if we have reached the start of the string (See scroll_right)
	inc dptr
	mov R5, dph
	mov R4, dpl
	
	
;Used https://stackoverflow.com/questions/14261374/8051-lcd-hello-world-replacing-db-with-variable
;as a reference for this function

;Writes the next 16 characters of the string pointed to by dptr(must be null-terminated)
WriteString:
	;Each new character is written by writing the next 16 characters of the data-pointer
	;so need to store the data pointer for later, otherwise we will be jumping 16 characters at a time
	;instead of 1
	push dph
	push dpl
	mov R1, #16 ;Counter to tell how many characters to print
	mov a, #0x80 ;Move cursor to line 1 column 1
    lcall WriteCommand
    mov a, #0x02 ;Clear Screen
    lcall WriteCommand
    mov R2, #2 ;Allow time for the screen to clear
    lcall WaitmilliSec
nextChar:
	clr a ;Want to store current data pointed to by dptr into a, so prepare a for movc command
	movc a, @a+dptr
	inc dptr ;Need to increment dptr otherwise will print the same char over and over
	lcall WriteData ;Write the character stored in a to the LCD
	djnz R1, nextChar ;Keep track of how many characters have been written
	pop dpl ;After writing 16 characters, restore the dptr to its state before writing
	pop dph
	sjmp CheckForScroll

;LCD can only hold 80 characters, so need
;to keep track of how many characters have been read
;and add new characters once they are requested(through scrolling).
CheckForScroll:
	jnb LCD_LEFT, Scroll_left
	jnb LCD_RIGHT, Scroll_right
	sjmp CheckForScroll

Scroll_left:
	;Check if the end of the string has been reached
	mov a, #16 ;Need to offset by 16 characters so we can see if we've reached the end without displaying the 15 characters after the 0
	movc a, @a+dptr
	jz same_dptr_left
	inc dptr
same_dptr_left:
	mov a, #0x18 ;Instruction code for shifting the display to the left
	lcall WriteCommand
	;Wait 0.08 seconds	
	mov R2, #80
	lcall WaitmilliSec
	;call Wait40usec ;For testing
	sjmp WriteString
	
Scroll_right:
    clr a
    movc a, @a+dptr
    jz same_dptr_right       
	;Check if dptr is pointing to the beginning of the string
	;clr c
	;mov a, R5
	;subb a, dph
	;jnz dec_dptr
	;clr c
	;mov a, R4
	;subb a, dpl
	;jnz dec_dptr
	
	;Decrement dptr. Used code from
	;https://stackoverflow.com/questions/49920045/why-cant-we-decrement-data-pointer-in-alp#:~:text=The%208051%20microcontroller%20was%20built,low%20and%20high%20byte%20separately.
dec_dptr:
	clr c
	mov a, dpl 
    dec a 
    jnc skip_dec_dptr
    mov a, #0xFF 
    dec dph
skip_dec_dptr:
    mov dpl, a 
    sjmp same_dptr_right 
	
same_dptr_right:
	mov a, #0x1C ;Instruction code for shifting to the right
	lcall WriteCommand
	;Wait 0.08 seconds
	mov R2, #80
	lcall WaitMilliSec
	;lcall Wait40usec ;For testing
	sjmp WriteString
    
;String which stores my name
name:
	db 'Bennett Galamaga 84372515', 0
	
test_string:
	db 'This is a test string that is long enough that it cannot be stored in memory but not so long that it is impractical to debug. WOOOHOOOOOOOOOOOOOOOOOO!!!', 0

tale_of_two_cities:
	db 'A TALE OF TWO CITIES  A STORY OF THE FRENCH REVOLUTION  By Charles Dickens CHAPTER I. The Period '
	db 'It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of '
	db 'foolishness, it was the epoch of belief, it was the epoch of incredulity, it was the season of Light, it was the season of Darkness, it was the spring of hope, it was the winter of despair, we had everything before us, we had nothing before us, we were all going direct to Heaven, we were all going direct the other way—in short, the period was so far like the present period, that some of its noisiest authorities insisted on its being received, for good or for evil, in the superlative degree of comparison only.There were a king with a large jaw and a queen with a plain face, on the throne of England; there were a king with a large jaw and a queen with a fair face, on the throne of France. In both countries it was clearer than crystal to the lords of the State preserves of loaves and fishes, that things in general were settled for ever.It was the year of Our Lord one thousand seven hundred and seventy-five. Spiritual revelations were conceded to England at that favoured period, as at this. Mrs. Southcott had recently attained her five-and-twentieth blessed birthday, of whom a prophetic private in the Life Guards had heralded the sublime appearance by announcing that arrangements were made for the swallowing up of London and Westminster. Even the Cock-lane ghost had been laid only a round dozen of years, after rapping out its messages, as the spirits of this very year last past (supernaturally deficient in originality) rapped out theirs. Mere messages in the earthly order of events had lately come to the English Crown and People, from a congress of British subjects in America: which, strange to relate, have proved more important to the human race than any communications yet received through any of the chickens of the Cock-lane brood.France, less favoured on the whole as to matters spiritual than her sister of the shield and trident, rolled with exceeding smoothness down hill, making paper money and spending it. Under the guidance of her Christian pastors, she entertained herself, besides, with such humane achievements as sentencing a youth to have his hands cut off, his tongue torn out with pincers, and his body burned alive, because he had not kneeled down in the rain to do honour to a dirty procession of monks which passed within his view, at a distance of some fifty or sixty yards. It is likely enough that, rooted in the woods of France and Norway, there were growing trees, when that sufferer was put to death, already marked by the Woodman, Fate, to come down and be sawn into boards, to make a certain movable framework with a sack and a knife in it, terrible in history. It is likely enough that in the rough outhouses of some tillers of the heavy lands adjacent to Paris, there were sheltered from the weather that very day, rude carts, bespattered with rustic mire, snuffed about by pigs, and roosted in by poultry, which the Farmer, Death, had already set apart to be his tumbrils of the Revolution. But that Woodman and that Farmer, though they work unceasingly, work silently, and no one heard them as they went about with muffled tread: the rather, forasmuch as to entertain any suspicion that they were awake, was to be atheistical and traitorous. ,In England, there was scarcely an amount of order and protection to justify much national boasting. Daring burglaries by armed men, and highway robberies, took place in the capital itself every night; families were publicly cautioned not to go out of town without removing their furniture to upholsterers’ warehouses for security; the highwayman in the dark was a City tradesman in the light, and, being recognised and challenged by his fellow-tradesman whom he stopped in his character of “the Captain,” gallantly shot him through the head and rode away; the mail was waylaid by seven robbers, and the guard shot three dead, and then got shot dead himself by the other four, “in consequence of the failure of his ammunition:” after which the mail was robbed in peace; that magnificent potentate, the Lord Mayor of London, was made to stand and deliver on Turnham Green, by one highwayman, who despoiled the illustrious creature in sight of all his retinue; prisoners in London gaols fought battles with their turnkeys, and the majesty of the law fired blunderbusses in among them, loaded with rounds of shot and ball; thieves snipped off diamond crosses from the necks of noble lords at Court drawing-rooms; musketeers went into St. Giles’s, to search for contraband goods, and the mob fired on the musketeers, and the musketeers fired on the mob, and nobody thought any of these occurrences much out of the common way. In the midst of them, the hangman, ever busy and ever worse than useless, was in constant requisition; now, stringing up long rows of miscellaneous criminals; now, hanging a housebreaker on Saturday who had been taken on Tuesday; now, burning people in the hand at Newgate by the dozen, and now burning pamphlets at the door of Westminster Hall; to-day, taking the life of an atrocious murderer, and to-morrow of a wretched pilferer who had robbed a farmer’s boy of sixpence. All these things, and a thousand like them, came to pass in and close upon the dear old year one thousand seven hundred and seventy-five. Environed by them, while the Woodman and the Farmer worked unheeded, those two of the large jaws, and those other two of the plain and the fair faces, trod with stir enough, and carried their divine rights with a high hand. Thus did the year one thousand seven hundred and seventy-five conduct their Greatnesses, and myriads of small creatures—the creatures of this chronicle among the rest—along the roads that lay before them.', 0
END
