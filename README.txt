# NEXYS4ddr_microphone
# GUENEGO Louis
# ENSEIRB-MATMECA, Electronique 2A, 2020

cons/ => constraints files
src/  => source files
tb/   => test benches
wcfg/ => waveform configuration file

This projet is about acquiring audio with the onboard microphne of 
the NEXYS 4 ddr. The language is VHDL.

there is a top entity (TOP_ENTITY.vhd) where everything is connected 
together. There is also a frequency generator (gest_frec.vhd).

Then there is a acquire section (acq_mic) with fir1.vhd and fir.vhd, which 
decimate the 2.5Mhz PDM signal from the microphne at 39062.5Hz 
(100MHz /40 /64), with an intermediary of 312 500kHz (2.5MHz /8) 
between fir1 and fir2. Fir1 and 2 are lowpass filter that remove the 
high frequency noise of the PDM audio.

Between acq_mic.vhd and mod_out.vhd there is some audio effect filters.

Then there is mod_out, which consist of intfir1.vhd and intfir2 which
are oversampling the audio, in order to regenerate a PDM signal with 
a second order PDM modulator (dsmod2.vhd) to play the audio on the 
onboard audio amplifier of the NEXYS4.

So:

Micro -> acq_mic -> (some effects) -> mod_out -> Phone connector
                          ^
                          |
                          Here: 18bits @39062.5Hz audio sample


To compile the projet with Vivado, the files under src have to be imported
as sources, and the constraint file under cons/ as a constraint.
Then you should generate the bitstream, program your NEXYS4 ddr and you
should hear what the microphone gets.

The project was made with Vivado 2020.2
