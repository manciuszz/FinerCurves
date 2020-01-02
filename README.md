# Finer Curves
 
An experimental tool to control GPU clocks using "NVIDIA Inspector" by setting specific clocks on specific GPU temperatures, probably like NVIDIA GPU Boost feature, just that its customizable.   

The goal here was to achieve optimal performance of the GPU while also having extra control over its temperatures when gaming.   

The motivation behind this was due to NVIDIA GPU Boost feature (atleast, the one in Kepler GTX 860M) downclocking super hard when it hits the throttle limits, resulting in crippling performance while gaming which usually results in a bad outcome in any situation.   

# TODO

- Take into account current GPU load and application frames per second into the algorithm?
- Write a GUI to set curve points.
