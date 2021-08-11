#####################################################################
#
# CSC258 Summer 2021 Assembly Final Project
# University of Toronto
#
# Student: Name, Student Number, UTorID
# Member1: Shuai Zhu, 1006034523, zhushua5
# Member2: Yi Yang,   1005910267, yangy180

#
# Bitmap Display Configuration:
# - Unit width in pixels: 8 (update this as needed)
# - Unit height in pixels: 8 (update this as needed)
# - Display width in pixels: 512 (update this as needed)
# - Display height in pixels: 512 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission? Milestone 1
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3 (choose the one that applies)

# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. scoring system
# 2. pickups: add 1 health, add jet speed, add bullet speed, add bullet amount, add score, slow down obstacle
# 3. shooting obstacles, 1 bullet destroys the obstalce, but goes through the pick ups
#
# Link to video demonstration for final submission:
# https://play.library.utoronto.ca/watch/9c63451e045dbdd97f1f95190f9c14ee
#
# Are you OK with us sharing the video with people outside course staff?
# Yes
#
# Any additional information that the TA needs to know:
# Jet 11x12, Obstacle 7x7
# Controls: WASD to Move, SPACE to start game, P to restart game
#####################################################################
.data
displayAddress: .word		0x10008000
#	          		 Green(0)    DGrey(4)    Grey(8)     LGrey(12)   White(16)   Azure(20)   DRed(24)    LBlue(28)   Red(32)    Black(36)   LGreen(40)  LYellow(44) Orange(48)
color:	.word			0x00228b22, 0x004f4f4f, 0x00616161, 0x00707070, 0x00ffffff, 0x000088cc, 0x00a10000, 0x0087ceeb, 0x00ff5a5a, 0x00000000, 0x00bcffc0, 0x00ffeb00, 0x00ffcc00
# Address of obstacles
obspos: 	.word		0x10007A00, 0x10006A00, 0x10005A00
# Number of Objects
obsnum: 	.byte		3
# Address of Jet		
beampos:	.word		1, 1
jetpos: 	.word		0
#				BeamSpeed-up	Beam lvl	Jet Speed-up	Obstacle Slow	Score
buff:		.word		0,		0,		0,		0,		0,
# 			 PickUp Positions(0)   Pick-up kind(4), Next pick-up(8)
PickUpAttr:	.word  		0x10007C00, 	-1, 		69
# Sleep Constant
.eqv		SleepTime	30
# Initial HP
.eqv            HP 		3
# MMIO Address 
.eqv		MMIOAddr	0xffff0000
# DifficultyLevel at score: xxxx
.eqv		DiffLvl1	500
.eqv		DiffLvl2	1500
# Set delay at different levels
.eqv		DelayAtLevel0	30
.eqv		DelayAtLevel1	25
.eqv		DelayAtLevel2	20

.text
lw $t0, displayAddress	# $t7 stores the base address for display
la $t1, color		# $t1 stores the base address for the color array
la $t2, obspos		# $t2 stores the current address of the obstacles
lb $t3, obsnum		# $t3 stores the number of obstacles currently on the display
addi $t4, $t0, 12396	# $t4 now stores the initial address of the jet
la $t5, SleepTime	# $t5 stores the SleepTime
la $t6, beampos
la $t7, PickUpAttr
li $t8, HP			
li $t9, 0xffff0000	# MMIO address
# $s0 is used to load the color

# +256 next row, +252 end row
# 0 start row
# 16128 end row
# 64x64

# $t0: displayAddress
# $t1: color (array)
# $t2: obspos (array)
# $t3: obsnum (not used?)
# $t4: jetpos
# $t5: SleepTime
# $t6: beampos
# $t7: PickUpPos (array)
# $t8: HP
# $t9: MMIO Address (might not need)


StartOver:
	# Randomize the first 3 obs generated
	lw $s1, 0($t2)
	li $a1, 56
	jal RandomLocation		# upperbound stored in $a1, return value in $v1
	add $s1, $s1, $v1
	sw $s1, 0($t2)
	
	lw $s1, 4($t2)
	jal RandomLocation
	add $s1, $s1, $v1
	sw $s1, 4($t2)
	
	lw $s1, 8($t2)
	jal RandomLocation
	add $s1, $s1, $v1
	sw $s1, 8($t2)    
	add $s1, $0, $0 		# Reset $s1
    	
    	# Randomize the first pick up kind
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 6			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sw $a0, 4($t7)			# Decide Pick-up Kind
	
	# Initial pickup location
	lw $s2, 0($t7)			# Call RandomLocation: Decide row of $s2
	li $a1, 60
	jal RandomLocation		# $v1 has the return value
	add $s2, $s2, $v1		
	sw $s2, 0($t7)
	add $s2, $0, $0			# Reset $s2
    
	
ClearScreen:				# clear screen before redraw (in case player press 'p' and go back here)
	addi $sp, $sp, -4
	sw $s1, 0($sp)         		# save previous $s1
    
	addi $s1, $t0, 0x3ffc  		# last pixel

ClearLoop:
	blt $s1, $t0, ClearDone
	lw $s0, 36($t1)			# BLACK
	sw $s0, 0($s1)
	addi $s1, $s1, -4
	j ClearLoop
    
ClearDone:    
	# GameStart takes a function argument $a0
	addi $a0, $t1, 16
	addi $a1, $t1, 20
     
 	jal StartScreen
	jal Jet

	lw $s1, 0($sp)
	addi $sp, $sp, 4        # restore $s1


StartGame:      li $s2, 0xffff0000
                lw $s1, 0($s2)             	# $s1 = 1, key_pressed
                bne $s1, 1, StartGame      	# if $s1 != 1, jump back
CheckIfSpace:   lw $s3, 4($s2)              	# $s3 contains ASCII value of the key pressed
                bne $s3, 0x20, StartGame    	# if $s3 != SP, jump back

                addi $a0, $t1, 36           	# $a0, a1: Black
                addi $a1, $t1, 36           	# clear start screen
                jal StartScreen
                
                j GameStartEnd              	# SP must have been pressed

GameStartEnd:   
	# sw $0, 0($t9)                    	# set reg at 0xffff0000 back to 0
	# sw $0, 4($t9)                    	# set key_pressed to some key unimportant
            
	lw $s1, 0($t9) 
	beq $s1, 1, keypress_happened
	lw $t0, displayAddress			# set $t0 back to display addr	
	j BuffUpdater
BuffUpdated:
	jal Jet 
	jal ScoreStart
	j Beam
GameBeamDone:
	jal CheckHP
	jal DrawAllObstacles
	j PickUpMovement
GameCheckPickUpDone:
	j PickUpCollision
GamePickUpCollisionDone:
	j CheckCollisionAll
GameCheckCollisionDone:
	jal SetDelay
	j GameStartEnd


SetDelay:
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp)  
	
	la $s1, buff
	lw $s1, 12($s1)
	bgt $s1, 0, DelayLvl0
	
	# If obstacle movement slow buff not available
	la $s1, buff
	lw $s1, 16($s1)			# score
	li $s2, DiffLvl1
	blt $s1, $s2, DelayLvl0 	# score < score for difficulty level 1
	# $s3 >= ScoreDiffLvl1
	li $s2, DiffLvl2
	blt $s1, $s2, DelayLvl1	# score < ScoreDiffLvl2
	# $s3 >= ScoreDiffLvl2
	j DelayLvl2
DelayLvl0:	
	li $v0, 32
	li $a0, DelayAtLevel0		 	
	syscall
	j DelaySet
DelayLvl1:	
	li $v0, 32
	li $a0, DelayAtLevel1		 	
	syscall
	j DelaySet
DelayLvl2:	
	li $v0, 32
	li $a0, DelayAtLevel2	 	
	syscall
	j DelaySet
DelaySet:
	lw $s2, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s2 back
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	jr $ra

keypress_happened:  
	lw $s2, 4($t9)			# this assumes $t9 is set to 0xfff0000 from before
	beq $s2, 0x77, respond_to_w	# w in ASCII
	beq $s2, 0x61, respond_to_a	# a in ASCII
	beq $s2, 0x73, respond_to_s	# s in ASCII
	beq $s2, 0x64, respond_to_d	# d in ASCII
	beq $s2, 0x20, respond_to_SP	# SP in ASCII
	beq $s2, 0x70, respond_to_p	# p in ASCII, go to the start screen upon pressing p
                    
	j GameStartEnd			# keypressed is not valid
	
respond_to_p:		# Set all data back to default values
	lw $t0, displayAddress	# $t7 stores the base address for display
	la $t1, color		# $t1 stores the base address for the color array
	la $t2, obspos		# $t2 stores the current address of the obstacles
	lb $t3, obsnum		# $t3 stores the number of obstacles currently on the display
	addi $t4, $t0, 12396	# $t4 now stores the initial address of the jet
	la $t5, SleepTime	# $t5 stores the SleepTime
	la $t6, beampos
	la $t7, PickUpAttr
	li $t8, HP			
	li $t9, 0xffff0000	# MMIO address
	
	# Reset obs pos in .data
	addi $s1, $0, 0x10007A00
	sw $s1, 0($t2)
	addi $s1, $0, 0x10006A00
	sw $s1, 4($t2)
	addi $s1, $0, 0x10005A00
	sw $s1, 8($t2)
	
	# Reset beam pos in .data
	addi $s1, $0, 1
	sw $s1, 0($t6)
	sw $s1, 4($t6)
	
	# Reset buff in .data
	la $s2, buff
	add $s1, $0, $0
	sw $s1, 0($s2)
	sw $s1, 4($s2)
	sw $s1, 8($s2)
	sw $s1, 12($s2)
	sw $s1, 16($s2)
	
	# Reset PickUpAttr in .data
	addi $s1, $0, 0x10007C00
	sw $s1, 0($t7)
	addi $s1, $0, -1
	sw $s1, 4($t7)
	addi $s1, $0, 69
	sw $s1, 8($t7)
	
	# Set $s0~7 to 0
	add $s1, $0, $0
	add $s2, $0, $0
	add $s3, $0, $0
	add $s4, $0, $0
	add $s5, $0, $0
	add $s6, $0, $0
	add $s7, $0, $0
	j StartOver
                    
