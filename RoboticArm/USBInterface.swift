//
//  USBInterface.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/11/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation
import IOKit
import IOKit.serial

public enum BaudRate : Int {
    case B9600 = 0
    case B38400 = 1
    case B115200 = 2
}

public struct ServoCommand
{
    let servo : Int
    let position : Int
    let speed : Int?
}

public class USBInterface
{
    var serialDeviceList : [String] = []
    var selectedSerialDevice : String = ""
    var baudRate = BaudRate.B9600
    var fileDescriptor : Int32 = -1
    let usbQueue = DispatchQueue(label: "USB communication")


    // Hold the original termios attributes so we can reset them
    var gOriginalTTYAttrs: termios = termios()

    init() {
        var kernResult: kern_return_t
        var serialPortIterator:io_iterator_t = io_iterator_t()
        var serialService: io_object_t

        kernResult = findSerialDevices(&serialPortIterator)
        if (KERN_SUCCESS != kernResult) {
            print("No serial devices were found.")
        }
        
        // Iterate across all serial devices found, remembering those that aren't standard
        repeat {
            serialService = IOIteratorNext(serialPortIterator)
            guard serialService != 0 else { continue }
            
            if let aPath = IORegistryEntryCreateCFProperty(serialService,
                                                           "IOCalloutDevice" as CFString,
                                                           kCFAllocatorDefault, 0).takeUnretainedValue() as? String {
                if (!aPath.contains("cu.SOC") && !aPath.contains("cu.MALS") && !aPath.contains("cu.Bluetooth")) {
                    serialDeviceList.append(aPath)
                }
            }
        
        } while (serialService != 0)
        
        //  If only one serial device found, select it
        if (serialDeviceList.count == 1) {
            selectedSerialDevice = serialDeviceList[0]
        }
    }

    // Returns an iterator across all known serial devices. Caller is responsible for
    // releasing the iterator when iteration is complete.
    func findSerialDevices(_ serialPortIterator: inout io_iterator_t ) -> kern_return_t {
        var kernResult: kern_return_t = KERN_FAILURE
        
        // Serial devices are instances of class IOSerialBSDClient.
        // Create a matching dictionary to find those instances."IOSerialBSDClient"
        let classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        if (classesToMatch.count == 0) { // Not sure about this. IOServiceMatching(kIOSerialBSDServiceValue) could return NULL which would be 0 in Swift but I'm not sure what "as NSMutableDictionary" would do with that. I can't think of how to force IOServiceMatching to fail in order to test this out.
            print("IOServiceMatching returned a NULL dictionary.");
        } else {
            // Look for devices that claim to be serial devices.
            classesToMatch[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes

            // Each serial device object has a property with key
            // kIOSerialBSDTypeKey and a value that is one of kIOSerialBSDAllTypes,
            // kIOSerialBSDModemType, or kIOSerialBSDRS232Type. You can experiment with the
            // matching by changing the last parameter in the above call to CFDictionarySetValue.
        }
        
        // Get an iterator across all matching devices.
        kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &serialPortIterator)
        if (KERN_SUCCESS != kernResult) {
            print("IOServiceGetMatchingServices returned \(kernResult)")
        }

        return kernResult
    }

