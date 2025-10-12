all:	hello.exe hello.ini
	kn10-kl hello.ini # loads hello.exe

hello.exe:	hello
	pdp10-unknown-elf-elf2boot -o hello.exe hello

hello:	hello.o
	pdp10-unknown-elf-ld -Ttext=0x1000 -e _start -o hello hello.o

hello.o:	hello.s
	pdp10-unknown-elf-as -o hello.o hello.s

clean:
	rm -f hello.exe hello hello.o