respond_to_w:      
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s7, 0($sp)  
	
	addi $t0, $t0, 0x100		# First block of the second line, set back at the begining of the loop
	blt $t4, $t0, MovementPop$s3s7	# Go Back if at top

	la $s3, buff
	lw $s3, 8($s3)			# JS
	beq $s3, 0, wSingleSpeed
wDoubleSpeed:	
	subi $t4, $t4, 0x100		# Move up
	lw $s0, 36($t1)			# BLACK
	sw $s0, 3072($t4)
	sw $s0, 2820($t4)
	sw $s0, 2568($t4)
	sw $s0, 2316($t4)
	sw $s0, 2832($t4)
	sw $s0, 3348($t4)
	sw $s0, 2840($t4)
	sw $s0, 2332($t4)
	sw $s0, 2592($t4)
	sw $s0, 2852($t4)
	sw $s0, 3112($t4)
	blt $t4, $t0, MovementPop$s3s7	# Go Back if at top
wSingleSpeed:
	subi $t4, $t4, 0x100		# Move up
	lw $s0, 36($t1)			# BLACK
	sw $s0, 3072($t4)
	sw $s0, 2820($t4)
	sw $s0, 2568($t4)
	sw $s0, 2316($t4)
	sw $s0, 2832($t4)
	sw $s0, 3348($t4)
	sw $s0, 2840($t4)
	sw $s0, 2332($t4)
	sw $s0, 2592($t4)
	sw $s0, 2852($t4)
	sw $s0, 3112($t4)
	j MovementPop$s3s7
	
respond_to_a:
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s7, 0($sp)
	
	andi $s7, $t4, 0xffffff00	# First pixel in the line
	ble $t4, $s7, MovementPop$s3s7	# Go back if reach left edge
    	
    	addi $sp, $sp, -4
	sw $s3, 0($sp) 
	la $s3, buff
	lw $s3, 8($s3)			# JS
	beq $s3, 0, aSingleSpeed
aDoubleSpeed:	
	subi $t4, $t4, 4		# Move left
	lw $s0, 36($t1)
	sw $s0, 0x018($t4)
	sw $s0, 0x118($t4)
	sw $s0, 0x218($t4)
	sw $s0, 0x31c($t4)
	sw $s0, 0x41c($t4)
	sw $s0, 0x51c($t4)
	sw $s0, 0x620($t4)
	sw $s0, 0x724($t4)
	sw $s0, 0x62c($t4)
	sw $s0, 0x72c($t4)
	sw $s0, 0x82c($t4)
	sw $s0, 0x92c($t4)
	sw $s0, 0xa2c($t4)
	sw $s0, 0xb2c($t4)
	sw $s0, 0x604($t4)
	sw $s0, 0x704($t4)
	sw $s0, 0x90c($t4)
	sw $s0, 0xa08($t4)
	sw $s0, 0xb04($t4)
	sw $s0, 0x91c($t4)
	sw $s0, 0xa1c($t4)
	sw $s0, 0xb18($t4)
	sw $s0, 0xc18($t4)
	ble $t4, $s7, MovementPop$s3s7	# Go back if reach left edge
aSingleSpeed:
	subi $t4, $t4, 4		# Move left
	lw $s0, 36($t1)
	sw $s0, 0x018($t4)
	sw $s0, 0x118($t4)
	sw $s0, 0x218($t4)
	sw $s0, 0x31c($t4)
	sw $s0, 0x41c($t4)
	sw $s0, 0x51c($t4)
	sw $s0, 0x620($t4)
	sw $s0, 0x724($t4)
	sw $s0, 0x62c($t4)
	sw $s0, 0x72c($t4)
	sw $s0, 0x82c($t4)
	sw $s0, 0x92c($t4)
	sw $s0, 0xa2c($t4)
	sw $s0, 0xb2c($t4)
	sw $s0, 0x604($t4)
	sw $s0, 0x704($t4)
	sw $s0, 0x90c($t4)
	sw $s0, 0xa08($t4)
	sw $s0, 0xb04($t4)
	sw $s0, 0x91c($t4)
	sw $s0, 0xa1c($t4)
	sw $s0, 0xb18($t4)
	sw $s0, 0xc18($t4)
	j MovementPop$s3s7

respond_to_s:       
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s7, 0($sp)  
	
	addi $t0, $t0, 0x3300		# Below 52th Row
	bge $t4, $t0, MovementPop$s3s7	# Go Back if at top

	la $s3, buff
	lw $s3, 8($s3)			# JS
	beq $s3, 0, sSingleSpeed
sDoubleSpeed:	
	addi $t4, $t4, 0x100             # Move down
	lw $s0, 36($t1)         
	# Red parts
	sw $s0, -236($t4)
	sw $s0, 1280($t4)
	sw $s0, 1320($t4)
	# White parts
	sw $s0, 1292($t4)
	sw $s0, 1544($t4)
	sw $s0, 1308($t4)
	sw $s0, 1568($t4)
	# Blue parts
	sw $s0, 528($t4)
	sw $s0, 536($t4)
	sw $s0, 1796($t4)
	sw $s0, 1828($t4)
	bge $t4, $t0, MovementPop$s3s7	# Go Back if at top
sSingleSpeed:
	addi $t4, $t4, 0x100             # Move down
	lw $s0, 36($t1)         
	# Red parts
	sw $s0, -236($t4)
	sw $s0, 1280($t4)
	sw $s0, 1320($t4)
	# White parts
	sw $s0, 1292($t4)
	sw $s0, 1544($t4)
	sw $s0, 1308($t4)
	sw $s0, 1568($t4)
	# Blue parts
	sw $s0, 528($t4)
	sw $s0, 536($t4)
	sw $s0, 1796($t4)
	sw $s0, 1828($t4)
	j MovementPop$s3s7
	
respond_to_d:
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s7, 0($sp)
	
	andi $s7, $t4, 0xffffff00	# First pixel in the line              
	addi $s7, $s7, 212                          
	bge $t4, $s7, MovementPop$s3s7	# when the jet reach the right edge
	la $s3, buff
	lw $s3, 8($s3)			# JS
	beq $s3, 0, dSingleSpeed
dDoubleSpeed: 
	addi $t4, $t4, 4		# Move right
	lw $s0, 36($t1)
	sw $s0, 0x010($t4)
	sw $s0, 0x110($t4)
	sw $s0, 0x210($t4)
	sw $s0, 0x30c($t4)
	sw $s0, 0x40c($t4)
	sw $s0, 0x50c($t4)
	sw $s0, 0x608($t4)
	sw $s0, 0x704($t4)
	sw $s0, 0x5fc($t4)
	sw $s0, 0x6fc($t4)
	sw $s0, 0x7fc($t4)
	sw $s0, 0x8fc($t4)
	sw $s0, 0x9fc($t4)
	sw $s0, 0xafc($t4)
    
	sw $s0, 0x624($t4)
	sw $s0, 0x724($t4)
	sw $s0, 0x91c($t4)
	sw $s0, 0xa20($t4)
	sw $s0, 0xb24($t4)
	sw $s0, 0x90c($t4)
	sw $s0, 0xa0c($t4)
	sw $s0, 0xb10($t4)
	sw $s0, 0xc10($t4)
	bge $t4, $s7, MovementPop$s3s7
dSingleSpeed:
	addi $t4, $t4, 4		# Move right
	lw $s0, 36($t1)
	sw $s0, 0x010($t4)
	sw $s0, 0x110($t4)
	sw $s0, 0x210($t4)
	sw $s0, 0x30c($t4)
	sw $s0, 0x40c($t4)
	sw $s0, 0x50c($t4)
	sw $s0, 0x608($t4)
	sw $s0, 0x704($t4)
	sw $s0, 0x5fc($t4)
	sw $s0, 0x6fc($t4)
	sw $s0, 0x7fc($t4)
	sw $s0, 0x8fc($t4)
	sw $s0, 0x9fc($t4)
	sw $s0, 0xafc($t4)
    
	sw $s0, 0x624($t4)
	sw $s0, 0x724($t4)
	sw $s0, 0x91c($t4)
	sw $s0, 0xa20($t4)
	sw $s0, 0xb24($t4)
	sw $s0, 0x90c($t4)
	sw $s0, 0xa0c($t4)
	sw $s0, 0xb10($t4)
	sw $s0, 0xc10($t4)
	# j MovementPop$s3s7

MovementPop$s3s7:
	lw $t0, displayAddress		# set $t0 back to display addr	
	lw $s7, 0($sp)
	addi $sp, $sp, 4		# restore $s7	
	lw $s3, 0($sp)
	addi $sp, $sp, 4		# restore $s3
	j GameStartEnd
    
respond_to_SP:
	addi $sp, $sp, -4
	sw $s2, 0($sp)
	addi $sp, $sp, -4
	sw $s3, 0($sp)
	addi $sp, $sp, -4
	sw $s4, 0($sp)
	
	la $s4, buff
	lw $s4, 4($s4)			# beam lvl ?
	bgt $s4, 0, ShootTwo		
ShootOne:
	lw $s2, 0($t6)
	bne $s2, 1, SPPopFromStack	# if beampos != 1, go back (go back if no beam available)
	# if beamopos == 1 (beam not present on screen, set beam pos to the jet pos)
	addi $s2, $t4, -492		# $s2 stores pos of first beam
	sw $s2, 0($t6)
	j SPPopFromStack
ShootTwo:
	lw $s2, 0($t6)
	lw $s3, 4($t6)
	bne $s3, 1, SPPopFromStack	# if second beampos != 1, go back (go back if no beam available)
	# if second beamopos == 1 (beam not present on screen, set beam pos to the jet pos)
	addi $s3, $t4, -492
	addi $s2, $s3, -0x400
	sw $s2, 0($t6)
	sw $s3, 4($t6)		
	# j SPPopFromStack
SPPopFromStack:
	lw $t0, displayAddress		# set $t0 back to display addr	
	lw $s4, 0($sp)
	addi $sp, $sp, 4
	lw $s3, 0($sp)
	addi $sp, $sp, 4
	lw $s2, 0($sp)
	addi $sp, $sp, 4
	j GameStartEnd
	

