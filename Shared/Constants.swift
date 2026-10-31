//
//  Constants.swift
//  Accretion
//
//  Ported from CONST.H of Matt Burdick's "accrete".
//

import Foundation

enum Const {
    static let eccentricityCoeff = 0.077            // Dole's was 0.077
    static let protoplanetMass = 1.0e-15            // solar masses
    static let solarMassInGrams = 1.989e33          // grams
    static let earthMassInGrams = 5.977e27          // grams
    static let earthRadius = 6.378e6                // cm
    static let earthRadiusInKM = 6378.0             // km
    static let earthAcceleration = 981.0            // cm/sec2
    static let earthAxialTilt = 23.4                // degrees
    static let earthExosphereTemp = 1273.0          // Kelvin
    static let earthMassesPerSolarMass = 332775.64
    static let earthEffectiveTemp = 255.0           // Kelvin
    static let earthAlbedo = 0.39
    static let cloudCoverageFactor = 1.839e-8       // km2/kg
    static let earthWaterMassPerArea = 3.83e15      // grams per square km
    static let earthSurfPresInMillibars = 1000.0
    static let earthConvectionFactor = 0.43         // Hart, eq.20
    static let freezingPointOfWater = 273.0         // Kelvin
    static let daysInAYear = 365.256
    static let gasRetentionThreshold = 5.0          // ratio of esc vel to RMS vel
    static let gasGiantAlbedo = 0.5
    static let cloudAlbedo = 0.52
    static let airlessRockyAlbedo = 0.07
    static let rockyAlbedo = 0.15
    static let waterAlbedo = 0.04
    static let airlessIceAlbedo = 0.5
    static let iceAlbedo = 0.7
    static let secondsPerHour = 3600.0
    static let cmPerAU = 1.495978707e13
    static let cmPerKM = 1.0e5
    static let cmPerMeter = 100.0
    static let millibarsPerBar = 1000.0
    static let kelvinCelsiusDifference = 273.0
    static let gravConstant = 6.672e-8              // dyne cm2/gram2
    static let greenhouseEffectConst = 0.93         // affects inner radius
    static let molarGasConst = 8314.41              // g*m2/(sec2*K*mol)
    static let gasDustRatio = 50.0                  // K in the original
    static let critMassB = 1.2e-5                   // B: used in crit mass calc
    static let dustDensityCoeff = 2.0e-3            // A in Dole's paper
    static let alpha = 5.0                          // used in density calcs
    static let n = 3.0                              // used in density calcs
    static let j = 1.46e-19                         // day-length calcs (cm2/sec2 g)
    static let incrediblyLargeNumber = 9.9999e37
    static let solarRadiusInAU = 0.00465047
    static let tripleFraction = 0.25                // share of multiples that are triples

    // Kothari radius (cgs units)
    static let a1_20 = 6.485e12
    static let a2_20 = 4.0032e-8
    static let beta_20 = 5.71e12

    // Cloud fraction
    static let q1_36 = 1.258e19                     // grams
    static let q2_36 = 0.0698                       // 1/Kelvin
}

/// Molecular weights, from Dole's "Habitable Planets for Man", p. 38.
enum MolecularWeight {
    static let atomicHydrogen = 1.0
    static let molecularHydrogen = 2.0
    static let helium = 4.0
    static let atomicNitrogen = 14.0
    static let atomicOxygen = 16.0
    static let methane = 16.0
    static let ammonia = 17.0
    static let waterVapor = 18.0
    static let neon = 20.2
    static let molecularNitrogen = 28.0
    static let carbonMonoxide = 28.0
    static let nitricOxide = 30.0
    static let molecularOxygen = 32.0
    static let hydrogenSulphide = 34.1
    static let argon = 39.9
    static let carbonDioxide = 44.0
    static let nitrousOxide = 44.0
    static let nitrogenDioxide = 46.0
    static let ozone = 48.0
    static let sulphurDioxide = 64.1
    static let sulphurTrioxide = 80.1
    static let krypton = 83.8
    static let xenon = 131.3
}
