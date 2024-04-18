Simple Floating Point Unit in MBF40bits (9-digits Basic) for a Z80 processor in Verilog (still in debugging)  
Only performs addition, subtraction, multiplication and division in floating point.   
Connect to the 8-bit bus,  
generates the wait signal when it tries to be read before it has finished.
  
Addressable version to connect to the Z80's Upper Address Bus (PORT B)  
It also includes a small C program to convert from floating point to MBF and vice versa to help with debugging.