Beam:	
	addi $sp, $sp, -4		# push $s2 to stack
	sw $s2, 0($sp)
	addi $sp, $sp, -4		# push $s3 to stack
	sw $s3, 0($sp)
	addi $sp, $sp, -4		# push $s4 to stack
	sw $s4, 0($sp)
	addi $sp, $sp, -4		# push $s4 to stack
	sw $s5, 0($sp)
	
	lw $s2, 0($t6)			# first beam pos
	lw $s3, 4($t6)			# second beam pos
	
	la $s5, buff			
	lw $s4, 4($s5)			# check beam level
	lw $s5, 0($s5)			# beam speed
	beq $s5, 0, BS0
BS1:	addi $s5, $0, -768
	j BeamAmount
BS0:	addi $s5, $0, -512
BeamAmount:	
	bgt $s4, 0, DrawTwoBeams
	
DrawOneBeam:	
	# $s2 == 0
	beq $s2, 1, BeamStatus		# if first beam's pos == 1, show beam status at bottom left corner

	# != 1, draw beam
	# Erase	
	#la $s4, buff			
	#lw $s4, 0($s4)			# check beam speed
	
	lw $s0, 36($t1) 		# Black
	sw $s0, 0($s2)			# middle beam
	sw $s0, 0x100($s2)

	add $s2, $s2, $s5		# update pos
	
	lw $s0, 28($t1)			# Light blue
	sw $s0, 0($s2)			# middle beam
	sw $s0, 0x100($s2)
	
	lw $s0, 36($t1)			# erase beam status
	sw $s0, 0x3810($t0)
	sw $s0, 0x390c($t0)
	sw $s0, 0x3910($t0)
	sw $s0, 0x3914($t0)
	sw $s0, 0x3a0c($t0)
	sw $s0, 0x3a10($t0)
	sw $s0, 0x3a14($t0)
	sw $s0, 0x3b10($t0)
	sw $s0, 0x3b14($t0)
	sw $s0, 0x3b0c($t0)
	sw $s0, 0x3c10($t0)
	sw $s0, 0x3710($t0)
	sw $s0, 0x380c($t0)
	sw $s0, 0x3814($t0)
	sw $s0, 0x3610($t0)
	sw $s0, 0x370c($t0)
	sw $s0, 0x3714($t0)

	bge $s2, 0x10006A00, BeamJumpBack
	addi $s2, $0, 1
	j BeamJumpBack

DrawTwoBeams:
	beq $s3, 1, BeamStatus		# if second beam's pos == 1, show beam status at bottom left corner
	# second beam pos != 1, cannot shoot, update beam pos
	# Erase	
	#la $s4, buff			
	#lw $s4, 0($s4)			# check beam speed
	
	lw $s0, 36($t1) 		# Black
	sw $s0, 0($s3)			# middle beam
	sw $s0, 0x100($s3)

	#beq $s4, 0, TwoBeamSingleSpeed	
	
	add $s3, $s3, $s5		# update pos
	
	lw $s0, 28($t1)			# Light blue
	sw $s0, 0($s3)			# middle beam
	sw $s0, 0x100($s3)
	
	lw $s0, 36($t1)			# erase beam status
	sw $s0, 0x3810($t0)
	sw $s0, 0x390c($t0)
	sw $s0, 0x3910($t0)
	sw $s0, 0x3914($t0)
	sw $s0, 0x3a0c($t0)
	sw $s0, 0x3a10($t0)
	sw $s0, 0x3a14($t0)
	sw $s0, 0x3b10($t0)
	sw $s0, 0x3b14($t0)
	sw $s0, 0x3b0c($t0)
	sw $s0, 0x3c10($t0)
	sw $s0, 0x3710($t0)
	sw $s0, 0x380c($t0)
	sw $s0, 0x3814($t0)
	sw $s0, 0x3610($t0)
	sw $s0, 0x370c($t0)
	sw $s0, 0x3714($t0)

	bge $s3, 0x10006E00, CheckFirstBeam
	addi $s3, $0, 1
	j BeamJumpBack

CheckFirstBeam:	
	beq $s2, 1, BeamJumpBack	# first beam do not need to update
	# Draw first beam if $s2 != 1
	# Erase	
	lw $s0, 36($t1) 		# Black
	sw $s0, 0x000($s2)              # middle beam
	sw $s0, 0x100($s2)
	
	add $s2, $s2, $s5		# update pos
	
	lw $s0, 28($t1)			# Light blue
	sw $s0, 0($s2)			# middle beam
	sw $s0, 0x100($s2)
	sw $s0, 0($s3)			# middle beam
	sw $s0, 0x100($s3)
	
	j BeamJumpBack
		
BeamStatus:
	la $s4, buff			# Beam level		
	lw $s4, 4($s4)
	beq $s4, 0, BeamStatus0
BeamStatus1:
	la $s5, buff
	lw $s5, 4($s5)			# BeamFlash takes $s5 as argument
	add $v1, $0, $0
	jal BuffFlash
	beq $v1, 5, BeamStatusErase	# Flash
	lw $s0, 28($t1)
	sw $s0, 0x3710($t0)
	sw $s0, 0x380c($t0)
	sw $s0, 0x3814($t0)
	sw $s0, 0x3610($t0)
	sw $s0, 0x370c($t0)
	sw $s0, 0x3714($t0)	
BeamStatus0:
	lw $s0, 28($t1)			# Light blue
	sw $s0, 0x3810($t0)
	sw $s0, 0x390c($t0)
	sw $s0, 0x3910($t0)
	sw $s0, 0x3914($t0)
	sw $s0, 0x3a0c($t0)
	sw $s0, 0x3a10($t0)
	sw $s0, 0x3a14($t0)
	sw $s0, 0x3b10($t0)
	sw $s0, 0x3b14($t0)	
	lw $s0, 20($t1)	
	sw $s0, 0x3b0c($t0)
	sw $s0, 0x3c10($t0)
	
	j BeamJumpBack
	
BeamStatusErase:
	lw $s0, 36($t1)
	sw $s0, 0x3710($t0)
	sw $s0, 0x380c($t0)
	sw $s0, 0x3814($t0)
	sw $s0, 0x3610($t0)
	sw $s0, 0x370c($t0)
	sw $s0, 0x3714($t0)
	
BeamJumpBack:
	sw $s2, 0($t6)
	sw $s3, 4($t6)
	
	lw $s5, 0($sp)
        addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	lw $s3, 0($sp)
        addi $sp, $sp, 4
        lw $s2, 0($sp)
        addi $sp, $sp, 4
        
	j GameBeamDone
	
	
# This Jet is 11x12
Jet:	# $t4 stores the curr addr of the top left corner of the jet
	lw $s0, 32($t1)			# $s0 stores the color code of Red
	sw $s0, 20($t4)
	sw $s0, 1536($t4)
	sw $s0, 1556($t4)
	sw $s0, 1576($t4)
	sw $s0, 1808($t4)
	sw $s0, 1816($t4)
	
	lw $s0, 28($t1)			# $s0 stores the color code of LightBlue
	sw $s0, 784($t4)
	sw $s0, 792($t4)
	sw $s0, 2052($t4)
	sw $s0, 2084($t4)
	sw $s0, 2304($t4)
	sw $s0, 2344($t4)
	
	lw $s0, 16($t1)			# $s0 stores the color code of White
	sw $s0, 276($t4)
	sw $s0, 532($t4)
	sw $s0, 788($t4)
	sw $s0, 1040($t4)
	sw $s0, 1044($t4)
	sw $s0, 1048($t4)
	sw $s0, 1296($t4)
	sw $s0, 1300($t4)
	sw $s0, 1304($t4)
	sw $s0, 1548($t4)
	sw $s0, 1552($t4)
	sw $s0, 1560($t4)
	sw $s0, 1564($t4)
	sw $s0, 1792($t4)
	sw $s0, 1800($t4)
	sw $s0, 1804($t4)
	sw $s0, 1812($t4)
	sw $s0, 1820($t4)
	sw $s0, 1824($t4)
	sw $s0, 1832($t4)
	sw $s0, 2048($t4)
	sw $s0, 2056($t4)
	sw $s0, 2060($t4)
	sw $s0, 2064($t4)
	sw $s0, 2068($t4)
	sw $s0, 2072($t4)
	sw $s0, 2076($t4)
	sw $s0, 2080($t4)
	sw $s0, 2088($t4)
	sw $s0, 2308($t4)
	sw $s0, 2312($t4)
	sw $s0, 2320($t4)
	sw $s0, 2324($t4)
	sw $s0, 2328($t4)
	sw $s0, 2336($t4)
	sw $s0, 2340($t4)
	sw $s0, 2560($t4)
	sw $s0, 2564($t4)
	sw $s0, 2576($t4)
	sw $s0, 2580($t4)
	sw $s0, 2584($t4)
	sw $s0, 2596($t4)
	sw $s0, 2600($t4)
	sw $s0, 2816($t4)
	sw $s0, 2836($t4)
	sw $s0, 2856($t4)
	sw $s0, 3092($t4)
	jr $ra				# Jumps to StartGame



# The obstacle is 7x7		

	# While loop
	#bne $s3, $t3, RandomGenerator		# when number of obstacles reached set value, exit RandomGenerator
	#addi $s3, $s3, 1		# i++
	#j RandomGenerator
	
#push	
#addi $sp, $sp, -4
#sw $s1, 0($sp)
# pop		
#lw $t2, 0($sp)
#addi $sp, $sp, 4

DrawAllObstacles:
        # push
        addi $sp, $sp, -4
        sw $s3, 0($sp)
        addi $sp, $sp, -4
        sw $s4, 0($sp)
        addi $sp, $sp, -4
        sw $s5, 0($sp)
        addi $sp, $sp, -4
        sw $s6, 0($sp)
        
        add $s6, $0, $0       # set $s6 to 0
        
        addi $sp, $sp, -4
        sw $ra, 0($sp)        # use $ra here jumps back to obstacle move line in GameStartEnd
        
        la $t2, obspos
LoopDAO:    # while s6 < 2
        jal ObstacleMove
        bge $s6, 2, LoopDAODone         
        addi $t2, $t2, 4      # Move to the next position of the obstacle
        addi $s6, $s6, 1      # $s6++
        j LoopDAO
LoopDAODone:        
        addi $t2, $t2, -8     # restore the original addr of $t2
        
        # pop
        lw $ra, 0($sp)
        addi $sp, $sp, 4      # Jump back to GameStartEnd
        lw $s6, 0($sp)
        addi $sp, $sp, 4
        lw $s5, 0($sp)
        addi $sp, $sp, 4
        lw $s4, 0($sp)
        addi $sp, $sp, 4
        lw $s3, 0($sp)
        addi $sp, $sp, 4


        jr $ra
        
        
