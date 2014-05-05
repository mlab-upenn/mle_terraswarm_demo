# Simple Example of MLE+ Simulation with S2Sim #

The example is a reference building provided with EnergyPlus, which is a large hotel in Chicago.  The hotel has 6 floors, 22 zones, complete HVAC system, and its own chiller and boiler.  The idea of this simple example is to connect MLE+ with S2Sim, spin up its simulation to keep up with the system time when it connects to S2Sim, then synchronize its simulation with S2Sim.  This provides the basis for co-simulation of MLE+ and S2Sim.  The experience gained from this example will help implement the final toolbox, (possibly) GUI tool, and the demo.

- The original IDF file is named "RefBldgLargeHotelNew2004_Chicago.idf"
- The IDF is modified to:
  - Comment out the unnecessary details, such as utility cost and tariff
  - Comment out unnecessary output and report variables
  - Add support for external interface so that it can connect to MLE+, in particular the variable `Output:Variable,Whole Building,Facility Total Electric Demand Power` returns the total electric demand of the system (building and HVAC) in Watts. It was verified that this number matched the value returned by the meter `Output:Meter,Electricity:Facility` (in Joules).
  

