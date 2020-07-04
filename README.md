# Finer Curves
 
An experimental tool to control GPU clocks using "NVIDIA Inspector" by setting specific clocks on specific GPU temperatures, probably like NVIDIA GPU Boost feature, just that its customizable.   

The goal here was to achieve optimal performance of the GPU while also having extra control over its temperatures when gaming.   

The motivation behind this was due to NVIDIA GPU Boost feature (atleast, the one in Kepler GTX 860M) downclocking super hard when it hits the throttle limits, resulting in crippling performance while gaming which usually results in a bad outcome in any situation.   
# Notice

This can cause crashes / instabilities to occur when the GPU is downclocking itself, but I guess that's more of a graphics card thing (more info: https://forums.anandtech.com/threads/why-you-should-not-use-afterburner-precision-to-overclock-maxwell-kepler.2432430/). Honestly, I find that really weird.   

I can think of some solutions to this, most of them that I haven't tested yet:
> Risky solutions:
- [Not tested] VBIOS Modding.
- [Not tested] Let the tool manage voltages too, but this would require VBIOS Modding to unlock it first on a lot of GPU cards.
> Less risky solutions:
- [Tested - haven't crashed with this yet] Use "Prefer maximum performance" performance management mode to make GPU downclocking to a minimum or stop it altogether. 
- [Not tested] Detect when GPU downclocks itself without external assistance and halt all clock modifications.

# TODO

- Finish writing the GUI for setting curve points.
- Take into account current GPU load and application frames per second into the algorithm?
