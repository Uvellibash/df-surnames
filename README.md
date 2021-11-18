# Example usage

DFHack's onLoad.init file:
```
repeat -name surnames -time 40 -timeUnits days -command [ surnames -patrilineal -inherit_parents -inherit_spouse -no_output ]