    //  Open the selected serial device
    func openSelectedDevice()
    {
        var options: termios

        //  Skip if no selected device
        if (selectedSerialDevice == "") { return }
        
        // Open the serial port read/write, with no controlling terminal, and don't wait for a connection.
        // The O_NONBLOCK flag also causes subsequent I/O on the device to be non-blocking.
        // See open(2) <x-man-page://2/open> for details.
        
        let openOptions: FCNTLOptions = [.O_RDWR, .O_NOCTTY, .O_NONBLOCK]
//        let openOptions: FCNTLOptions = []
        fileDescriptor = open(selectedSerialDevice, openOptions.rawValue);
        if (fileDescriptor == -1) {
            print("Error opening port")
            return
        }
       
       // Note that open() follows POSIX semantics: multiple open() calls to the same file will succeed
       // unless the TIOCEXCL ioctl is issued. This will prevent additional opens except by root-owned
       // processes.
       // See tty(4) <x-man-page//4/tty> and ioctl(2) <x-man-page//2/ioctl> for details.
       
       var result = ioctl(fileDescriptor, TIOCEXCL)
       if (result == -1) {
           print("Error setting TIOCEXCL")
       }
       
       // Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
       // See fcntl(2) <x-man-page//2/fcntl> for details.
       
       result = fcntl(fileDescriptor, F_SETFL, 0)
       if (result == -1) {
        print("Error clearing O_NONBLOCK \(selectedSerialDevice) - \(String(describing: strerror(errno)))(\(errno))")
       }
       
       // Get the current options and save them so we can restore the default settings later.
       result = tcgetattr(fileDescriptor, &gOriginalTTYAttrs)
       if (result == -1) {
        print("Error getting attributes \(selectedSerialDevice) - \(String(describing: strerror(errno)))(\(errno))")
       }
       
       // The serial port attributes such as timeouts and baud rate are set by modifying the termios
       // structure and then calling tcsetattr() to cause the changes to take effect. Note that the
       // changes will not become effective without the tcsetattr() call.
       // See tcsetattr(4) <x-man-page://4/tcsetattr> for details.
       
       options = gOriginalTTYAttrs;
       
       // Print the current input and output baud rates.
       // See tcsetattr(4) <x-man-page://4/tcsetattr> for details.
       
       print("Current input baud rate is \(cfgetispeed(&options))")
       print("Current output baud rate is \(cfgetospeed(&options))")
        
        // Set raw input (non-canonical) mode, with reads blocking until either a single character
        // has been received or a one second timeout expires.
        // See tcsetattr(4) <x-man-page://4/tcsetattr> and termios(4) <x-man-page://4/termios> for details.
        
        cfmakeraw(&options)
        //options.c_cc[VMIN] = 0
        //options.c_cc[VTIME] = 10;
        
//        With SSC_IO
//             .PortName = Port      'Port name validity must be handled by calling application
//             .BaudRate = Baudrate
//             .DataBits = 8
//             .Parity = IO.Ports.Parity.None
//             .DiscardNull = False
//             .Handshake = IO.Ports.Handshake.None
//             .ReceivedBytesThreshold = 1
//             .Encoding = System.Text.Encoding.GetEncoding(28591)
//             .Open()
//             Me.mvar_IsOpen = True
//             Return True
//         End With

        // The baud rate and word length can be set as follows:
        switch (baudRate) {
            case .B9600:
                cfsetspeed(&options, 9600);        // Set 9600 baud
            case .B38400:
                cfsetspeed(&options, 38400);        // Set 38400 baud
            case .B115200:
                cfsetspeed(&options, 115200);        // Set 115200 baud
        }
        options.c_cflag |= UInt(CS8)       // Use 8 bit words, no parity, no flow control

        print("Input baud rate changed to \(cfgetispeed(&options))")
        print("Output baud rate changed to \(cfgetospeed(&options))")
        
        // Cause the new options to take effect immediately.
        if (tcsetattr(fileDescriptor, TCSANOW, &options) == -1) {
            print("Error setting attributes")
        }
    }

    //  Close the device.
    func closeSerialPort() {
        //  Verify it is still open
        if (fileDescriptor < 0) { return }
        
        // Block until all written output has been sent from the device.
        // Note that this call is simply passed on to the serial device driver.
        // See tcsendbreak(3) <x-man-page://3/tcsendbreak> for details.
        if (tcdrain(fileDescriptor) == -1) {
            print("Error waiting for drain - \(String(describing: strerror(errno)))(\(errno)).")
        }
        
        // Traditionally it is good practice to reset a serial port back to
        // the state in which you found it. This is why the original termios struct
        // was saved.
        if (tcsetattr(fileDescriptor, TCSANOW, &gOriginalTTYAttrs) == -1) {
            print("Error resetting tty attributes - \(String(describing: strerror(errno)))(\(errno)).\n")
        }
        
        close(fileDescriptor)
        fileDescriptor = -1
    }
    
    func createAndSendCommand(_ positions : [ServoCommand], time : Int?)
    {
        //  Create a data object
        var commandData = Data(capacity: positions.count * 11 + 10)
        
        //  Add each servo position
        for position in positions {
            //  Add the servo number
            commandData.append(0x23)    //  #
            commandData.addInteger(position.servo)
            
            //  Add the servo position
            commandData.append(0x50)    //  P
            commandData.addInteger(position.position)
            
            //  If a speed was specified, add that
            if let speed = position.speed {
                commandData.append(0x53)    //  S
                commandData.addInteger(speed)
            }
        }
        
        //  If a time was specified, add that
        if let t = time {
            commandData.append(0x54)    //  T
            commandData.addInteger(t)
        }
        
        //  Add a carriage return
        commandData.append(0x0D)    //  <cr>
        
        //  Send the command
        writeCommand(commandData)
    }
    
