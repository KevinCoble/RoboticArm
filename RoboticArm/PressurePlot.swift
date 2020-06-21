//
//  PressurePlot.swift
//  RoboticArm
//
//  Created by Kevin Coble on 6/4/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Cocoa

public protocol TimePlotDataItem {
    var time: Date { get }
    var value: Double { get }
}

struct PressureReading : TimePlotDataItem {
    let time : Date
    let pressure : Double
    
    var value : Double {
        get { return pressure }
    }
}

public class TimePlot<PlotDataType:TimePlotDataItem> {
    var points : [PlotDataType] = []
    var timeWidth : TimeInterval        //  For now, should be integer seconds
    var minValue : Double
    var maxValue : Double
    let autoScale : Bool
    let logScale : Bool
    public var limitLine: Double?
    public var labelTickLength : CGFloat
    
    init(timeFrame : TimeInterval, autoscale : Bool, _ logarithmic : Bool = false) {
        timeWidth = timeFrame
        self.autoScale = autoscale
        minValue = 0.0
        maxValue = 100.0
        logScale = logarithmic
        labelTickLength = 4.0
    }
     
    func addPoint(_ newPoint : PlotDataType) {
        points.append(newPoint)
    }
    
    func removeOldPoints(startTime: Date) {
        //  Find any old points
        var removeUpTo = -1
        for index in 0..<points.count {
            if (points[index].time < startTime) {
                removeUpTo = index
            }
            else {
                break
            }
        }
        
        //  Remove the points
        if (removeUpTo >= 0) {
            points.removeFirst(removeUpTo+1)
        }
    }
    
    func getAutoScale() {
        //  If no points, leave scale alone
        if (points.count <= 0) { return }
        
        //  Get the range of the data
        var min = Double.infinity
        var max = -Double.infinity
        for point in points {
            let value = point.value
            if (value < min) { min = value }
            if (value > max) { max = value }
        }
        
        var Y : Double
        var Z : Double
        
        //  Set the temporary limit values
        var upper = max
        var lower = min
        
        //  If logarithmic, just round the min and max to the nearest power of 10
        if (logScale) {
            //  Round the upper limit
            if (upper <= 0.0) { upper = 1000.0 }
            Y = log10(upper)
            Z = Double(Int(Y))
            if (Y != Z && Y > 0.0) { Z += 1.0 }
            upper = pow(10.0, Z)
            
            //  round the lower limit
            if (lower <= 0.0) { lower = 0.1}
            Y = log10(lower)
            Z = Double(Int(Y))
            if (Y != Z && Y < 0.0) { Z -= 1.0 }
            lower = pow(10.0, Z)
            
            //  Make sure the limits are not the same
            if (lower == upper) {
                Y = log10(max)
                upper = pow(10.0, Y+1.0)
                lower = pow(10.0, Y-1.0)
            }
            minValue = lower
            maxValue = upper
            return
        }
        
        //  Get the difference between the limits
        var bRoundLimits = true
        var bNegative = false
        while (bRoundLimits) {
            bRoundLimits = false
            let difference = upper - lower
            if (!difference.isFinite) {
                minValue = 0.0
                maxValue = 0.0
                return
            }
            
            //  Calculate the upper limit
            if (upper != 0) {
                //  Convert negatives to positives
                bNegative = false
                if (upper < 0.0) {
                    bNegative = true
                    upper *= -1.0
                }
                //  If the limits match, use value for rounding
                if (difference == 0.0) {
                    Z = Double(Int(log10(upper)))
                    if (Z < 0.0) { Z -= 1.0 }
                    Z -= 1.0
                }
                    //  If the limits don't match, use difference for rounding
                else {
                    Z = Double(Int(log10(difference)))
                }
                //  Get the normalized limit
                Y = upper / pow(10.0, Z)
                //  Make sure we don't round down due to value storage limitations
                let NY = Y + Double.ulpOfOne * 100.0
                if (Int(log10(Y)) != Int(log10(NY))) {
                    Y = NY * 0.1
                    Z += 1.0
                }
                //  Round by integerizing the normalized number
                if (Y != Double(Int(Y))) {
                    Y = Double(Int(Y))
                    if (!bNegative) {
                        Y += 1.0
                    }
                    upper = Y * pow(10.0, Z)
                }
                if (bNegative) { upper *= -1.0 }
            }
            
            //  Calculate the lower limit
            if (lower != 0) {
                //  Convert negatives to positives
                bNegative = false
                if (lower < 0.0) {
                    bNegative = true
                    lower *= -1.0
                }
                //  If the limits match, use value for rounding
                if (difference == 0.0) {
                    Z = Double(Int(log10(lower)))
                    if (Z < 0.0) { Z -= 1.0 }
                    Z -= 1.0
                }
                    //  If the limits don't match, use difference for rounding
                else {
                    Z = Double(Int(log10(difference)))
                }
                //  Get the normalized limit
                Y = lower / pow(10.0, Z)
                //  Make sure we don't round down due to value storage limitations
                let NY = Y + Double.ulpOfOne * 100.0
                if (Int(log10(Y)) != Int(log10(NY))) {
                    Y = NY * 0.1
                    Z += 1.0
                }
                //  Round by integerizing the normalized number
                if (Y != Double(Int(Y))) {
                    Y = Double(Int(Y))
                    if (bNegative) {
                        Y += 1.0
                    }
                    else {
                        if (difference == 0.0) { Y -= 1.0 }
                    }
                    lower = Y * pow(10.0, Z)
                }
                if (bNegative) { lower *= -1.0 }
                
                //  Make sure both are not 0
                if (upper == 0.0 && lower == 0.0) {
                    upper = 1.0;
                    lower = -1.0;
                }
                
                //  If the limits still match offset by a percent each and recalculate
                if (upper == lower) {
                    if (lower > 0.0) {
                        lower *= 0.99
                    }
                    else {
                        lower *= 1.01
                    }
                    if (upper > 0.0) {
                        upper *= 1.01
                    }
                    else {
                        upper *= 0.99
                    }
                    bRoundLimits = true
                }
            }
        }
        
        minValue = lower
        maxValue = upper
    }
    
