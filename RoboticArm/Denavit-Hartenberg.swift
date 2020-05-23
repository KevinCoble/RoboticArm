//
//  Denavit-Hartenberg.swift
//  RoboticArm
//
//  Created by Kevin Coble on 5/20/20.
//  Copyright © 2020 Kevin Coble. All rights reserved.
//

import Foundation
import Accelerate
import simd
import GLKit

/*
 Denavit - Hartenberg Parameters
    θ - angle to rotate frame N-1 around axis Zn-1 to have Xn-1 point in same direction as Xn
    α - angle to rotate frame N-1 around axis Xn to have Zn-1 point in same direction as Zn
    r - distance between center of frame N-1 and center of frame N along axis Xn  (length of common normal)
    d - distance between center of frame N-1 and center of frame N, along axis Zn-1
 
 */

public class DenavitHartenberg {
    public enum VariableParameter {
        case None
        case θ
        case α
        case r
        case d
    }
    
    let variableParameter : VariableParameter
    var θ = 0.0
    var α = 0.0
    var r = 0.0
    var d = 0.0
    
    init (variableParameter : VariableParameter) {
        self.variableParameter = variableParameter
    }
    
    init (variableParameter : VariableParameter, θ : Double, α : Double, r : Double, d : Double) {
        self.variableParameter = variableParameter
        self.θ = θ
        self.α = α
        self.r = r
        self.d = d
    }
    
    init (variableParameter : VariableParameter, θdegrees : Double, αdegrees : Double, r : Double, d : Double) {
        self.variableParameter = variableParameter
        self.θ = Double(GLKMathDegreesToRadians(Float(θdegrees)))
        self.α = Double(GLKMathDegreesToRadians(Float(αdegrees)))
        self.r = r
        self.d = d
    }

    func matrix(degrees : Double) -> matrix_double4x4
    {
        //  Convert to radians
        let variable = Double(GLKMathDegreesToRadians(Float(degrees)))

        //  Get the matrix
        return matrix(variable: variable)
    }
    
    func matrix(variable : Double) -> matrix_double4x4
    {
        //  Start with the base parameters
        var mθ = θ
        var mα = α
        var mr = r
        var md = d
        
        //  Add the variable to the appropriate parameter
        switch (variableParameter) {
            case .None:
                break
            case .θ:
                mθ += variable
            case .α:
                mα += variable
            case .r:
                mr += variable
            case .d:
                md += variable
        }
        
        //  Create the matrix
        var matrix = matrix_double4x4()
        
        //  Get the sine and cosines of the angles, using faster vector processor routines
        var angles: [Double] = [mθ, mα]
        var sines = [Double](repeating: 0, count: 2)
        var cosines = [Double](repeating: 0, count: 2)
        var n : Int32 = 2
        vvsincos(&sines, &cosines, &angles, &n)
        
        let cosθ = cosines[0]
        let sinθ = sines[0]
        let cosα = cosines[1]
        let sinα = sines[1]

        //  Set each entry of the matrix
        matrix[0, 0] = cosθ
        matrix[1, 0] = -sinθ * cosα
        matrix[2, 0] = sinθ * sinα
        matrix[3, 0] = mr * cosθ
        matrix[0, 1] = sinθ
        matrix[1, 1] = cosθ * cosα
        matrix[2, 1] = -cosθ * sinα
        matrix[3, 1] = mr * sinθ
        matrix[0, 2] = 0.0
        matrix[1, 2] = sinα
        matrix[2, 2] = cosα
        matrix[3, 2] = md
        matrix[0, 3] = 0.0
        matrix[1, 3] = 0.0
        matrix[2, 3] = 0.0
        matrix[3, 3] = 1.0

        return matrix
    }
    
    //  Routine to get final matrix from array of parameters and variables
    static func matrix(parameters : [DenavitHartenberg], variables : [Double], isInDegrees : Bool = false) -> matrix_double4x4
    {
        //  Use indices to skip variables to non-parametric joints
        var variableIndex = 0
        
        //  Start with an identity matrix
        var matrix = matrix_identity_double4x4
        
        for parameter in parameters {
            //  Get the matrix for this parameter set
            var pmatrix : matrix_double4x4
            if (parameter.variableParameter == .None) {
                pmatrix = parameter.matrix(variable: 0.0)
            }
            else {
                var variable = variables[variableIndex]
                if (isInDegrees && ((parameter.variableParameter == .θ) || (parameter.variableParameter == .α))) {
                    variable = Double(GLKMathDegreesToRadians(Float(variable)))
                }
                pmatrix = parameter.matrix(variable: variable)
                variableIndex += 1
            }
            
            //  Multiply the matrices
            matrix = matrix * pmatrix
        }
        
        return matrix
    }
}

