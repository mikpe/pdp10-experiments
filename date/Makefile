all:	date.exe date.ini
	kn10-kl date.ini # loads date.exe

date.exe:	date
	pdp10-unknown-elf-elf2boot -o date.exe date

date:	date.o
	pdp10-unknown-elf-ld -Ttext=0x1000 -e _start -o date date.o

date.o:	date.s
	pdp10-unknown-elf-as -o date.o date.s

clean:
	rm -f date.exe date date.o