    func getPlotImage(size: CGSize, endTime : Date) -> CGImage?
    {
        //  Get the label font attributes
        let axisColor = NSColor.blue
        let labelFont = NSFont(name: "Helvetica Neue", size: 10.0)
        let YAxisLabelDecimalDigits = 2
        let labelParaStyle = NSMutableParagraphStyle()
        labelParaStyle.lineSpacing = 0.0
        labelParaStyle.alignment = NSTextAlignment.center
        let labelAttributes : [NSAttributedString.Key : Any] = [
            NSAttributedString.Key.foregroundColor: axisColor,
            NSAttributedString.Key.paragraphStyle: labelParaStyle,
            NSAttributedString.Key.font: labelFont!
        ]

        //  Create the offscreen context
        //  Help from https://stackoverflow.com/questions/10627557/mac-os-x-drawing-into-an-offscreen-nsgraphicscontext-using-cgcontextref-c-funct in updated answer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                       bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        
//        guard let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: 0, bitsPerPixel: 32) else { return nil }
//
        //  If set to autoscale, do so now
        if (autoScale) {
            getAutoScale()
        }
        
        //  Set up the context for text drawing
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext
        
        //  Fill the background color
        context.setFillColor(CGColor.white)
        context.fill(CGRect(origin: CGPoint.zero, size: size))
        
        //  Get the 'current' (time 0) label
        var label = "0"
        var labelSize = label.size(withAttributes: labelAttributes)
        let rightMargin = labelSize.width * 0.5
        let bottomMargin = labelSize.height + labelTickLength
        
        //  Draw the current time label
        var labelRect = CGRect(x: size.width - labelSize.width, y: 0.0, width: labelSize.width, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        context.beginPath()
        context.move(to: CGPoint(x: size.width - rightMargin, y: labelSize.height))
        context.addLine(to: CGPoint(x: size.width - rightMargin, y: bottomMargin))
        context.strokePath()

        //  Get the Y axis label size
        let format = String(format: "%%.%df", YAxisLabelDecimalDigits)
        label = String(format: format, minValue)
        labelSize = label.size(withAttributes: labelAttributes)
        var maxLabelSize = labelSize.width;
        label = String(format: format, maxValue)
        labelSize = label.size(withAttributes: labelAttributes)
        if (labelSize.width > maxLabelSize) { maxLabelSize = labelSize.width }
        let leftMargin = maxLabelSize + labelTickLength
        let topMargin = labelSize.height
        
        //  Draw the time axis line
        context.beginPath()
        context.move(to: CGPoint(x: leftMargin, y: bottomMargin))
        context.addLine(to: CGPoint(x: size.width - rightMargin, y: bottomMargin))
        context.strokePath()
        
        //  Get the oldest time label
        if (timeWidth >= 180.0) {
            //  Put it in units of minutes
            label = String(format: "%.0f", -timeWidth / 60.0)
        }
        else {
            //  Units of seconds
            label = String(format: "%.0f", -timeWidth)
        }
        labelSize = label.size(withAttributes: labelAttributes)
        
        //  Draw the oldest time label
        labelRect = CGRect(x: leftMargin - (labelSize.width * 0.5), y: 0.0, width: labelSize.width, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        context.beginPath()
        context.move(to: CGPoint(x: leftMargin, y: labelSize.height))
        context.addLine(to: CGPoint(x: leftMargin, y: bottomMargin))
        context.strokePath()
        
        //  Draw the Y axis line
        context.beginPath()
        context.move(to: CGPoint(x: leftMargin, y: bottomMargin))
        context.addLine(to: CGPoint(x: leftMargin, y: size.height - topMargin))
        context.strokePath()

        //  Draw the Y axis max label
        label = String(format: format, maxValue)
        labelSize = label.size(withAttributes: labelAttributes)
        labelRect = CGRect(x: leftMargin - labelSize.width - labelTickLength, y: size.height - topMargin - (labelSize.height * 0.5), width: labelSize.width, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        context.beginPath()
        context.move(to: CGPoint(x: leftMargin - labelTickLength, y: size.height - topMargin))
        context.addLine(to: CGPoint(x: leftMargin, y: size.height - topMargin))
        context.strokePath()

        //  Draw the Y axis min label
        label = String(format: format, minValue)
        labelSize = label.size(withAttributes: labelAttributes)
        labelRect = CGRect(x: leftMargin - labelSize.width - labelTickLength, y: bottomMargin - (labelSize.height * 0.5), width: labelSize.width, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        context.beginPath()
        context.move(to: CGPoint(x: leftMargin - labelTickLength, y: bottomMargin))
        context.addLine(to: CGPoint(x: leftMargin, y: bottomMargin))
        context.strokePath()

        //  Get scale multipliers
        let xScaleMultiplier = (size.width - (leftMargin + rightMargin)) / CGFloat(timeWidth)
        let yScaleMultiplier = (size.height - (topMargin + bottomMargin)) / CGFloat(maxValue - minValue)
        
        //  If a limit line is defined, draw it
        if let limit = limitLine {
            if (limit >= minValue && limit <= maxValue) {
                let y = CGFloat(limit) * yScaleMultiplier + bottomMargin
                context.setStrokeColor(CGColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.9))
                context.setLineDash(phase: 0.0, lengths: [2.0, 3.0])
                context.beginPath()
                context.move(to: CGPoint(x: leftMargin, y: y))
                context.addLine(to: CGPoint(x: size.width - rightMargin, y: y))
                context.strokePath()
            }
        }
        
        //  Start a path
        context.setStrokeColor(CGColor(red: 0.1, green: 1.0, blue: 0.1, alpha: 0.9))
        context.setLineDash(phase: 0.0, lengths: [])
        context.beginPath()

        //  Find first point before start time
        let startTime = endTime - timeWidth
        var lastBefore = -1
        for index in 0..<points.count {
            if (points[index].time <= startTime) {
                lastBefore = index
            }
            else { break }
        }
        
        //  If none before start time, we don't need to interpolate
        if (lastBefore < 0) {
            if (points.count < 2) { return nil }  //  Must have two points in plot area
            lastBefore = 0
            let x = CGFloat(points[0].time.timeIntervalSince(startTime)) * xScaleMultiplier + leftMargin
            let y = CGFloat(points[0].value) * yScaleMultiplier + bottomMargin
            context.move(to: CGPoint(x: x, y: y))
        }
        else {
            if (lastBefore >= points.count-1) { return nil }  //  Must have two points in plot area
            
            //  Move to the interpolated point at the start time
            var yValue = (points[lastBefore+1].value - points[lastBefore].value) / (points[lastBefore+1].time.timeIntervalSince(points[lastBefore].time))
            yValue *= startTime.timeIntervalSince(points[lastBefore].time)
            yValue += points[lastBefore].value
            let y = CGFloat(yValue) * yScaleMultiplier + bottomMargin
            context.move(to: CGPoint(x: leftMargin, y: y))
        }
        
        //  Connect each point after that
        for index in (lastBefore+1)..<points.count {
            let x = CGFloat(points[index].time.timeIntervalSince(startTime)) * xScaleMultiplier + leftMargin
            let y = CGFloat(points[index].value) * yScaleMultiplier + bottomMargin
            context.addLine(to: CGPoint(x: x, y: y))
        }
        context.strokePath()

        //  Make the image
        guard let image = context.makeImage() else {
            return nil
        }
        return image
    }
}
