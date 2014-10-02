# TerraSwarm Demo September 2014 #

## Buildings ##

### LargeHotel ###

The example is a reference building provided with EnergyPlus, which is a large hotel in Chicago.  The hotel has 6 floors, 22 zones, complete HVAC system, and its own chiller and boiler.

- The original IDF file is named "RefBldgLargeHotelNew2004_Chicago.idf"
- The IDF is modified to:
  - Comment out the unnecessary details, such as utility cost and tariff
  - Comment out unnecessary output and report variables
  - Add support for external interface so that it can connect to MLE+, in particular the variable `Output:Variable,Whole Building,Facility Total Electric Demand Power` returns the total electric demand of the system (building and HVAC) in Watts. It was verified that this number matched the value returned by the meter `Output:Meter,Electricity:Facility` (in Joules).
  
### LargeOffice ###

## Matlab Reference ##

References that are useful for Matlab GUI development of the demo.

- [Improve realtime plotting performance](http://undocumentedmatlab.com/blog/plot-performance)
- [Rotate X-axis tick labels](http://www.mathworks.com/matlabcentral/fileexchange/27812-rotate-x-axis-tick-labels)
