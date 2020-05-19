RoboticArm is a program for working with the LynxMotion AL5D robotic arm with the SSC-32U interface on a Macintosh.

The program uses SwiftUI, Combine, and SceneKit; so will require Catalina for operation.

It was built using XCode 11.4

#### Important notes
* Note:  You must install the FTDI drivers for this program to talk to the arm.  The link to get the drivers is [here](http://www.ftdichip.com/Drivers/VCP.htm).
* The program is not sandboxed (talking to USB devices directly is discouraged in security models)

#### Working notes
* The port drop-down list selection does not update after program initialization, so a restart will be required if the arm is not plugged in prior to starting the program.
* You do not have to have the SSC-32U powered for the port to appear, just to move the servos.
* If the program is not talking to the arm, you may reset the port connection by re-selecting the port from the drop-down list (even if there is only one port in the list)


#### Additions I am working on...
* Better forward kinematics
* Inverse kenematics


![](RoboticArm.png)