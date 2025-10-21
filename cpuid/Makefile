all:	cpuid.exe cpuid.ini
	kn10-kl cpuid.ini # loads cpuid.exe

cpuid.exe:	cpuid
	pdp10-unknown-elf-elf2boot -o cpuid.exe cpuid

cpuid:	cpuid.o
	pdp10-unknown-elf-ld -Ttext=0x1000 -e _start -o cpuid cpuid.o

cpuid.o:	cpuid.s
	pdp10-unknown-elf-as -o cpuid.o cpuid.s

clean:
	rm -f cpuid.exe cpuid cpuid.o
