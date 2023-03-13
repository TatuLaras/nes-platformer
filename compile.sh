#!/bin/bash

rm main.o
rm main.nes
rm main.map.txt
rm main.labels.txt
rm main.nes.ram.nl
rm main.nes.0.nl
rm main.nes.1.nl
rm main.nes.dbg

echo "Compliling..."
ca65 main.s -g -o main.o

echo "Linking..."
ld65 -o main.nes -C nes.cfg main.o -m main.map.txt -Ln main.labels.txt --dbgfile main.nes.dbg