    func getAnalogInputs(_ inputIDs : [Character]) -> [UInt8]?
    {
        //  Create a data object
        var commandData = Data(capacity: inputIDs.count * 2 + 2)
        
        //  Add each request
        for id in inputIDs {
            commandData.append(0x56)    //  V
            commandData.append(id.asciiValue!)    //  analog input ID
        }
        
        //  Add a carriage return
        commandData.append(0x0D)    //  <cr>

        //  Write the command and get the response
        if let response = writeCommandWaitForResponse(commandData, responseSize: inputIDs.count) {
            let array = [UInt8](response)
            return array
        }
        return nil
    }
    
    func writeCommand(_ commandData : Data)
    {
        //  Verify we are connected
        if (fileDescriptor < 0) { return }
        
        //  Send the bytes
        usbQueue.sync {
            commandData.withUnsafeBytes { rawBufferPointer in
                let rawPtr = rawBufferPointer.baseAddress!
                let numBytes = write(fileDescriptor, rawPtr, commandData.count)
                if (numBytes < 0) {
                    print("Error sending command")
                }
            }
        }
    }
    
    func writeCommandWaitForResponse(_ commandData : Data, responseSize: Int) -> Data?
    {
        //  Verify we are connected
        if (fileDescriptor < 0) { return nil }
        
        var data : Data? = nil
        usbQueue.sync {
            //  Send the bytes
            commandData.withUnsafeBytes { rawBufferPointer in
                let rawPtr = rawBufferPointer.baseAddress!
                let numBytes = write(fileDescriptor, rawPtr, commandData.count)
                if (numBytes < 0) {
                    print("Error sending command")
                }
            }
            
            //  Get the response
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: responseSize)
            defer {
                buffer.deallocate()
            }
            let bytesRead = read(fileDescriptor, buffer, responseSize)
            if (bytesRead > 0) {
                data = Data(bytes: buffer, count: bytesRead)
            }
        }

        return data
    }
}

extension Data {
    public mutating func addInteger(_ value : Int)
    {
        //  Handle zero
        if (value == 0) {
            self.append(0x30)    //  0
            return
        }
        
        //  If negative, add the signe
        var mutableValue = value
        if (mutableValue < 0) {
            self.append(0x2D)       //  '-'
            mutableValue *= -1
        }

        //  Get the digits
        var digits : [Int] = []
        while (mutableValue > 0) {
            digits.append(mutableValue % 10)
            mutableValue /= 10
        }
        
        //  Add the digits
        digits = digits.reversed()
        for digit in digits {
            self.append(0x30 + UInt8(digit))
        }
    }
}


struct FCNTLOptions : OptionSet {
    let rawValue: CInt
    init(rawValue: CInt) { self.rawValue = rawValue }
    
//    static let  O_RDONLY        = FCNTLOptions(rawValue: 0x0000)
    static let  O_WRONLY        = FCNTLOptions(rawValue: 0x0001)
    static let  O_RDWR          = FCNTLOptions(rawValue: 0x0002)
    static let  O_ACCMODE       = FCNTLOptions(rawValue: 0x0003)
    static let  O_NONBLOCK      = FCNTLOptions(rawValue: 0x0004)
    static let  O_APPEND        = FCNTLOptions(rawValue: 0x0008)
    static let     O_SHLOCK        = FCNTLOptions(rawValue: 0x0010)        /* open with shared file lock */
    static let     O_EXLOCK        = FCNTLOptions(rawValue: 0x0020)        /* open with exclusive file lock */
    static let     O_ASYNC         = FCNTLOptions(rawValue: 0x0040)        /* signal pgrp when data ready */
    //static let     O_FSYNC     = FCNTLOptions(rawValue: O_SYNC         /* source compatibility: do not use */
    static let  O_NOFOLLOW      = FCNTLOptions(rawValue: 0x0100)        /* don't follow symlinks */
    static let     O_CREAT         = FCNTLOptions(rawValue: 0x0200)        /* create if nonexistant */
    static let     O_TRUNC         = FCNTLOptions(rawValue: 0x0400)        /* truncate to zero length */
    static let     O_EXCL          = FCNTLOptions(rawValue: 0x0800)        /* error if already exists */
    static let    O_EVTONLY       = FCNTLOptions(rawValue: 0x8000)        /* descriptor requested for event notifications only */
    
    static let    O_NOCTTY        = FCNTLOptions(rawValue: 0x20000)        /* don't assign controlling terminal */
    static let  O_DIRECTORY     = FCNTLOptions(rawValue: 0x100000)
    static let  O_SYMLINK       = FCNTLOptions(rawValue: 0x200000)      /* allow open of a symlink */
    static let    O_CLOEXEC       = FCNTLOptions(rawValue: 0x1000000)     /* implicitly set FD_CLOEXEC */
}
