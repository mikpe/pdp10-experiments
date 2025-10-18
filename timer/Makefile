all:	timer.exe timer.ini
	kn10-kl timer.ini # loads timer.exe

timer.exe:	timer
	pdp10-unknown-elf-elf2boot -o timer.exe timer

timer:	timer.o
	pdp10-unknown-elf-ld -Ttext=0x1000 -e _start -o timer timer.o

timer.o:	timer.s
	pdp10-unknown-elf-as -o timer.o timer.s

clean:
	rm -f timer.exe timer timer.o