ObstacleMove:
	#beqz $s4, RandomGenerator
        lw $s5, 0($t2)                  # Addr of the curr obstacle
        bgt $s5, 0x1000c100, SetAddrBack

Move:
        # Erase
        lw $s0, 36($t1)
	sw $s0, -0x0f4($s5)
        sw $s0, -0x0f0($s5)
        sw $s0, -0x0ec($s5)
        sw $s0, 0x004($s5)
        sw $s0, 0x008($s5)
        sw $s0, 0x018($s5)
        sw $s0, 0x100($s5)
        sw $s0, 0x11c($s5)
        
        lw $s0, 12($t1)			# $s0 stores the color code of LightGrey
        sw $s0, 0x00c($s5)
        sw $s0, 0x010($s5)
        sw $s0, 0x014($s5)
        sw $s0, 0x104($s5)
        sw $s0, 0x108($s5)
        sw $s0, 0x10c($s5)
        sw $s0, 0x114($s5)
        sw $s0, 0x118($s5)
        sw $s0, 0x200($s5)
        sw $s0, 0x204($s5)
        sw $s0, 0x210($s5)
        sw $s0, 0x214($s5)
        sw $s0, 0x218($s5)
        sw $s0, 0x21c($s5)
        sw $s0, 0x300($s5)
        sw $s0, 0x304($s5)
        sw $s0, 0x30c($s5)
        sw $s0, 0x310($s5)
        sw $s0, 0x314($s5)
        sw $s0, 0x31c($s5)
        sw $s0, 0x400($s5)        
        sw $s0, 0x404($s5)
        sw $s0, 0x408($s5)
        sw $s0, 0x40c($s5)
        sw $s0, 0x410($s5)
        sw $s0, 0x418($s5)
        sw $s0, 0x41c($s5)
        sw $s0, 0x504($s5)
        sw $s0, 0x508($s5)
        sw $s0, 0x50c($s5)
        sw $s0, 0x510($s5)
        sw $s0, 0x514($s5)
        sw $s0, 0x518($s5)
        sw $s0, 0x608($s5)
        sw $s0, 0x60c($s5)
        sw $s0, 0x610($s5)
        sw $s0, 0x110($s5)
        lw $s0, 4($t1)			# $s0 stores the color code of DarkGrey
        sw $s0, 0x208($s5)
        sw $s0, 0x20c($s5)
        sw $s0, 0x308($s5)
        sw $s0, 0x318($s5)
        sw $s0, 0x414($s5)
	
	# Counter for movement
	addi $s5, $s5, 256
	
	sw $s5, 0($t2)
	jr $ra                          # Jump to LoopDAO

SetAddrBack:
	addi $sp, $sp, -4
 	sw $s1, 0($sp)
 	addi $sp, $sp, -4
 	sw $s2, 0($sp) 
 
 	la $s1, buff
 	lw $s2, 16($s1)
 	addi $s2, $s2, 10
 	sw $s2, 16($s1)
 
        lw $s2, 0($sp)
        addi $sp, $sp, 4
 	lw $s1, 0($sp) 
 	addi $sp, $sp, 4
        # Random int generator
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 4			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	addi $a0, $a0, -2               # -2 <= $a0 <= 2
	sll $a0, $a0, 8                 # $a0 * 0x100
	
        subi $s5, $s5, 0x4700           # $s5 = $s5 - 0x4400 ~ 0x4900
        add $s5, $s5, $a0
        
        andi $s5, $s5, 0xffffff00
        #sw $s5, 0($t2)
        
RandomGenerator:
	# Random int generator
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 56			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	#addi $s1, $a0, 0		# $s1 stores the randomized number
	sll $s1, $a0, 2                 # shift left 2, same as * 4
	
	# Store position
	#addi $s1, $s1, 0x10007A00	# $s1 = initial position of obstacle
	#lw $s5, 0($t2)
	add $s5, $s1, $s5
	#addi $s4, $0, 71		# $t5 stores counter for movement
	#addi $s3, $s3, 1               # i++
	
	j Move

CheckHP:
	addi $s1, $0, 0x10008000
	addi $sp, $sp, -4		# saves previous $s1 into the stack
    	sw $s1, 0($sp)
    	beq $t8, 3, FullHP
    	beq $t8, 2, TwoHP
    	beq $t8, 1, OneHP
	j ZeroHP
	
FullHP:
	lw $s0, 24($t1)
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)

	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	addi $s1, $0, 0x10008000
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	jr $ra				
	
TwoHP:
	lw $s0, 24($t1)
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 24($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 36($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	addi $s1, $0, 0x10008000
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	jr $ra			

OneHP:
	lw $s0, 24($t1)
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 36($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 36($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	addi $s1, $0, 0x10008000
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	jr $ra					

ZeroHP:
	lw $s0, 36($t1)
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 36($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	lw $s0, 36($t1)
	addi $s1, $s1, 24
	sw $s0, 264($s1)
	sw $s0, 272($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 524($s1)
	sw $s0, 528($s1)
	sw $s0, 532($s1)
	sw $s0, 776($s1)
	sw $s0, 780($s1)
	sw $s0, 784($s1)
	sw $s0, 1036($s1)
	
	addi $s1, $0, 0x10008000
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	j GameOver	

CheckCollisionAll:
	# push $s1~7 to stack
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp) 
	addi $sp, $sp, -4
	sw $s3, 0($sp)                  # use $s3 to loop over obs, will be restored
	addi $sp, $sp, -4
	sw $s4, 0($sp)
	addi $sp, $sp, -4
	sw $s5, 0($sp)
	addi $sp, $sp, -4
	sw $s6, 0($sp) 
	addi $sp, $sp, -4
	sw $s7, 0($sp)	
	
	la $t2, obspos                  # load the array of addresses of obspos stored in $t2
	addi $s3, $t2, 8
CheckCollisionLoop:
	bgt $t2, $s3, CollisionLoopOver # while $t2 <= $s3(8)
	jal Collision
	addi $t2, $t2, 4
	
	j CheckCollisionLoop

CollisionLoopOver:
	addi $t2, $t2, -12              # restore $t2
	# pop $s7~1 from stack
        lw $s7, 0($sp)
        addi $sp, $sp, 4
	lw $s6, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s5, 0($sp)	
	addi $sp, $sp, 4	
        lw $s4, 0($sp)
        addi $sp, $sp, 4
	lw $s3, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s2, 0($sp)	
	addi $sp, $sp, 4
        lw $s1, 0($sp)
        addi $sp, $sp, 4

	j GameCheckCollisionDone


Collision:    	# obs 7*7 in size, jet 3*6 plus 11*6

	lw $s1, 0($t2)                  # $s1: pos of 1st obstacle
	
	andi $s7, $s1, 0xffffff00       # obs.y (row number)
	sub $s6, $s1, $s7               # obs.x
	andi $s5, $t4, 0xffffff00       # jet.y
	sub $s4, $t4, $s5               # jet.x
	

	
	
CollisionPart1:				# check collision between 7*7 square and 3*6 square	
					# $s6: obs.x
	addi $s2, $s4, 24               # $s2: jet.x (rightmost)
	bgt $s6, $s2, CollisionPart2    # $s6 > $s2 then no collision with the first part of the jet
    	
	addi $s1, $s6, 24               # $s1: obs.x (rightmost)
	addi $s2, $s4, 16               # $s2: jet.x + offset (16)	
	blt $s1, $s2, CollisionPart2    # $s1 < $s2 then no collision
    	
    	# don't need
			                  # $s7: obs.y
	# addi $s2, $s5, 0x600            # $s2: jet.y (bottom) 
	# bgt $s7, $s2, CollisionPart2    # obs.y >= jet.y (bottom)
	
	addi $s1, $s7, 0x600            # $s1: obs.y (bottom)
			                # $s5: jet.y  
	bge $s1, $s5, Collide           # all conditions met, must have collision with jet part1
	# if not, go part2

CollisionPart2:	 			# check collision between 7x7 square and 11x6 square
			                # $s6: obs.x
	addi $s2, $s4, 40           	# $s2: jet.x (leftmost, base addr + 40)
	bgt $s6, $s2, CheckCollisionBeam       # obs.x > jet.x (leftmost)
    	
	addi $s1, $s6, 24               # $s1: obs.x + obs.width (4*7 = 28)
			                # $s4: jet.x	
	blt $s1, $s4, CheckCollisionBeam       # $s1 < $s2 then no collision
    	
			                # $s7: obs.y
	addi $s2, $s5, 0xb00            # $s2: jet.y bottom (11x256= 0xb00) 
	bgt $s7, $s2, CheckCollisionBeam       # obs.y > jet.y + jet.height
	
	addi $s1, $s7, 0x600            # $s1: obs.y bottom (6x256 = 0x600)
	addi $s2, $s5, 0x600            # $s2: jet.y + offset (0x600)
	bge $s1, $s2, Collide           # all conditions met, must have collision with jet part2
	# if not, then no collision

CheckCollisionBeam:
	lw $s2, 4($t6)
	# $s7 obs.y (row number)
	# $s6 obs.x
	#la $s3, buff
	#lw $s3, 0($s3)			# beam lvl
CheckBeam1:
	lw $s1, 0($t6)
	beq $s1, 1, CheckBeam2
	andi $s5, $s1, 0xffffff00       # beam1.y
	sub $s4, $s1, $s5               # beam1.x
	
	blt $s4, $s6, NoCollision
	addi $s2, $s6, 0x24		# $s2 = right edge of the obstacle
	bgt $s4, $s2, NoCollision	# beam at right egde of the obstacle
	addi $s2, $s7, 0x600		# $s2 = bottom of the obstacle
	blt $s1, $s2, CollisionWithBeam1
	j NoCollision
CheckBeam2:
	lw $s1, 4($t6)
	beq $s1, 1, NoCollision
	andi $s5, $s1, 0xffffff00       # beam2.y
	sub $s4, $s1, $s5               # beam2.x
	
	blt $s4, $s6, NoCollision
	addi $s2, $s6, 0x24		# $s2 = right edge of the obstacle
	bgt $s4, $s2, NoCollision	# beam at right egde of the obstacle
	addi $s2, $s7, 0x600		# $s2 = bottom of the obstacle
	blt $s1, $s2, CollisionWithBeam2
	j NoCollision

CollisionWithBeam1:
	lw $s1, 0($t6)
	lw $s0, 36($t1)			# erase
	sw $s0, 0x000($s1)		# position in $t6 updated but havent drawed on screen, 
	sw $s0, 0x100($s1)		# hence add 0x200
	
	addi $s1, $0, 1
	sw $s1, 0($t6)
	j BeamSetObstacleBack
	
CollisionWithBeam2:
	lw $s1, 4($t6)
	lw $s0, 36($t1)			# erase
	sw $s0, 0x000($s1)
	sw $s0, 0x100($s1)
	
	addi $s1, $0, 1
	sw $s1, 4($t6)
	
BeamSetObstacleBack:
	lw $s5, 0($t2)                  # Addr of the curr obstacle
	addi $s5, $s5, -256
        lw $s0, 36($t1)			# $s0 stores the color code of LightGrey
        sw $s0, 0x00c($s5)
        sw $s0, 0x010($s5)
        sw $s0, 0x014($s5)
        sw $s0, 0x104($s5)
        sw $s0, 0x108($s5)
        sw $s0, 0x10c($s5)
        sw $s0, 0x114($s5)
        sw $s0, 0x118($s5)
        sw $s0, 0x200($s5)
        sw $s0, 0x204($s5)
        sw $s0, 0x210($s5)
        sw $s0, 0x214($s5)
        sw $s0, 0x218($s5)
        sw $s0, 0x21c($s5)
        sw $s0, 0x300($s5)
        sw $s0, 0x304($s5)
        sw $s0, 0x30c($s5)
        sw $s0, 0x310($s5)
        sw $s0, 0x314($s5)
        sw $s0, 0x31c($s5)
        sw $s0, 0x400($s5)        
        sw $s0, 0x404($s5)
        sw $s0, 0x408($s5)
        sw $s0, 0x40c($s5)
        sw $s0, 0x410($s5)
        sw $s0, 0x418($s5)
        sw $s0, 0x41c($s5)
        sw $s0, 0x504($s5)
        sw $s0, 0x508($s5)
        sw $s0, 0x50c($s5)
        sw $s0, 0x510($s5)
        sw $s0, 0x514($s5)
        sw $s0, 0x518($s5)
        sw $s0, 0x608($s5)
        sw $s0, 0x60c($s5)
        sw $s0, 0x610($s5)
        sw $s0, 0x110($s5)
        sw $s0, 0x208($s5)
        sw $s0, 0x20c($s5)
        sw $s0, 0x308($s5)
        sw $s0, 0x318($s5)
        sw $s0, 0x414($s5)

	# The same SetAddrBack				
	lw $s4, 0($t2)                  # $s4 stores curr $t2 pos
	
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 3			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	addi $a0, $a0, -3               # -3 <= $a0 <= 0
	sll $a0, $a0, 8                 # $a0 * 0x100
        addi $s4, $t0, -0x700           # $s4 = base addr - 0x700
        add $s4, $s4, $a0
        # set random x
        li $a0, 0       		# Select random generator 0
	li $a1, 56			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sll $s1, $a0, 2                 # shift left 2, same as * 4
	add $s4, $s1, $s4
        sw $s4, 0($t2)
        
	#Collide add score
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp) 
	
	la $s1, buff
	lw $s2, 16($s1)
	addi $s2, $s2, 50
	sw $s2, 16($s1)
	
        lw $s2, 0($sp)
        addi $sp, $sp, 4
	lw $s1, 0($sp)	
	addi $sp, $sp, 4
        
        jr $ra

NoCollision:    
	jr $ra 
	
Collide:	# effects to be added
	addi $sp, $sp, -4		# push previous $ra into stack
	sw $ra, 0($sp)                  # This $ra is used to jump back to CheckCollisionLoop
	addi $t8, $t8, -1		# -1 HP for 1 collision
	
	lw $s5, 0($t2)                  # Addr of the curr obstacle
	addi $s5, $s5, -256
        lw $s0, 36($t1)			# $s0 stores the color code of LightGrey
        sw $s0, 0x00c($s5)
        sw $s0, 0x010($s5)
        sw $s0, 0x014($s5)
        sw $s0, 0x104($s5)
        sw $s0, 0x108($s5)
        sw $s0, 0x10c($s5)
        sw $s0, 0x114($s5)
        sw $s0, 0x118($s5)
        sw $s0, 0x200($s5)
        sw $s0, 0x204($s5)
        sw $s0, 0x210($s5)
        sw $s0, 0x214($s5)
        sw $s0, 0x218($s5)
        sw $s0, 0x21c($s5)
        sw $s0, 0x300($s5)
        sw $s0, 0x304($s5)
        sw $s0, 0x30c($s5)
        sw $s0, 0x310($s5)
        sw $s0, 0x314($s5)
        sw $s0, 0x31c($s5)
        sw $s0, 0x400($s5)        
        sw $s0, 0x404($s5)
        sw $s0, 0x408($s5)
        sw $s0, 0x40c($s5)
        sw $s0, 0x410($s5)
        sw $s0, 0x418($s5)
        sw $s0, 0x41c($s5)
        sw $s0, 0x504($s5)
        sw $s0, 0x508($s5)
        sw $s0, 0x50c($s5)
        sw $s0, 0x510($s5)
        sw $s0, 0x514($s5)
        sw $s0, 0x518($s5)
        sw $s0, 0x608($s5)
        sw $s0, 0x60c($s5)
        sw $s0, 0x610($s5)
        sw $s0, 0x110($s5)
        sw $s0, 0x208($s5)
        sw $s0, 0x20c($s5)
        sw $s0, 0x308($s5)
        sw $s0, 0x318($s5)
        sw $s0, 0x414($s5)

	# The same SetAddrBack				
	lw $s4, 0($t2)                  # $s4 stores curr $t2 pos
	
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 3			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	addi $a0, $a0, -3               # -3 <= $a0 <= 0
	sll $a0, $a0, 8                 # $a0 * 0x100
        addi $s4, $t0, -0x700           # $s4 = base addr - 0x700
        add $s4, $s4, $a0
        # set random x
        li $a0, 0       		# Select random generator 0
	li $a1, 56			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sll $s1, $a0, 2                 # shift left 2, same as * 4
	add $s4, $s1, $s4
        sw $s4, 0($t2)

	lw $ra, 0($sp)
        addi $sp, $sp, 4                # pop $ra from stack that take us back to CheckCollisionLoop
        
        jr $ra          
        

PickUpCollision:
	# push $s1~7 to stack
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp) 
	addi $sp, $sp, -4
	sw $s3, 0($sp)			# use $s3 to loop over obs, will be restored
	addi $sp, $sp, -4
	sw $s4, 0($sp)
	addi $sp, $sp, -4
	sw $s5, 0($sp)
	addi $sp, $sp, -4
	sw $s6, 0($sp) 
	addi $sp, $sp, -4
	sw $s7, 0($sp)	

	lw $s1, 0($t7)			# $s1: pos of pickup
	andi $s7, $s1, 0xffffff00	# pu.y (row number)
	sub $s6, $s1, $s7		# pu.x
	andi $s5, $t4, 0xffffff00	# jet.y
	sub $s4, $t4, $s5		# jet.x	 
	 
PUCollisionPart1:	# check collision between 5*5 square and 3*6 square	
					# $s6: pu.x
	addi $s2, $s4, 24		# $s2: jet.x (rightmost)
	bgt $s6, $s2, PUCollisionPart2	# $s6 > $s2 then no collision with the first part of the jet
    	
	addi $s1, $s6, 16		# $s1: pu.x (rightmost)
	addi $s2, $s4, 16		# $s2: jet.x + offset (16)	
	blt $s1, $s2, PUCollisionPart2	# $s1 < $s2 then no collision
    	
    	# don't need
					# $s7: pu.y
	# addi $s2, $s5, 0x600		# $s2: jet.y (bottom) 
	# bgt $s7, $s2, CollisionPart2	# obs.y >= jet.y (bottom)
	
	addi $s1, $s7, 0x400		# $s1: pu.y (bottom)
					# $s5: jet.y  
	bge $s1, $s5, PUObtained	# all conditions met, must have collision with jet part1
	# if not, go part2

PUCollisionPart2:	# check collision between 7x7 square and 11x6 square
					# $s6: pu.x
	addi $s2, $s4, 40		# $s2: jet.x (leftmost, base addr + 40)
	bgt $s6, $s2, CollisionPUEnd	# obs.x > jet.x (leftmost)
    	
	addi $s1, $s6, 16               # $s1: pu.x + pu.width (4*5 = 20)
			                # $s4: jet.x	
	blt $s1, $s4, CollisionPUEnd	# $s1 < $s2 then no collision
    	
			                # $s7: pu.y
	addi $s2, $s5, 0xb00            # $s2: jet.y bottom (11x256= 0xb00) 
	bgt $s7, $s2, CollisionPUEnd	# obs.y > jet.y + jet.height
	
	addi $s1, $s7, 0x400		# $s1: pu.y bottom (4x256 = 0x400)
	addi $s2, $s5, 0x600		# $s2: jet.y + offset (0x600)
	bge $s1, $s2, PUObtained	# all conditions met, must have collision with jet part2  
	j CollisionPUEnd  

PUObtained:
	lw $s2, 0($t7)
	addi $s2, $s2, -256		# erase next line
	lw $s0, 36($t1)
	
	sw $s0, 0($s2)
	sw $s0, 4($s2)
	sw $s0, 8($s2)
	sw $s0, 12($s2)
	sw $s0, 16($s2)
	
	sw $s0, 256($s2)
	sw $s0, 260($s2)
	sw $s0, 264($s2)
	sw $s0, 268($s2)
	sw $s0, 272($s2)
	
	sw $s0, 512($s2)
	sw $s0, 516($s2)
	sw $s0, 520($s2)
	sw $s0, 524($s2)
	sw $s0, 528($s2)
	
	sw $s0, 768($s2)
	sw $s0, 772($s2)
	sw $s0, 776($s2)
	sw $s0, 780($s2)
	sw $s0, 784($s2)
	
	sw $s0, 1024($s2)
	sw $s0, 1028($s2)
	sw $s0, 1032($s2)
	sw $s0, 1036($s2)
	sw $s0, 1040($s2)
	
	add $s2, $0, $0
	sw $s2, 0($t7)
	lw $s7, 4($t7)
	
	addi $sp, $sp, -4  # save previous $s4
	sw $s4, 0($sp)
	addi $sp, $sp, -4  # save previous $s5
	sw $s5, 0($sp)
	la $s4, buff

	beq $s7, 0, PUHP
	beq $s7, 1, PUJS
	beq $s7, 2, PUSc
	beq $s7, 3, PUBS
	beq $s7, 4, PUBA
	beq $s7, 5, PUSl
 
PUHP:
	beq $t8, 3, CollisionPUEnd
	addi $t8, $t8, 1
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd

PUJS:
	lw $s5, 8($s4)
	#beq $s5, 2, CollisionPUEnd
	addi $s5, $0, 700
	sw $s5, 8($s4)
 
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd

PUSc:
	lw $s5, 16($s4)
	addi $s5, $s5, 200
	sw $s5, 16($s4)
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd
 
PUBS:
	lw $s5, 0($s4)
	#beq $s5, 1, CollisionPUEnd
	addi $s5, $0, 600
	sw $s5, 0($s4)
	
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd
	
PUBA:
	lw $s5, 4($s4)
	#beq $s5, 120, CollisionPUEnd
	addi $s5, $0, 600
	sw $s5, 4($s4)
	
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd
	
PUSl:
	lw $s5, 12($s4)
	#beq $s5, 0, CollisionPUEnd
	addi $s5, $0, 600
	sw $s5, 12($s4)
	lw $s5, 0($sp)
	addi $sp, $sp, 4
	lw $s4, 0($sp)
        addi $sp, $sp, 4
	j CollisionPUEnd 
	
CollisionPUEnd:
	# pop $s7~1 from stack
        lw $s7, 0($sp)
        addi $sp, $sp, 4
	lw $s6, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s5, 0($sp)	
	addi $sp, $sp, 4	
        lw $s4, 0($sp)
        addi $sp, $sp, 4
	lw $s3, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s2, 0($sp)	
	addi $sp, $sp, 4
        lw $s1, 0($sp)
        addi $sp, $sp, 4
        
	j GamePickUpCollisionDone

BuffUpdater:	# update buff duration and show buff status 
	# BeamSpeed-up, Beam lvl, Jet Speed-up, Obstacle Slow, Score
	
	addi $sp, $sp, -4  # save previous $s4
	sw $s4, 0($sp)
	addi $sp, $sp, -4  # save previous $s5
	sw $s5, 0($sp)
	
	la $s4, buff
	
UpdateBSDuration:
	lw $s5, 0($s4)
	ble $s5, 0, EraseBS
	jal BuffFlash
	beq $v1, 5, UpdateBeforeEraseBS
	# if $s5 > 0
	# Display buff
	lw $s0, 20($t1)
	sw $s0, 0x3c1c($t0)
	sw $s0, 0x3b20($t0)
	sw $s0, 0x3c24($t0)
	lw $s0, 28($t1)
	sw $s0, 0x3b1c($t0)
	sw $s0, 0x3a20($t0)
	sw $s0, 0x3b24($t0)
	
	addi $s5, $s5, -1	# Update buff duration
	sw $s5, 0($s4)
	j UpdateBADuration
UpdateBeforeEraseBS:
	addi $s5, $s5, -1	# Update buff duration
	sw $s5, 0($s4)	
EraseBS:	
	lw $s0, 36($t1)
	sw $s0, 0x3c1c($t0)
	sw $s0, 0x3b20($t0)
	sw $s0, 0x3c24($t0)
	sw $s0, 0x3b1c($t0)
	sw $s0, 0x3a20($t0)
	sw $s0, 0x3b24($t0)
	
UpdateBADuration:	
	lw $s5, 4($s4)
	ble $s5, 0, EraseBA		
	# $s5 > 0
	addi $s5, $s5, -1
	sw $s5, 4($s4)
	j UpdateJSDuration
EraseBA:
	lw $s5, 4($t6)			# pos of second beam
	beq $s5, 1, UpdateJSDuration	# if $s5 == 1, do not erase second beam
	lw $s0, 36($t1)
	sw $s0, 0($s5)			# Erase the old second beam displayed on screen
	sw $s0, 0x100($s5)
	addi $s5, $0, 1
	lw $s0, 36($t1)
	sw $s0, 0x3710($t0)
	sw $s0, 0x380c($t0)
	sw $s0, 0x3814($t0)
	sw $s0, 0x3610($t0)
	sw $s0, 0x370c($t0)
	sw $s0, 0x3714($t0)	
	sw $s5, 4($t6)			# Set second beam pos to 1
	
UpdateJSDuration:	
	lw $s5, 8($s4)
	ble $s5, 0, EraseJS
	jal BuffFlash
	beq $v1, 5, UpdateBeforeEraseJS
	lw $s0, 0($t1)
	sw $s0, 0x3c2c($t0)
	sw $s0, 0x3b30($t0)
	sw $s0, 0x3c34($t0)
	lw $s0, 40($t1)
	sw $s0, 0x3b2c($t0)
	sw $s0, 0x3a30($t0)
	sw $s0, 0x3b34($t0)
	addi $s5, $s5, -1
	sw $s5, 8($s4)
	j UpdateBuffEnd
UpdateBeforeEraseJS:
	addi $s5, $s5, -1
	sw $s5, 8($s4)		
EraseJS:
	lw $s0, 36($t1)
	sw $s0, 0x3c2c($t0)
	sw $s0, 0x3b30($t0)
	sw $s0, 0x3c34($t0)
	sw $s0, 0x3b2c($t0)
	sw $s0, 0x3a30($t0)
	sw $s0, 0x3b34($t0)

UpdateSlow:
	lw $s5, 12($s4)
	ble $s5, 0, UpdateBuffEnd
	addi $s5, $s5, -1
	sw $s5, 12($s4)
	# j UpdateJSDuration
	
UpdateBuffEnd:
	lw $s5, 0($sp)	
	addi $sp, $sp, 4	
        lw $s4, 0($sp)
        addi $sp, $sp, 4
        add $v1, $0, $0
	j BuffUpdated

BuffFlash:		# $s5 has the value of curr buff, $v1 indicates whether buff should be black
	addi $sp, $sp, -4			# save previous $s5
	sw $s6, 0($sp)
	bgt $s5, 100, BuffFlashEnd
	# $s5 <= 100,  buff 3 seconds remaining
	andi $s6, $s5, 0x0000000f		# Last 4 bits
	blt $s6, 8, BuffFlashEnd		# 8 = 0b1000
	# 15 > $s6 >= 8
	addi $v1, $0, 5
BuffFlashEnd:
        lw $s6, 0($sp)
        addi $sp, $sp, 4
        
        jr $ra           
                                                        
StartScreen:			  # Display the start screen
	addi $t0, $t0, 0xc00      # $t0 stores the addr of the first line of the title scrren (can be overwritten later)
	lw $s0, 0($a0)		  # $s0 stores the color code of White
       
	sw $s0, 0x048($t0)        # line1     
      	sw $s0, 0x04c($t0)
      	sw $s0, 0x050($t0)
       	sw $s0, 0x14c($t0)        # line2
        sw $s0, 0x150($t0)
        sw $s0, 0x24c($t0)        # line3
        sw $s0, 0x250($t0)
        sw $s0, 0x34c($t0)        # line3
        sw $s0, 0x350($t0)
        sw $s0, 0x444($t0)        # line5
        sw $s0, 0x44c($t0)      
        sw $s0, 0x450($t0)
        sw $s0, 0x548($t0)        # line6
        sw $s0, 0x54c($t0)
        
        # E
        sw $s0, 0x058($t0)        # line1
        sw $s0, 0x05c($t0)
        sw $s0, 0x060($t0)
        sw $s0, 0x064($t0)
        sw $s0, 0x068($t0)
        sw $s0, 0x158($t0)        # line2
        sw $s0, 0x15c($t0)
        sw $s0, 0x258($t0)        # line3
        sw $s0, 0x25c($t0)
        sw $s0, 0x358($t0)        # line4
        sw $s0, 0x35c($t0)
        sw $s0, 0x360($t0)
        sw $s0, 0x364($t0)
        sw $s0, 0x458($t0)        # line5
        sw $s0, 0x45c($t0) 
       	sw $s0, 0x558($t0)        # line6
       	sw $s0, 0x55c($t0)
       	sw $s0, 0x560($t0)
       	sw $s0, 0x564($t0)
       	sw $s0, 0x568($t0)
       	
        # T
        sw $s0, 0x070($t0)        # line1
        sw $s0, 0x074($t0)
        sw $s0, 0x078($t0)
        sw $s0, 0x07c($t0)
        sw $s0, 0x174($t0)        # line2
        sw $s0, 0x178($t0)
        sw $s0, 0x274($t0)        # line3
        sw $s0, 0x278($t0)
        sw $s0, 0x374($t0)        # line4
        sw $s0, 0x378($t0)
        sw $s0, 0x474($t0)        # line5
        sw $s0, 0x478($t0)
        sw $s0, 0x574($t0)        # line6
        sw $s0, 0x578($t0)
        
        # 4 spaces
        # Y
        sw $s0, 0x090($t0)        # line1
        sw $s0, 0x094($t0)
        sw $s0, 0x0a0($t0)
        sw $s0, 0x190($t0)        # line2
        sw $s0, 0x194($t0)
        sw $s0, 0x1a0($t0)
        sw $s0, 0x290($t0)        # line3
        sw $s0, 0x294($t0)
        sw $s0, 0x2a0($t0)
        sw $s0, 0x394($t0)        # line4
        sw $s0, 0x398($t0)
        sw $s0, 0x39c($t0)
        sw $s0, 0x3a0($t0)
        sw $s0, 0x4a0($t0)        # line5
        sw $s0, 0x594($t0)        # line6
        sw $s0, 0x598($t0)
        sw $s0, 0x59c($t0)
        
        # Z  
	sw $s0, 0x0a8($t0)        # line1
	sw $s0, 0x0ac($t0)
	sw $s0, 0x0b0($t0)
	sw $s0, 0x0b4($t0)
	sw $s0, 0x0b8($t0)
	sw $s0, 0x1b4($t0)        # line2
	sw $s0, 0x1b8($t0)
	sw $s0, 0x2b0($t0)        # line3
	sw $s0, 0x2b4($t0)
	sw $s0, 0x2b8($t0)
	sw $s0, 0x3ac($t0)        # line4
	sw $s0, 0x3b0($t0)
	sw $s0, 0x3b4($t0)
	sw $s0, 0x4a8($t0)        # line5
	sw $s0, 0x4ac($t0)
	sw $s0, 0x4b0($t0)
	sw $s0, 0x5a8($t0)        # line6
	sw $s0, 0x5ac($t0)
	sw $s0, 0x5b0($t0)
	sw $s0, 0x5b4($t0)
	sw $s0, 0x5b8($t0)
	
	addi $t0, $0, 0x10008000	# Reset base address 
	    
    # Create Bar take a function argument $a1 (preset with $a0)
    # Add a bar under the title
CreateBar:
    # Save previous value of $s0 and $s1 to the stack
    addi $sp, $sp, -4
    sw $s0, 0($sp)
    addi $sp, $sp, -4
    sw $s1, 0($sp)
      	  	
    addi $s1, $t0, 0x1420
    addi $s2, $s1, 0x00c0 
    lw $s0, 0($a1)                      # $s0 has color of $a1
        
InnerLoop:	
    bge $s1, $s2, Reset_data    
    sw $s0, 0($s1)
    addi $s1, $s1, 4                    # update the position of $s1
    j InnerLoop
            
Reset_data:    	
    add $a0, $0, $0			# Reset $a0
    add $a1, $0, $0			# Reset $a1
    
    # Recover $s0 and $s1 from the stack
    lw $s0, 0($sp)
    addi $sp, $sp, 4
    lw $s1, 0($sp)
    addi $sp, $sp, 4
    
    jr $ra

PickUpMovement:
	addi $sp, $sp, -4		# saves previous $s1 into the stack
    	sw $s1, 0($sp)			# $s1 stores pickup number, 0:PickUpHP, 1:PickUpJS, 2:PickUpScore
    	addi $sp, $sp, -4		# saves previous $s2 into the stack
    	sw $s2, 0($sp)			# $s2 stores pickup address
	addi $sp, $sp, -4		# saves previous $s3 into the stack
    	sw $s3, 0($sp)			# $s3 stores counter for movement
    	
    	la $t7, PickUpAttr
    	lw $s1, 4($t7)			# $s1 stores the pickup number
    	lw $s2, 0($t7)			# $s2 stores the pos
    	lw $s3, 8($t7)
    	
    	beqz, $s2, UpdateCounter	# $s2 set to 0 when reached by jet and counter is not 0 yet         
    	beq $s1, 0, PickUpHP
	beq $s1, 1, PickUpJS
	beq $s1, 2, PickUpScore
	beq $s1, 3, PickUpBS
	beq $s1, 4, PickUpBA
	beq $s1, 5, PickUpSlow

    	
PickUpHP:
	lw $s0, 24($t1)
	sw $s0, 0($s2)
	sw $s0, 4($s2)
	sw $s0, 8($s2)
	sw $s0, 12($s2)
	sw $s0, 16($s2)
	
	sw $s0, 256($s2)
	sw $s0, 260($s2)
	sw $s0, 268($s2)
	sw $s0, 272($s2)
	
	sw $s0, 512($s2)
	sw $s0, 528($s2)
	
	sw $s0, 768($s2)
	sw $s0, 772($s2)
	sw $s0, 780($s2)
	sw $s0, 784($s2)
	
	sw $s0, 1024($s2)
	sw $s0, 1028($s2)
	sw $s0, 1032($s2)
	sw $s0, 1036($s2)
	sw $s0, 1040($s2)
	
	lw $s0, 16($t1)
	sw $s0, 264($s2)
	sw $s0, 516($s2)
	sw $s0, 520($s2)
	sw $s0, 524($s2)
	sw $s0, 776($s2)

	j MovePickUp
		
PickUpJS:
       	lw $s0, 36($t1)
	sw $s0, 12($s2)
	sw $s0, 16($s2)
	sw $s0, 256($s2)
	sw $s0, 272($s2)
	sw $s0, 512($s2)
	sw $s0, 516($s2)
	sw $s0, 768($s2)
	sw $s0, 784($s2)
	sw $s0, 1036($s2)
	sw $s0, 1040($s2)
		

	lw $s0, 40($t1)
	sw $s0, 4($s2)
	sw $s0, 264($s2)
	sw $s0, 524($s2)
	sw $s0, 776($s2)
	sw $s0, 1028($s2)
	sw $s0, 8($s2)
	sw $s0, 268($s2)
	sw $s0, 528($s2)
	sw $s0, 780($s2)
	sw $s0, 1032($s2)
	
	lw $s0, 0($t1)
	sw $s0, 0($s2)
	sw $s0, 260($s2)
	sw $s0, 520($s2)
	sw $s0, 772($s2)
	sw $s0, 1024($s2)
	
	j MovePickUp
	
PickUpScore:
	lw $s0, 48($t1)
	sw $s0, 16($s2)
	sw $s0, 272($s2)
	sw $s0, 528($s2)
	sw $s0, 784($s2)
	sw $s0, 1024($s2)
	sw $s0, 1028($s2)
	sw $s0, 1032($s2)
	sw $s0, 1036($s2)
	sw $s0, 1040($s2)
	
	lw $s0, 44($t1)
	sw $s0, 0($s2)
	sw $s0, 4($s2)
	sw $s0, 8($s2)
	sw $s0, 12($s2)
	sw $s0, 256($s2)
	sw $s0, 260($s2)
	sw $s0, 264($s2)
	sw $s0, 268($s2)
	sw $s0, 512($s2)
	sw $s0, 516($s2)
	sw $s0, 520($s2)
	sw $s0, 524($s2)
	sw $s0, 768($s2)
	sw $s0, 772($s2)
	sw $s0, 776($s2)
	sw $s0, 780($s2)
	
	j MovePickUp

PickUpBS:
	lw $s0, 36($t1)
	sw $s0, 0($s2)
	sw $s0, 4($s2)
	sw $s0, 12($s2)
	sw $s0, 16($s2)
	sw $s0, 256($s2)
	sw $s0, 272($s2)
	sw $s0, 776($s2)
	sw $s0, 1028($s2)
	sw $s0, 1032($s2)
	sw $s0, 1036($s2)
	
	lw $s0, 28($t1)
	sw $s0, 8($s2)
	sw $s0, 260($s2)
	sw $s0, 264($s2)
	sw $s0, 268($s2)
	sw $s0, 512($s2)
	sw $s0, 516($s2)

	sw $s0, 524($s2)
	sw $s0, 528($s2)
	sw $s0, 768($s2)
	sw $s0, 784($s2)
	
	lw $s0, 20($t1)
	sw $s0, 520($s2)
	sw $s0, 772($s2)
	sw $s0, 780($s2)
	sw $s0, 1024($s2)
	sw $s0, 1040($s2)
	
	j MovePickUp

PickUpBA:
	lw $s0, 20($t1)
	sw $s0, 0($s2)
	sw $s0, 4($s2)
	sw $s0, 8($s2)
	sw $s0, 12($s2)
	sw $s0, 16($s2)
	
	sw $s0, 256($s2)
	sw $s0, 260($s2)
	sw $s0, 268($s2)
	sw $s0, 272($s2)
	
	sw $s0, 512($s2)
	sw $s0, 528($s2)
	
	sw $s0, 768($s2)
	sw $s0, 772($s2)
	sw $s0, 780($s2)
	sw $s0, 784($s2)
	
	sw $s0, 1024($s2)
	sw $s0, 1028($s2)
	sw $s0, 1032($s2)
	sw $s0, 1036($s2)
	sw $s0, 1040($s2)
	
	lw $s0, 28($t1)
	sw $s0, 264($s2)
	sw $s0, 516($s2)
	sw $s0, 520($s2)
	sw $s0, 524($s2)
	sw $s0, 776($s2)
	
	j MovePickUp

PickUpSlow:
	lw $s0, 16($t1)
	sw $s0, 0($s2)
	sw $s0, 8($s2)
	sw $s0, 16($s2)
	sw $s0, 260($s2)
	sw $s0, 264($s2)
	sw $s0, 268($s2)
	sw $s0, 512($s2)
	sw $s0, 516($s2)
	sw $s0, 524($s2)
	sw $s0, 528($s2)
	sw $s0, 772($s2)
	sw $s0, 776($s2)
	sw $s0, 780($s2)
	sw $s0, 1024($s2)
	sw $s0, 1032($s2)
	sw $s0, 1040($s2)
	
	lw $s0, 36($t1)
	sw $s0, 4($s2)
	sw $s0, 12($s2)
	sw $s0, 256($s2)
	sw $s0, 272($s2)
	sw $s0, 520($s2)
	sw $s0, 768($s2)
	sw $s0, 784($s2)
	sw $s0, 1028($s2)
	sw $s0, 1036($s2)
	
	j MovePickUp

MovePickUp:
	lw $s0, 36($t1)
	sw $s0, -256($s2)
	sw $s0, -252($s2)
	sw $s0, -248($s2)
	sw $s0, -244($s2)
	sw $s0, -240($s2)
	
	addi $s2, $s2, 256
	sw $s2, 0($t7)
	
UpdateCounter:	
	addi $s3, $s3, -1
	sw $s3, 8($t7)
	# bge $s2, 0x10010000, PickUpGenerator	# Might need to be removed
	beqz $s3, PickUpGenerator
	j EndPickUp

PickUpGenerator:
    	addi $s3, $0, 89
    	sw $s3, 8($t7)
	
	# Random PickUp generator
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 6			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sw $a0, 4($t7)
	
	# Random PickUp address generator
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	li $a1, 60			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sll $s2, $a0, 2			# shift left 2, same as * 4

	addi $s2, $s2, 0x10007C00
	sw $s2, 0($t7)
		
EndPickUp:
	lw $s3, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s3 back
	lw $s2, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s2 back
	lw $s1, 0($sp)	
	addi $sp, $sp, 4		# pops previous $s1 back
	
	j GameCheckPickUpDone
	
RandomLocation:		# upperbound stored in $a1, return value in $v1
	li $v0, 42			# Service 42, random int range
	li $a0, 0       		# Select random generator 0
	# li $a1, 60			# Select upper bound of random number
	syscall            		# Generate random int (returns in $a0)
	sll $v1, $a0, 2			# shift left 2, same as * 4
	jr $ra

ScoreStart:
	# push $s1~7 to stack
	addi $sp, $sp, -4
	sw $s1, 0($sp)
	addi $sp, $sp, -4
	sw $s2, 0($sp) 
	addi $sp, $sp, -4
	sw $s3, 0($sp)			
	addi $sp, $sp, -4
	sw $s4, 0($sp)
	addi $sp, $sp, -4
	sw $s5, 0($sp)
	addi $sp, $sp, -4
	sw $s6, 0($sp) 
	addi $sp, $sp, -4
	sw $s7, 0($sp)	
	
	addi $s1, $t0, 512	# Initialize the address of the score to be the top right corner
	
	la $s2, buff		# Load buff
	lw $s3, 16($s2)		# Get score
	beqz $s3, ScoreStartZero
	
	addi $s4, $0, 10 	# Use 10 to get the digits of score
	addi $s7, $0, 1		# use $s7 to flag EraseNum
	j CalcScore
	
ScoreStartZero:
	addi $s1, $s1, -16
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j ScoreEnd

CalcScore:
	beqz $s3, ScoreEnd
	div $s3, $s4
	mfhi $s5		# $s5 = hi
	mflo $s6		# $s6 = lo
	addi $s3, $s6, 0
	bgez $s6, ScoreShift
	j DrawScore

ScoreShift:
	sub $s1, $s1, 16
	addi $s7, $0, 1

DrawScore:
	beq $s7, 1, EraseNum
	beq $s5, 0, Zero
	beq $s5, 1, One
	beq $s5, 2, Two
	beq $s5, 3, Three
	beq $s5, 4, Four
	beq $s5, 5, Five
	beq $s5, 6, Six
	beq $s5, 7, Seven
	beq $s5, 8, Eight
	beq $s5, 9, Nine
	
Zero:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
One:
	lw $s0, 16($t1)
	sw $s0, 4($s1)
	sw $s0, 260($s1)
	sw $s0, 516($s1)
	sw $s0, 772($s1)
	sw $s0, 1028($s1)
	j CalcScore
	
Two:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Three:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Four:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 776($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Five:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Six:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Seven:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 264($s1)
	sw $s0, 520($s1)
	sw $s0, 776($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Eight:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore
	
Nine:
	lw $s0, 16($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	j CalcScore

EraseNum:
	lw $s0, 36($t1)
	sw $s0, 0($s1)
	sw $s0, 4($s1)
	sw $s0, 8($s1)
	sw $s0, 256($s1)
	sw $s0, 260($s1)
	sw $s0, 264($s1)
	sw $s0, 512($s1)
	sw $s0, 516($s1)
	sw $s0, 520($s1)
	sw $s0, 768($s1)
	sw $s0, 772($s1)
	sw $s0, 776($s1)
	sw $s0, 1024($s1)
	sw $s0, 1028($s1)
	sw $s0, 1032($s1)
	addi $s7, $0, 0
	j DrawScore

ScoreEnd:
	# pop $s7~1 from stack
        lw $s7, 0($sp)
        addi $sp, $sp, 4
	lw $s6, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s5, 0($sp)	
	addi $sp, $sp, 4	
        lw $s4, 0($sp)
        addi $sp, $sp, 4
	lw $s3, 0($sp)	
	addi $sp, $sp, 4		       	
	lw $s2, 0($sp)	
	addi $sp, $sp, 4
        lw $s1, 0($sp)
        addi $sp, $sp, 4
	jr $ra
            
GameOver:

	lw $s0, 24($t1)			# $s0 stores the color code of Dark Red
	sw $s0, 8192($t0)
	sw $s0, 8196($t0)
	sw $s0, 8440($t0)
	sw $s0, 8444($t0)
	
	# W
	sw $s0, 7204($t0)
	sw $s0, 7208($t0)
	sw $s0, 7224($t0)
	
	sw $s0, 7460($t0)
	sw $s0, 7464($t0)
	sw $s0, 7480($t0)
	
	sw $s0, 7716($t0)
	sw $s0, 7720($t0)
	sw $s0, 7736($t0)
	
	sw $s0, 7972($t0)
	sw $s0, 7976($t0)
	sw $s0, 7992($t0)
	
	sw $s0, 8228($t0)
	sw $s0, 8232($t0)
	sw $s0, 8248($t0)
	
	sw $s0, 8484($t0)
	sw $s0, 8488($t0)
	sw $s0, 8496($t0)
	sw $s0, 8504($t0)
	
	sw $s0, 8740($t0)
	sw $s0, 8744($t0)
	sw $s0, 8748($t0)
	sw $s0, 8756($t0)
	sw $s0, 8760($t0)
	
	sw $s0, 8996($t0)
	sw $s0, 9000($t0)
	sw $s0, 9016($t0)
	
	# A
	sw $s0, 7240($t0)
	sw $s0, 7244($t0)
	sw $s0, 7248($t0)
	sw $s0, 7252($t0)
	sw $s0, 7256($t0)
	
	sw $s0, 7492($t0)
	sw $s0, 7496($t0)
	sw $s0, 7512($t0)
	
	sw $s0, 7748($t0)
	sw $s0, 7752($t0)
	sw $s0, 7768($t0)
	
	sw $s0, 8004($t0)
	sw $s0, 8008($t0)
	sw $s0, 8024($t0)
	
	sw $s0, 8260($t0)
	sw $s0, 8264($t0)
	sw $s0, 8280($t0)
	
	sw $s0, 8516($t0)
	sw $s0, 8520($t0)
	sw $s0, 8524($t0)
	sw $s0, 8528($t0)
	sw $s0, 8532($t0)
	sw $s0, 8536($t0)
	
	sw $s0, 8772($t0)
	sw $s0, 8776($t0)
	sw $s0, 8792($t0)
	
	sw $s0, 9028($t0)
	sw $s0, 9032($t0)
	sw $s0, 9048($t0)
	
	# S
	sw $s0, 7272($t0)
	sw $s0, 7276($t0)
	sw $s0, 7280($t0)
	sw $s0, 7284($t0)
	sw $s0, 7288($t0)
	
	sw $s0, 7524($t0)
	sw $s0, 7528($t0)
	sw $s0, 7532($t0)
	
	sw $s0, 7780($t0)
	sw $s0, 7784($t0)
	sw $s0, 7788($t0)
	
	sw $s0, 8040($t0)
	sw $s0, 8044($t0)
	sw $s0, 8048($t0)
	
	sw $s0, 8300($t0)
	sw $s0, 8304($t0)
	sw $s0, 8308($t0)
	
	sw $s0, 8560($t0)
	sw $s0, 8564($t0)
	sw $s0, 8568($t0)
	
	sw $s0, 8816($t0)
	sw $s0, 8820($t0)
	sw $s0, 8824($t0)
	
	sw $s0, 9060($t0)
	sw $s0, 9064($t0)
	sw $s0, 9068($t0)
	sw $s0, 9072($t0)
	sw $s0, 9076($t0)
	
	# T
	sw $s0, 7300($t0)
	sw $s0, 7304($t0)
	sw $s0, 7308($t0)
	sw $s0, 7312($t0)
	sw $s0, 7316($t0)
	sw $s0, 7320($t0)
	
	sw $s0, 7308($t0)
	sw $s0, 7312($t0)
	sw $s0, 7564($t0)
	sw $s0, 7568($t0)
	sw $s0, 7820($t0)
	sw $s0, 7824($t0)
	sw $s0, 8076($t0)
	sw $s0, 8080($t0)
	sw $s0, 8332($t0)
	sw $s0, 8336($t0)
	sw $s0, 8588($t0)
	sw $s0, 8592($t0)
	sw $s0, 8844($t0)
	sw $s0, 8848($t0)
	sw $s0, 9100($t0)
	sw $s0, 9104($t0)

	# E
	sw $s0, 7332($t0)
	sw $s0, 7336($t0)
	sw $s0, 7340($t0)
	sw $s0, 7344($t0)
	sw $s0, 7348($t0)
	sw $s0, 7352($t0)
	
	sw $s0, 7588($t0)
	sw $s0, 7592($t0)
	
	sw $s0, 7844($t0)
	sw $s0, 7848($t0)
	
	sw $s0, 8100($t0)
	sw $s0, 8104($t0)
	
	sw $s0, 8356($t0)
	sw $s0, 8360($t0)
	sw $s0, 8364($t0)
	sw $s0, 8368($t0)
	sw $s0, 8372($t0)
	
	sw $s0, 8612($t0)
	sw $s0, 8616($t0)
	
	sw $s0, 8868($t0)
	sw $s0, 8872($t0)
	
	sw $s0, 9124($t0)
	sw $s0, 9128($t0)
	sw $s0, 9132($t0)
	sw $s0, 9136($t0)
	sw $s0, 9140($t0)
	sw $s0, 9144($t0)
	
	# D
	sw $s0, 7364($t0)
	sw $s0, 7368($t0)
	sw $s0, 7372($t0)
	sw $s0, 7376($t0)
	sw $s0, 7380($t0)
	
	sw $s0, 7620($t0)
	sw $s0, 7624($t0)
	sw $s0, 7640($t0)
	
	sw $s0, 7876($t0)
	sw $s0, 7880($t0)
	sw $s0, 7896($t0)
	
	sw $s0, 8132($t0)
	sw $s0, 8136($t0)
	sw $s0, 8152($t0)
	
	sw $s0, 8388($t0)
	sw $s0, 8392($t0)
	sw $s0, 8408($t0)
	
	sw $s0, 8644($t0)
	sw $s0, 8648($t0)
	sw $s0, 8664($t0)
	
	sw $s0, 8900($t0)
	sw $s0, 8904($t0)
	sw $s0, 8920($t0)
	
	sw $s0, 9156($t0)
	sw $s0, 9160($t0)
	sw $s0, 9164($t0)
	sw $s0, 9168($t0)
	sw $s0, 9172($t0)



